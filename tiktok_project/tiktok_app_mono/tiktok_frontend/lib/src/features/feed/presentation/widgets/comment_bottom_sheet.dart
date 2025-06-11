// tiktok_frontend/lib/src/features/feed/presentation/widgets/comment_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/feed/domain/models/comment_model.dart';
import 'package:tiktok_frontend/src/features/feed/domain/services/comment_service.dart';
import 'package:tiktok_frontend/src/features/feed/presentation/widgets/comment_item_widget.dart';

class CommentBottomSheet extends StatefulWidget {
  final String videoId;
  final int initialCommentsCount;
  final Function(int)? onCommentsCountChanged;
  final String? highlightCommentId; // Add highlight support

  const CommentBottomSheet({
    super.key,
    required this.videoId,
    required this.initialCommentsCount,
    this.onCommentsCountChanged,
    this.highlightCommentId,
  });

  @override
  State<CommentBottomSheet> createState() => CommentBottomSheetState();
}

class CommentBottomSheetState extends State<CommentBottomSheet> {
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  List<CommentModel> _comments = [];
  bool _isLoading = false;
  bool _isPosting = false;
  bool _hasError = false;
  String? _errorMessage;
  
  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasNextPage = false;
  bool _isLoadingMore = false;
  int _commentsCount = 0;

  // Track deleting comments
  final Set<String> _deletingComments = {};
  // Track editing comments
  final Set<String> _editingComments = {};
  
  // Highlight support
  String? _highlightedCommentId;
  bool _shouldScrollToHighlight = false;

  @override
  void initState() {
    super.initState();
    _commentsCount = widget.initialCommentsCount;
    _highlightedCommentId = widget.highlightCommentId;
    _shouldScrollToHighlight = widget.highlightCommentId != null;
    _loadComments();
    
    // Listen for scroll to load more comments
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasNextPage && !_isLoadingMore) {
        _loadMoreComments();
      }
    }
  }

  Future<void> _loadComments() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final response = await _commentService.getVideoComments(widget.videoId, page: 1, limit: 20);
      
      if (mounted) {
        setState(() {
          _comments = response.comments;
          _currentPage = response.pagination.currentPage;
          _totalPages = response.pagination.totalPages;
          _hasNextPage = response.pagination.hasNextPage;
          _commentsCount = response.pagination.totalComments;
          _isLoading = false;
        });
        
        // Update parent widget
        widget.onCommentsCountChanged?.call(_commentsCount);
        
        // Auto-scroll to highlighted comment if needed
        if (_shouldScrollToHighlight && _highlightedCommentId != null) {
          _scrollToHighlightedComment();
        }
      }
    } catch (e) {
      print('[CommentBottomSheet] Error loading comments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  void _scrollToHighlightedComment() {
    if (_highlightedCommentId == null) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _comments.indexWhere((c) => c.id == _highlightedCommentId);
      if (index != -1 && _scrollController.hasClients) {
        // Calculate approximate position (each comment item is roughly 120px)
        final position = index * 120.0;
        _scrollController.animateTo(
          position.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        
        // Clear highlight after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _highlightedCommentId = null;
            });
          }
        });
      }
      _shouldScrollToHighlight = false;
    });
  }

  // Public method to highlight a comment (can be called from outside)
  void highlightComment(String commentId) {
    setState(() {
      _highlightedCommentId = commentId;
      _shouldScrollToHighlight = true;
    });
    _scrollToHighlightedComment();
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasNextPage) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _commentService.getVideoComments(
        widget.videoId, 
        page: _currentPage + 1, 
        limit: 20
      );
      
      if (mounted) {
        setState(() {
          _comments.addAll(response.comments);
          _currentPage = response.pagination.currentPage;
          _hasNextPage = response.pagination.hasNextPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('[CommentBottomSheet] Error loading more comments: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải thêm comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _postComment() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để bình luận!'))
      );
      return;
    }

    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    if (commentText.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment không được vượt quá 500 ký tự!'))
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final newComment = await _commentService.addComment(
        widget.videoId,
        authService.currentUser!.id,
        commentText,
      );

      if (mounted) {
        setState(() {
          _comments.insert(0, newComment); // Add to top
          _commentController.clear();
          _commentsCount += 1;
          _isPosting = false;
        });
        
        // Update parent widget
        widget.onCommentsCountChanged?.call(_commentsCount);
        
        // Hide keyboard
        _focusNode.unfocus();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment đã được đăng!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[CommentBottomSheet] Error posting comment: $e');
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi đăng comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editComment(CommentModel comment, String newText) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) return;

    // Check if user owns the comment
    if (comment.userId != authService.currentUser!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chỉ có thể chỉnh sửa comment của mình!'))
      );
      return;
    }

    // Prevent multiple edit requests for the same comment
    if (_editingComments.contains(comment.id)) {
      print('[CommentBottomSheet] Edit already in progress for comment: ${comment.id}');
      return;
    }

    print('[CommentBottomSheet] Starting edit process for comment: ${comment.id}');
    
    setState(() {
      _editingComments.add(comment.id);
    });

    try {
      final updatedComment = await _commentService.editComment(
        comment.id, 
        authService.currentUser!.id, 
        newText
      );
      
      if (mounted) {
        setState(() {
          // Find and replace the comment in the list
          final index = _comments.indexWhere((c) => c.id == comment.id);
          if (index != -1) {
            _comments[index] = updatedComment;
          }
          _editingComments.remove(comment.id);
        });
        
        print('[CommentBottomSheet] Comment edited successfully: ${comment.id}');
      }
    } catch (e) {
      print('[CommentBottomSheet] Error editing comment: $e');
      if (mounted) {
        setState(() {
          _editingComments.remove(comment.id);
        });
        
        // Show more specific error messages
        String errorMessage = 'Lỗi khi chỉnh sửa comment';
        if (e.toString().contains('Connection refused') || e.toString().contains('Failed host lookup')) {
          errorMessage = 'Không thể kết nối đến server';
        } else if (e.toString().contains('404')) {
          errorMessage = 'Không tìm thấy comment để chỉnh sửa';
        } else if (e.toString().contains('403')) {
          errorMessage = 'Bạn không có quyền chỉnh sửa comment này';
        } else if (e.toString().contains('401')) {
          errorMessage = 'Vui lòng đăng nhập lại';
        }
        
        throw Exception(errorMessage); // Re-throw to be handled by EditCommentDialog
      }
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) return;

    // Check if user owns the comment
    if (comment.userId != authService.currentUser!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chỉ có thể xóa comment của mình!'))
      );
      return;
    }

    // Prevent multiple delete requests for the same comment
    if (_deletingComments.contains(comment.id)) {
      print('[CommentBottomSheet] Delete already in progress for comment: ${comment.id}');
      return;
    }

    print('[CommentBottomSheet] Starting delete process for comment: ${comment.id}');
    
    setState(() {
      _deletingComments.add(comment.id);
    });

    try {
      await _commentService.deleteComment(comment.id, authService.currentUser!.id);
      
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
          _commentsCount = (_commentsCount - 1).clamp(0, double.infinity).toInt();
          _deletingComments.remove(comment.id);
        });
        
        // Update parent widget
        widget.onCommentsCountChanged?.call(_commentsCount);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Comment đã được xóa!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        print('[CommentBottomSheet] Comment deleted successfully: ${comment.id}');
      }
    } catch (e) {
      print('[CommentBottomSheet] Error deleting comment: $e');
      if (mounted) {
        setState(() {
          _deletingComments.remove(comment.id);
        });
        
        // Show more specific error messages
        String errorMessage = 'Lỗi khi xóa comment';
        if (e.toString().contains('Connection refused') || e.toString().contains('Failed host lookup')) {
          errorMessage = 'Không thể kết nối đến server';
        } else if (e.toString().contains('404')) {
          errorMessage = 'Không tìm thấy comment để xóa';
        } else if (e.toString().contains('403')) {
          errorMessage = 'Bạn không có quyền xóa comment này';
        } else if (e.toString().contains('401')) {
          errorMessage = 'Vui lòng đăng nhập lại';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Thử lại',
              textColor: Colors.white,
              onPressed: () => _deleteComment(comment),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    
    return Container(
      height: mediaQuery.size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bình luận',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '$_commentsCount',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  iconSize: 24,
                ),
              ],
            ),
          ),
          
          // Comments List
          Expanded(
            child: _buildCommentsList(),
          ),
          
          // Comment Input
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + keyboardHeight,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: _buildCommentInput(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading && _comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_hasError && _comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Lỗi khi tải comment',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (_errorMessage != null) 
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadComments,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    
    if (_comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Chưa có comment nào',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy là người đầu tiên bình luận!',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == _comments.length) {
          // Loading more indicator
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final comment = _comments[index];
        final isDeleting = _deletingComments.contains(comment.id);
        final isEditing = _editingComments.contains(comment.id);
        
        return AnimatedOpacity(
          opacity: isDeleting || isEditing ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: comment.id == _highlightedCommentId 
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: comment.id == _highlightedCommentId 
                  ? Border.all(color: Colors.blue.withOpacity(0.3), width: 2)
                  : null,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: comment.id == _highlightedCommentId 
                      ? const EdgeInsets.all(8.0)
                      : EdgeInsets.zero,
                  child: CommentItemWidget(
                    comment: comment,
                    onDelete: isDeleting ? null : () => _deleteComment(comment),
                    onEdit: isEditing ? null : (newText) => _editComment(comment, newText),
                  ),
                ),
                if (isDeleting || isEditing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withOpacity(0.7),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isDeleting ? 'Deleting...' : 'Editing...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            focusNode: _focusNode,
            maxLength: 500,
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _postComment(),
            decoration: InputDecoration(
              hintText: 'Thêm bình luận...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              counterText: '', // Hide character counter
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _commentController,
          builder: (context, value, child) {
            final hasText = value.text.trim().isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: IconButton(
                onPressed: _isPosting || !hasText ? null : _postComment,
                icon: _isPosting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.send,
                        color: hasText ? Colors.blue : Colors.grey,
                      ),
              ),
            );
          },
        ),
      ],
    );
  }
}