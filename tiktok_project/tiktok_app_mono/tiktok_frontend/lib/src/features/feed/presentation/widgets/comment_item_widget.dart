// tiktok_frontend/lib/src/features/feed/presentation/widgets/comment_item_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/feed/domain/models/comment_model.dart';
import 'edit_comment_dialog.dart';

class CommentItemWidget extends StatelessWidget {
  final CommentModel comment;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final Function(String)? onEdit;

  const CommentItemWidget({
    super.key,
    required this.comment,
    this.onDelete,
    this.onReply,
    this.onLike,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isOwnComment = currentUser?.id == comment.userId;
    final isLiked = comment.isLikedByUser(currentUser?.id);

    return InkWell(
      onLongPress: isOwnComment ? () => _showOptionsBottomSheet(context) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar
          _buildUserAvatar(),
          
          const SizedBox(width: 12),
          
          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and time
                Row(
                  children: [
                    Text(
                      comment.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.relativeTime,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    // Show edited indicator if comment was edited
                    if (_isEdited()) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(edited)',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (isOwnComment)
                      InkWell(
                        onTap: () => _showOptionsBottomSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                // Comment Text
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Action buttons
                Row(
                  children: [
                    // Like button
                    InkWell(
                      onTap: onLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: isLiked ? Colors.red : Colors.grey.shade600,
                          ),
                          if (comment.likesCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              _formatCount(comment.likesCount),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // Reply button
                    InkWell(
                      onTap: onReply,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.reply,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Replies count (if any)
                    if (comment.repliesCount > 0) ...[
                      const SizedBox(width: 24),
                      Text(
                        '${comment.repliesCount} replies',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isEdited() {
    try {
      final createdAt = comment.createdAt;
      final updatedAt = comment.updatedAt;
      
      // Consider edited if updated time is more than 1 minute after created time
      return updatedAt.difference(createdAt).inMinutes > 1;
    } catch (e) {
      return false;
    }
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: comment.userAvatarUrl != null && comment.userAvatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                comment.userAvatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAvatar();
                },
              ),
            )
          : _buildDefaultAvatar(),
    );
  }

  Widget _buildDefaultAvatar() {
    return Icon(
      Icons.person,
      size: 20,
      color: Colors.grey.shade600,
    );
  }

  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Comment options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 20),
              
              // Edit option - ONLY show if onEdit callback is provided
              if (onEdit != null)
                ListTile(
                  leading: Icon(
                    Icons.edit_outlined,
                    color: Colors.blue.shade600,
                  ),
                  title: Text(
                    'Edit comment',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(context);
                  },
                ),
              
              // Delete option
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                title: const Text(
                  'Delete comment',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context);
                },
              ),
              
              // Cancel
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              
              // Bottom padding for safe area
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context) {
    if (onEdit == null) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditCommentDialog(
          initialText: comment.text,
          onSave: (newText) async {
            await onEdit!(newText);
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Comment'),
          content: const Text(
            'Are you sure you want to delete this comment? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (onDelete != null) {
                  onDelete!();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
  }
}