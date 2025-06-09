// tiktok_frontend/lib/src/features/feed/presentation/widgets/edit_comment_dialog.dart
import 'package:flutter/material.dart';

class EditCommentDialog extends StatefulWidget {
  final String initialText;
  final Function(String) onSave;

  const EditCommentDialog({
    super.key,
    required this.initialText,
    required this.onSave,
  });

  @override
  State<EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<EditCommentDialog> {
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    
    // Auto focus and select all text
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasChanges => _textController.text.trim() != widget.initialText.trim();
  bool get _isValid => _textController.text.trim().isNotEmpty && _textController.text.trim().length <= 500;

  void _save() async {
    if (!_isValid || _isSaving) return;

    final newText = _textController.text.trim();
    if (newText == widget.initialText.trim()) {
      // No changes, just close
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(newText);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Comment updated successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to update comment: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _save,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Comment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLines: null,
            minLines: 3,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Edit your comment...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (value) {
              setState(() {}); // Rebuild to update button states
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
                  'Comment cannot be empty',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                  ),
                )
              else if (_textController.text.length > 500)
                Text(
                  'Too long',
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
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving || !_isValid || !_hasChanges ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}