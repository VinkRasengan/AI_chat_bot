import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/models/chat/chat_session.dart';
import '../../../core/models/chat/message.dart';
import '../../../core/services/chat/jarvis_chat_service.dart';
import '../../../widgets/chat/message_bubble_widget.dart';
import '../../../widgets/chat/chat_input_widget.dart';

class ChatScreen extends StatefulWidget {
  final ChatSession chatSession;
  final JarvisChatService chatService;

  const ChatScreen({
    super.key,
    required this.chatSession,
    required this.chatService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final Logger _logger = Logger();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

  bool _isLoading = true;
  bool _isSending = false;
  List<Message> _messages = [];
  String _currentTitle = '';

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.chatSession.title;
    _loadMessages();

    if (widget.chatSession.messages != null && widget.chatSession.messages!.isNotEmpty) {
      setState(() {
        _messages = widget.chatSession.messages!;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final messages = await widget.chatService.getMessages(widget.chatSession.id);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      _logger.e('Error loading messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    _inputController.clear();
    
    try {
      setState(() {
        _isSending = true;
        _messages.add(Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ));
        _messages.add(Message(
          id: 'typing',
          text: '',
          isUser: false,
          isTyping: true,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();

      final response = await widget.chatService.sendMessage(widget.chatSession.id, text);
      if (mounted) {
        setState(() {
          _messages.removeWhere((message) => message.id == 'typing');
          if (response['success'] == true) {
            _messages.add(Message(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: response['message'] ?? 'No response',
              isUser: false,
              timestamp: DateTime.now(),
            ));
            if (response['title'] != null && _currentTitle != response['title']) {
              _currentTitle = response['title'];
            }
          } else {
            _messages.add(Message(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: 'Error: ${response['error'] ?? 'Failed to get response'}',
              isUser: false,
              timestamp: DateTime.now(),
            ));
          }
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      _logger.e('Error sending message: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((message) => message.id == 'typing');
          _messages.add(Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: 'Error: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          
                          // If you want to style system messages differently but still show them:
                          return MessageBubbleWidget(
                            message: message,
                            isLastMessage: index == _messages.length - 1,
                          );
                        },
                      ),
          ),
          SafeArea(
            child: ChatInputWidget(
              controller: _inputController,
              onSend: _sendMessage,
              isLoading: _isSending,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }
}
