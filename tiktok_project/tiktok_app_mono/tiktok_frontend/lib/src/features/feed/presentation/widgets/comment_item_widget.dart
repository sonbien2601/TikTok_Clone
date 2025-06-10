// tiktok_frontend/lib/src/features/feed/presentation/widgets/comment_item_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/feed/domain/models/comment_model.dart';
import 'package:tiktok_frontend/src/features/feed/domain/services/comment_service.dart';
import 'edit_comment_dialog.dart';
import 'reply_dialog.dart';

class CommentItemWidget extends StatefulWidget {
  final CommentModel comment;
  final VoidCallback? onDelete;
  final Function(String)? onEdit;
  final Function(CommentModel)? onReplyAdded;
  final bool showReplies;

  const CommentItemWidget({
    super.key,
    required this.comment,
    this.onDelete,
    this.onEdit,
    this.onReplyAdded,
    this.showReplies = true,
  });

  @override
  State<CommentItemWidget> createState() => _CommentItemWidgetState();
}

class _CommentItemWidgetState extends State<CommentItemWidget> {
  final CommentService _commentService = CommentService();
  late CommentModel _currentComment;
  List<CommentModel> _replies = [];
  bool _isLoadingReplies = false;
  bool _showReplies = false;
  bool _isLiking = false;
  int _repliesPage = 1;
  bool _hasMoreReplies = false;

  @override
  void initState() {
    super.initState();
    _currentComment = widget.comment;
  }

  @override
  void didUpdateWidget(CommentItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.comment.id != oldWidget.comment.id) {
      _currentComment = widget.comment;
      _replies.clear();
      _showReplies = false;
      _repliesPage = 1;
    }
  }

  Future<void> _toggleLike() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để thích comment!'))
      );
      return;
    }

    if (_isLiking) return;

    setState(() {
      _isLiking = true;
    });

    // Optimistic update
    final wasLiked = _currentComment.isLikedByUser(authService.currentUser!.id);
    final newLikes = List<String>.from(_currentComment.likes);
    if (wasLiked) {
      newLikes.remove(authService.currentUser!.id);
    } else {
      newLikes.add(authService.currentUser!.id);
    }

    setState(() {
      _currentComment = _currentComment.copyWith(
        likes: newLikes,
        likesCount: newLikes.length,
      );
    });

    try {
      final updatedComment = await _commentService.toggleLikeComment(
        _currentComment.id,
        authService.currentUser!.id,
      );

      if (mounted) {
        setState(() {
          _currentComment = updatedComment;
        });
      }
    } catch (e) {
      print('[CommentItemWidget] Error toggling like: $e');
      
      // Revert optimistic update
      if (mounted) {
        setState(() {
          _currentComment = widget.comment;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thích comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }

  Future<void> _loadReplies() async {
    if (_isLoadingReplies) return;

    setState(() {
      _isLoadingReplies = true;
    });

    try {
      final response = await _commentService.getCommentReplies(
        _currentComment.id, 
        page: _repliesPage, 
        limit: 10
      );

      if (mounted) {
        setState(() {
          if (_repliesPage == 1) {
            _replies = response.replies;
          } else {
            _replies.addAll(response.replies);
          }
          _hasMoreReplies = response.pagination.hasNextPage;
          _showReplies = true;
        });
      }
    } catch (e) {
      print('[CommentItemWidget] Error loading replies: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải phản hồi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReplies = false;
        });
      }
    }
  }

  Future<void> _loadMoreReplies() async {
    if (_isLoadingReplies || !_hasMoreReplies) return;
    
    _repliesPage++;
    await _loadReplies();
  }

  void _showReplyDialog() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để trả lời!'))
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReplyDialog(
          parentComment: _currentComment,
          onReply: (replyText) async {
            try {
              final newReply = await _commentService.replyToComment(
                _currentComment.id,
                authService.currentUser!.id,
                replyText,
              );

              if (mounted) {
                setState(() {
                  _replies.insert(0, newReply);
                  _currentComment = _currentComment.copyWith(
                    repliesCount: _currentComment.repliesCount + 1,
                  );
                  _showReplies = true;
                });

                widget.onReplyAdded?.call(newReply);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã trả lời comment!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi khi trả lời: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isOwnComment = currentUser?.id == _currentComment.userId;
    final isLiked = _currentComment.isLikedByUser(currentUser?.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main comment
        InkWell(
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
                          _currentComment.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentComment.relativeTime,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        // Show edited indicator if comment was edited
                        if (_currentComment.isEdited) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(đã chỉnh sửa)',
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
                      _currentComment.text,
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
                          onTap: _isLiking ? null : _toggleLike,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isLiking)
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isLiked ? Colors.red : Colors.grey.shade600,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  size: 16,
                                  color: isLiked ? Colors.red : Colors.grey.shade600,
                                ),
                              if (_currentComment.likesCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  _formatCount(_currentComment.likesCount),
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
                          onTap: _showReplyDialog,
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
                                'Trả lời',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Replies count and toggle (if any)
                        if (_currentComment.repliesCount > 0) ...[
                          const SizedBox(width: 24),
                          InkWell(
                            onTap: () {
                              if (_showReplies) {
                                setState(() {
                                  _showReplies = false;
                                });
                              } else {
                                if (_replies.isEmpty) {
                                  _repliesPage = 1;
                                  _loadReplies();
                                } else {
                                  setState(() {
                                    _showReplies = true;
                                  });
                                }
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showReplies ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${_currentComment.repliesCount} phản hồi',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
        ),

        // Replies section
        if (_showReplies && widget.showReplies) ...[
          const SizedBox(height: 8),
          if (_isLoadingReplies && _replies.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 44),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            // Show replies
            for (final reply in _replies) ...[
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: CommentItemWidget(
                  comment: reply,
                  showReplies: false, // Don't show nested replies for now
                  onDelete: () => _deleteReply(reply),
                  onEdit: (newText) => _editReply(reply, newText),
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Load more replies button
            if (_hasMoreReplies)
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: InkWell(
                  onTap: _isLoadingReplies ? null : _loadMoreReplies,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoadingReplies)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.expand_more,
                          size: 16,
                          color: Colors.blue,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        _isLoadingReplies ? 'Đang tải...' : 'Xem thêm phản hồi',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: _currentComment.userAvatarUrl != null && _currentComment.userAvatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                _currentComment.userAvatarUrl!,
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
                'Tùy chọn comment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 20),
              
              // Edit option - ONLY show if onEdit callback is provided
              if (widget.onEdit != null)
                ListTile(
                  leading: Icon(
                    Icons.edit_outlined,
                    color: Colors.blue.shade600,
                  ),
                  title: Text(
                    'Chỉnh sửa comment',
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
                  'Xóa comment',
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
                    'Hủy',
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
    if (widget.onEdit == null) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditCommentDialog(
          initialText: _currentComment.text,
          onSave: (newText) async {
            await widget.onEdit!(newText);
            // Update local comment
            setState(() {
              _currentComment = _currentComment.copyWith(
                text: newText,
                updatedAt: DateTime.now(),
              );
            });
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
          title: const Text('Xóa Comment'),
          content: const Text(
            'Bạn có chắc chắn muốn xóa comment này? Hành động này không thể hoàn tác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (widget.onDelete != null) {
                  widget.onDelete!();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text(
                'Xóa',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editReply(CommentModel reply, String newText) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) return;

    try {
      final updatedReply = await _commentService.editComment(
        reply.id,
        authService.currentUser!.id,
        newText,
      );

      if (mounted) {
        setState(() {
          final index = _replies.indexWhere((r) => r.id == reply.id);
          if (index != -1) {
            _replies[index] = updatedReply;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi chỉnh sửa phản hồi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteReply(CommentModel reply) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) return;

    try {
      await _commentService.deleteComment(reply.id, authService.currentUser!.id);

      if (mounted) {
        setState(() {
          _replies.removeWhere((r) => r.id == reply.id);
          _currentComment = _currentComment.copyWith(
            repliesCount: (_currentComment.repliesCount - 1).clamp(0, double.infinity).toInt(),
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phản hồi đã được xóa!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa phản hồi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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