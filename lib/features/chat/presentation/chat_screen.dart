import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/models/chat/chat_session.dart';
import '../../../core/models/chat/message.dart';
import '../../../core/services/chat/jarvis_chat_service.dart';
import '../../../widgets/ai/model_selector_widget.dart';

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
  final TextEditingController _messageController = TextEditingController();
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
  
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _messageController.clear();
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
      
      // Send the message
      final userMessage = await _chatService.sendMessage(widget.chatSession.id, text);
      
      // Check if the session is using local fallback mode
      final isLocalSession = widget.chatSession.id.startsWith('local_') || 
                            _chatService.isUsingDirectGeminiApi();
      
      if (isLocalSession) {
        // For local sessions, we need to generate a response using Gemini API directly
        setState(() {
          _waitingForResponse = true;
        });
        
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
          _waitingForResponse = false;
          
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
        _isLoading = false;
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
    // Check if this is a local session due to model limitations
    final isLocalSession = widget.chatSession.id.startsWith('local_');
    final isNoHistoryModel = widget.chatSession.metadata != null && 
                            widget.chatSession.metadata!['noHistorySupport'] == true;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatSession.title),
        actions: [
          if (isLocalSession && isNoHistoryModel)
            Tooltip(
              message: 'This model doesn\'t support server-side chat history',
              child: const Icon(Icons.info_outline, color: Colors.amber),
            ),
          ModelSelectorWidget(
            currentModel: _currentModel,
            onModelChanged: _onModelChanged,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Bắt đầu cuộc trò chuyện bằng cách gửi tin nhắn.'),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessageBubble(message);
                        },
                      ),
          ),
          
          // Input box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isSending,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(Message message) {
    // Renders each message in the history
    final isUser = message.isUser;
    
    if (message.isTyping) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
          child: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
            ),
          ),
        ),
      );
    }
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFFEEEEEE), // Use const Color instead of Colors.grey[300]
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                color: isUser ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
