import 'package:flutter/material.dart';

class ChatInputWidget extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isLoading;
  
  const ChatInputWidget({
    super.key,
    required this.onSendMessage,
    this.isLoading = false,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _messageController = TextEditingController();
  bool _hasText = false;
  
  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
  }
  
  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }
  
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    widget.onSendMessage(text);
    _messageController.clear();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -1),
            blurRadius: 3,
          ),
        ],
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Message AI Assistant...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: !widget.isLoading,
                maxLines: null,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hasText ? const Color(0xFF1A7BF5) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: IconButton(
                icon: widget.isLoading 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _hasText ? Colors.white : Colors.grey[400]!),
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: _hasText ? Colors.white : Colors.grey[400],
                        size: 18,
                      ),
                splashRadius: 22,
                onPressed: (_hasText && !widget.isLoading) ? _sendMessage : null,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    super.dispose();
  }
}
