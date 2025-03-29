import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/models/chat/chat_session.dart';
import '../../../core/models/chat/message.dart';
import '../../../core/services/chat/jarvis_chat_service.dart';
import '../../../widgets/ai/model_selector_widget.dart';
import '../../../widgets/chat/message_bubble_widget.dart';
import '../../../widgets/chat/chat_input_widget.dart';

class ChatScreen extends StatefulWidget {
  final ChatSession chatSession;
  
  const ChatScreen({
    super.key, 
    required this.chatSession,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final JarvisChatService _chatService = JarvisChatService();
  final Logger _logger = Logger();
  
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String _currentModel = 'gemini-1.5-flash-latest';
  String? _errorMessage;
  bool _waitingForResponse = false;
  
  @override
  void initState() {
    super.initState();
    _loadModel();
    
    // Show warning if using a model that doesn't support history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      
      // Check if this is a local session due to model limitations
      final isLocalSession = widget.chatSession.id.startsWith('local_');
      final isNoHistoryModel = widget.chatSession.metadata != null && 
                              widget.chatSession.metadata!['noHistorySupport'] == true;
      
      if (isLocalSession && isNoHistoryModel && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using local mode: The current model doesn\'t support server-side chat history.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    });
  }
  
  Future<void> _loadMessages() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Check if we're using a local session (fallback mode)
      final isLocalSession = widget.chatSession.id.startsWith('local_');
      final isUsingGemini = _chatService.isUsingDirectGeminiApi();
      
      if (isLocalSession || isUsingGemini) {
        // In fallback mode, we don't have persistent history
        setState(() {
          _isLoading = false;
          if (_messages.isEmpty && mounted) {
            // Show an informative message for the user - moved to postBuild callback
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Using offline mode. Chat history is not available.'),
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            });
          }
        });
        return;
      }
      
      // Get messages from API
      final messages = await _chatService.getMessages(widget.chatSession.id);
      
      if (!mounted) return;
      
      if (messages.isEmpty && !isUsingGemini) {
        // Check for diagnostic info to help user
        final diagnostics = _chatService.getDiagnosticInfo();
        _logger.i('Chat diagnostics: $diagnostics');
        
        // If API is having auth issues but we're not in fallback mode yet
        if (diagnostics['hasApiError'] == true && !isUsingGemini && mounted) {
          // Moved to postBuild callback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to load chat history. There might be an authentication issue.'),
                  duration: Duration(seconds: 5),
                ),
              );
            }
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        
        // Scroll to bottom after loading messages
        if (_messages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      _logger.e('Error loading messages: $e');
      
      if (!mounted) return;
      
      // Check for specific error types
      final errorMessage = e.toString().toLowerCase();
      String userMessage;
      
      if (errorMessage.contains('scope') || errorMessage.contains('permission')) {
        userMessage = 'Unable to load chat history. Your account may not have the required permissions.';
      } else if (errorMessage.contains('unauthorized') || errorMessage.contains('auth')) {
        userMessage = 'Session expired. Please try logging out and back in.';
      } else {
        userMessage = 'Error loading chat history. Please try again later.';
      }
      
      setState(() {
        _isLoading = false;
        // Add empty state or error state UI
      });
      
      // Moved to postBuild callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userMessage)),
          );
        }
      });
    }
  }
  
  Future<void> _loadModel() async {
    try {
      final model = await _chatService.getSelectedModel();
      if (model != null && mounted) {
        setState(() {
          _currentModel = model;
        });
      }
    } catch (e) {
      _logger.e('Error loading model: $e');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _waitingForResponse = true;
    });

    try {
      // Create a temporary message to show immediately
      final tempMessage = Message(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      );
      
      setState(() {
        _messages.add(tempMessage);
      });
      
      // Scroll to the bottom
      _scrollToBottom();
      
      // Send the message
      final userMessage = await _chatService.sendMessage(widget.chatSession.id, text);
      
      // Check if the session is using local fallback mode
      final isLocalSession = widget.chatSession.id.startsWith('local_') || 
                           _chatService.isUsingDirectGeminiApi();
      
      if (isLocalSession) {
        // For local sessions, we need to generate a response using Gemini API directly
        
        // Convert previous messages to a format Gemini can use
        final chatHistory = _messages
            .take(_messages.length - 1) // Exclude the message we just added
            .map((msg) => {
              'role': msg.isUser ? 'user' : 'assistant',
              'content': msg.text,
            })
            .toList();
        
        // Get AI response using direct Gemini API
        final response = await _chatService.getDirectAIResponse(text, chatHistory);
        
        setState(() {
          // Add AI response message
          _messages.add(Message(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      } else {
        // For Jarvis API sessions, refresh messages to get the AI response
        final messages = await _chatService.getMessages(widget.chatSession.id);
        
        setState(() {
          _messages = messages;
        });
      }
      
      // Scroll to the bottom
      _scrollToBottom();
    } catch (e) {
      _logger.e('Error sending message: $e');
      
      setState(() {
        _errorMessage = 'Failed to send message: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSending = false;
        _waitingForResponse = false;
      });
    }
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void _onModelChanged(String model) {
    setState(() {
      _currentModel = model;
    });
    
    // Save selected model
    _chatService.updateSelectedModel(model);
  }
  
  @override
  Widget build(BuildContext context) {
    final formattedTitle = _formatTitle(widget.chatSession.title);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // Show drawer of parent HomePage
            Scaffold.of(context).openDrawer();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              formattedTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            // Show model name in subtitle
            Text(
              _getModelDisplayName(_currentModel),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Container(
              color: Colors.white,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _messages.length + (_waitingForResponse ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length && _waitingForResponse) {
                              // Show typing indicator
                              return MessageBubbleWidget(
                                message: Message(
                                  text: '',
                                  isUser: false,
                                  timestamp: DateTime.now(), 
                                  isTyping: true,
                                ),
                                previousMessage: _messages.isNotEmpty ? _messages.last : null,
                              );
                            }
                            
                            final message = _messages[index];
                            final previousMessage = index > 0 ? _messages[index - 1] : null;
                            
                            return MessageBubbleWidget(
                              message: message,
                              previousMessage: previousMessage,
                            );
                          },
                        ),
            ),
          ),
          
          // Input box
          ChatInputWidget(
            onSendMessage: _sendMessage,
            isLoading: _isSending,
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'How can I help you today?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to start chatting',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Change model'),
                onTap: () {
                  Navigator.pop(context);
                  _showModelSelector(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reload messages'),
                onTap: () {
                  Navigator.pop(context);
                  _loadMessages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete conversation'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteChat();
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showModelSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Model'),
          content: SizedBox(
            width: double.maxFinite,
            child: ModelSelectorWidget(
              currentModel: _currentModel,
              onModelChanged: (model) {
                _onModelChanged(model);
                Navigator.pop(context);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
  
  void _confirmDeleteChat() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Conversation'),
          content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Return to home page
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
  
  String _formatTitle(String title) {
    // If title is too long, truncate it
    if (title.length > 30) {
      return '${title.substring(0, 27)}...';
    }
    return title;
  }
  
  String _getModelDisplayName(String modelId) {
    // Map model IDs to user-friendly names
    const modelNames = {
      'gemini-1.5-flash-latest': 'Gemini 1.5 Flash',
      'gemini-1.5-pro-latest': 'Gemini 1.5 Pro',
      'claude-3-5-sonnet-20240620': 'Claude 3.5 Sonnet',
      'gpt-4o': 'GPT-4o',
      'gpt-4o-mini': 'GPT-4o Mini',
    };
    
    return modelNames[modelId] ?? modelId;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
