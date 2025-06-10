// tiktok_frontend/lib/src/features/feed/presentation/widgets/reply_dialog.dart
import 'package:flutter/material.dart';
import 'package:tiktok_frontend/src/features/feed/domain/models/comment_model.dart';

class ReplyDialog extends StatefulWidget {
  final CommentModel parentComment;
  final Function(String) onReply;

  const ReplyDialog({
    super.key,
    required this.parentComment,
    required this.onReply,
  });

  @override
  State<ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<ReplyDialog> {
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  bool _isReplying = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    
    // Auto focus and start with @username
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      // Optionally start with @username mention
      final mention = '@${widget.parentComment.username} ';
      _textController.text = mention;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: mention.length),
      );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isValid => _textController.text.trim().isNotEmpty && _textController.text.trim().length <= 500;

  void _reply() async {
    if (!_isValid || _isReplying) return;

    final replyText = _textController.text.trim();
    if (replyText.isEmpty) return;

    setState(() {
      _isReplying = true;
    });

    try {
      await widget.onReply(replyText);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isReplying = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Lỗi khi trả lời: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Thử lại',
              textColor: Colors.white,
              onPressed: _reply,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.reply,
            color: Colors.blue.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text('Trả lời comment'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show parent comment
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Parent comment author avatar
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: widget.parentComment.userAvatarUrl != null && widget.parentComment.userAvatarUrl!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                widget.parentComment.userAvatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.parentComment.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.parentComment.relativeTime,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.parentComment.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Reply input
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLines: null,
            minLines: 3,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Viết phản hồi của bạn...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (value) {
              setState(() {}); // Rebuild để update button states
            },
          ),
          
          const SizedBox(height: 8),
          
          // Character count and validation
          Row(
            children: [
              Text(
                '${_textController.text.length}/500',
                style: TextStyle(
                  fontSize: 12,
                  color: _textController.text.length > 500 
                    ? Colors.red 
                    : Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              if (!_isValid && _textController.text.trim().isEmpty)
                Text(
                  'Phản hồi không được để trống',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                  ),
                )
              else if (_textController.text.length > 500)
                Text(
                  'Quá dài',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isReplying ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isReplying || !_isValid ? null : _reply,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
          child: _isReplying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Trả lời'),
        ),
      ],
    );
  }
}