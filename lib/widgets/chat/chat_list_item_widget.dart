import 'package:flutter/material.dart';
import '../../core/models/chat/chat_session.dart';

class ChatListItemWidget extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  
  const ChatListItemWidget({
    super.key,
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isLocalSession = session.id.startsWith('local_');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            title: Text(
              _formatChatTitle(session.title),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                if (isLocalSession)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Local',
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                    ),
                  ),
                Expanded(
                  child: Text(
                    'Created: ${_formatDate(session.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            leading: CircleAvatar(
              backgroundColor: _getAvatarColor(session.title),
              child: Icon(
                isLocalSession ? Icons.offline_bolt : Icons.chat,
                color: Colors.white,
                size: 20,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              color: Colors.red[300],
              tooltip: 'Xóa cuộc trò chuyện',
            ),
          ),
        ),
      ),
    );
  }
  
  String _formatChatTitle(String title) {
    if (title.length <= 40) return title;
    final questionIndex = title.indexOf('?');
    if (questionIndex > 0 && questionIndex < 60) {
      return title.substring(0, questionIndex + 1);
    }
    return '${title.substring(0, 37)}...';
  }
  
  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    return '$day/$month/$year';
  }
  
  Color _getAvatarColor(String title) {
    final colorSeed = title.codeUnits.fold(0, (prev, element) => prev + element);
    final colors = [
      Colors.blue[700]!,
      Colors.purple[700]!,
      Colors.green[700]!,
      Colors.orange[800]!,
      Colors.teal[700]!,
      Colors.pink[700]!,
    ];
    return colors[colorSeed % colors.length];
  }
}
