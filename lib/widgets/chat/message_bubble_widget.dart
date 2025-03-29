import 'package:flutter/material.dart';
import '../../core/models/chat/message.dart';

class MessageBubbleWidget extends StatelessWidget {
  final Message message;
  final bool isLastMessage;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    this.isLastMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTyping = message.isTyping;
    final isWelcomeMessage = message.id == 'welcome';
    final isStartConversation = message.isUser && message.text == 'start_conversation';
    
    // If it's an initialization message, show a different UI component
    if (isStartConversation) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Conversation started',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }
    
    return Row(
      mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!message.isUser) _buildAvatar(context, isWelcomeMessage),
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: message.isUser 
                  ? Colors.blue[100] 
                  : (isTyping ? Colors.grey[200] : (isWelcomeMessage ? Colors.blue[50] : Colors.grey[50])),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: message.isUser ? const Radius.circular(20) : const Radius.circular(5),
                bottomRight: message.isUser ? const Radius.circular(5) : const Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13), // Fix: Using withAlpha instead of withOpacity
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: isTyping ? _buildTypingIndicator() : _buildMessageContent(context),
          ),
        ),
        if (message.isUser) _buildUserAvatar(context),
      ],
    );
  }
  
  Widget _buildAvatar(BuildContext context, bool isWelcomeMessage) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: CircleAvatar(
        backgroundColor: isWelcomeMessage ? Colors.blue.shade600 : Colors.green.shade700,
        radius: 16,
        child: Icon(
          isWelcomeMessage ? Icons.waving_hand : Icons.smart_toy,
          size: isWelcomeMessage ? 18 : 20,
          color: Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildUserAvatar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: CircleAvatar(
        backgroundColor: Colors.blue.shade700,
        radius: 16,
        child: const Icon(
          Icons.person,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [  // Fix: Using const constructor
        AnimatedPulse(delay: 100),
        AnimatedPulse(delay: 300),
        AnimatedPulse(delay: 500),
      ],
    );
  }
  
  Widget _buildMessageContent(BuildContext context) {
    final isWelcomeMessage = message.id == 'welcome';
    return Text(
      message.text,
      style: TextStyle(
        color: message.isUser ? Colors.black87 : (isWelcomeMessage ? Colors.black87 : Colors.black87),
        fontSize: 15,
        fontWeight: isWelcomeMessage ? FontWeight.w500 : FontWeight.normal,
      ),
    );
  }
}

// Animation cho typing indicator
class AnimatedPulse extends StatefulWidget {
  final int delay;
  
  const AnimatedPulse({super.key, required this.delay});

  @override
  State<AnimatedPulse> createState() => _AnimatedPulseState();
}

class _AnimatedPulseState extends State<AnimatedPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha(((0.6 * _animation.value + 0.2) * 255).toInt()), // Fix: Using withAlpha
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
