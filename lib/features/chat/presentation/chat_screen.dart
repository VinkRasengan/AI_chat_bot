import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/models/chat/chat_session.dart';
import '../../../core/models/chat/message.dart';
import '../../../core/services/chat/jarvis_chat_service.dart';
import '../../../core/services/auth/auth_service.dart';
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
  final AuthService _authService = AuthService();
  late final JarvisChatService _chatService;
  final Logger _logger = Logger();
  final TextEditingController _textController = TextEditingController();
  
  List<Message> _messages = [];
  bool _isLoading = true;
  final bool _isSending = false;
  final bool _waitingForResponse = false;
  String _currentModel = 'gemini-1.5-flash-latest';
  
  @override
  void initState() {
    super.initState();
    _chatService = JarvisChatService(_authService);
    _loadModel();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      
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
      final isLocalSession = widget.chatSession.id.startsWith('local_');
      final isUsingGemini = await _chatService.isUsingDirectGeminiApi();
      
      if (isLocalSession || isUsingGemini) {
        setState(() {
          _isLoading = false;
          if (_messages.isEmpty && mounted) {
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
      
      final messages = await _chatService.getMessages(widget.chatSession.id);
      
      if (!mounted) return;
      
      if (messages.isEmpty && !isUsingGemini) {
        final diagnostics = await _chatService.getDiagnosticInfo();
        _logger.i('Chat diagnostics: $diagnostics');
        
        if (diagnostics['hasApiError'] == true && !isUsingGemini && mounted) {
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
        
        if (_messages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      _logger.e('Error loading messages: $e');
      
      if (!mounted) return;
      
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
      });
      
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
    if (text.trim().isEmpty) return;
    
    setState(() {
      // Add user message immediately to UI
      _messages.add(Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      
      // Add a temporary typing indicator for the bot
      _messages.add(Message(
        id: 'typing-${DateTime.now().millisecondsSinceEpoch}',
        text: '...',
        isUser: false,
        isTyping: true,
        timestamp: DateTime.now(),
      ));
    });
    
    try {
      // Clear input field and scroll to bottom
      _textController.clear();
      _scrollToBottom();
      
      // Send the message
      final result = await _chatService.sendMessage(widget.chatSession.id, text);
      
      setState(() {
        // Remove the typing indicator
        _messages.removeWhere((message) => message.isTyping);
        
        if (result['success'] == true) {
          // Add the bot's response from the API
          _messages.add(Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: result['message'] ?? 'No response',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        } else {
          // Show error message
          _messages.add(Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: 'Error: ${result['error'] ?? 'Failed to get response'}',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        }
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() {
        // Remove the typing indicator
        _messages.removeWhere((message) => message.isTyping);
        
        // Show error message
        _messages.add(Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: 'Error: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      
      _scrollToBottom();
    }
  }
  
  void _scrollToBottom() {
    // Use Future.delayed to ensure the UI has updated first
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void _onModelChanged(String model) {
    setState(() {
      _currentModel = model;
    });
    
    _chatService.updateSelectedModel(model);
  }
  
  Widget _buildMessageBubble(Message message, int index) {
    return MessageBubbleWidget(
      key: ValueKey(message.id ?? message.timestamp.toString()),
      message: message,
      showTimestamp: true,
      onTap: () {
        // Handle message tap if needed
      },
    );
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
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
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
                              return MessageBubbleWidget(
                                message: Message(
                                  text: '',
                                  isUser: false,
                                  timestamp: DateTime.now(), 
                                  isTyping: true,
                                ),
                              );
                            }
                            
                            final message = _messages[index];
                            
                            return _buildMessageBubble(message, index);
                          },
                        ),
            ),
          ),
          
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
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
  
  String _formatTitle(String title) {
    if (title.length > 30) {
      return '${title.substring(0, 27)}...';
    }
    return title;
  }
  
  String _getModelDisplayName(String modelId) {
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
