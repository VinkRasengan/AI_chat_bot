import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/models/chat/message.dart';

class MessageBubbleWidget extends StatefulWidget {
  final Message message;
  final VoidCallback? onTap;
  final bool showTimestamp;
  
  const MessageBubbleWidget({
    Key? key,
    required this.message,
    this.onTap,
    this.showTimestamp = true,
  }) : super(key: key);
  
  @override
  State<MessageBubbleWidget> createState() => _MessageBubbleWidgetState();
}

class _MessageBubbleWidgetState extends State<MessageBubbleWidget> {
  late TapGestureRecognizer _tapRecognizer;
  
  @override
  void initState() {
    super.initState();
    _tapRecognizer = TapGestureRecognizer()
      ..onTap = widget.onTap;
  }
  
  @override
  void dispose() {
    _tapRecognizer.dispose(); // Important: Dispose the recognizer
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final isTyping = widget.message.isTyping;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isUser 
              ? Theme.of(context).primaryColor 
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26), // 0.1 * 255 = ~26
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isTyping)
              _buildTypingIndicator()
            else
              _buildMessageText(context),
            
            if (widget.showTimestamp && !isTyping)
              _buildTimestamp(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessageText(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        text: widget.message.text,
        style: TextStyle(
          color: widget.message.isUser ? Colors.white : null,
        ),
        recognizer: widget.onTap != null ? _tapRecognizer : null,
      ),
    );
  }
  
  Widget _buildTypingIndicator() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
        SizedBox(width: 8),
        Text('Đang nhập...'),
      ],
    );
  }
  
  Widget _buildTimestamp() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        _formatTimestamp(widget.message.timestamp),
        style: TextStyle(
          fontSize: 10,
          color: widget.message.isUser 
              ? Colors.white.withAlpha(179) // 0.7 * 255 = ~179
              : Colors.grey,
        ),
      ),
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
