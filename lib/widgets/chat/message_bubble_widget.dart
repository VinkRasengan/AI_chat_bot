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
    
    return Row(
      mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Avatar (only show for AI messages)
        if (!message.isUser) _buildAvatar(context, isWelcomeMessage),
        
        // Message Content
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // Use special styling for welcome message
              color: message.isUser 
                  ? Theme.of(context).primaryColor 
                  : (isTyping 
                      ? Colors.grey.shade200 
                      : (isWelcomeMessage 
                          ? Colors.blue.shade50  // Light blue for welcome message
                          : Colors.white)),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: isTyping 
                ? _buildTypingIndicator() 
                : _buildMessageContent(context),
          ),
        ),
        
        // User Avatar (only show for user messages)
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
      children: const [
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
        color: message.isUser 
            ? Colors.white 
            : (isWelcomeMessage ? Colors.black87 : Colors.black87),
        fontSize: 15,
        fontWeight: isWelcomeMessage ? FontWeight.w500 : FontWeight.normal,
      ),
    );
  }
}

// Animation for typing indicator
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
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    
    // Add delay before starting animation
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
        // Calculate the alpha value as a double between 128.0 and 256.0
        final double alphaValue = 128.0 + (_animation.value * 128.0);
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(alphaValue / 255.0), // Proper opacity value
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
