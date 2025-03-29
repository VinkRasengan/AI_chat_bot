import 'package:flutter/material.dart';

class ChatInputWidget extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isLoading;
  final bool isDisabled;
  final String? hintText;
  
  const ChatInputWidget({
    Key? key,
    required this.onSendMessage,
    this.isLoading = false,
    this.isDisabled = false,
    this.hintText,
  }) : super(key: key);
  
  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateHasText);
  }
  
  void _updateHasText() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }
  
  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading || widget.isDisabled) return;
    
    widget.onSendMessage(text);
    _controller.clear();
    // Keep focus after sending
    _focusNode.requestFocus();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13), // 0.05 * 255 = ~13
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !widget.isDisabled,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: widget.isDisabled 
                    ? Colors.grey.shade200 
                    : Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          // Use Builder to get a context with the Scaffold ancestor
          Builder(
            builder: (context) => Material(
              color: _hasText && !widget.isLoading && !widget.isDisabled
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade300,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _hasText && !widget.isLoading && !widget.isDisabled 
                    ? _handleSubmit 
                    : null,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: widget.isLoading 
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.send,
                          color: _hasText && !widget.isDisabled
                              ? Colors.white
                              : Colors.grey.shade400,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.removeListener(_updateHasText);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
