import 'package:flutter/material.dart';
import '../../core/models/chat/message.dart';

class MessageBubbleWidget extends StatelessWidget {
  final Message message;
  final Message? previousMessage;
  
  const MessageBubbleWidget({
    super.key,
    required this.message,
    this.previousMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    
    // Check if we should show the sender label (when sender changes)
    final showSenderLabel = previousMessage == null || previousMessage!.isUser != message.isUser;
    
    if (message.isTyping) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSenderLabel)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
              child: Text(
                'AI Assistant',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(left: 16, right: 60, bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Thinking...'),
              ],
            ),
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Show sender label when sender changes
        if (showSenderLabel)
          Padding(
            padding: EdgeInsets.only(
              left: isUser ? 0 : 16, 
              right: isUser ? 16 : 0,
              top: 16, 
              bottom: 4,
            ),
            child: Text(
              isUser ? 'You' : 'AI Assistant',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        
        Container(
          margin: EdgeInsets.only(
            left: isUser ? 60 : 16, 
            right: isUser ? 16 : 60,
            bottom: 10,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFF1A7BF5) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        
        // Show timestamp below the message, aligned with the message
        Padding(
          padding: EdgeInsets.only(
            left: isUser ? 0 : 16, 
            right: isUser ? 16 : 0,
            bottom: 8,
          ),
          child: Text(
            _formatTimestamp(message.timestamp),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    // Format the time
    String timeStr = '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    
    // If not today, include the date
    if (messageDate != today) {
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      timeStr = '${timestamp.day} ${monthNames[timestamp.month - 1]}, $timeStr';
    }
    
    return timeStr;
  }
}
