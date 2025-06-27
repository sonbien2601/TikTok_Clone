// tiktok_frontend/lib/src/features/video_detail/presentation/pages/video_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/feed/domain/models/video_post_model.dart';
import 'package:tiktok_frontend/src/features/feed/domain/services/video_service.dart';
import 'package:tiktok_frontend/src/features/feed/presentation/widgets/full_screen_video_item.dart';
import 'package:tiktok_frontend/src/features/feed/presentation/widgets/comment_bottom_sheet.dart';

class VideoDetailPage extends StatefulWidget {
  final String videoId;
  final String? highlightCommentId;

  const VideoDetailPage({
    super.key,
    required this.videoId,
    this.highlightCommentId,
  });

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final VideoService _videoService = VideoService();
  
  VideoPost? _video;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isVideoNotFound = false;

  @override
  void initState() {
    super.initState();
    print('[VideoDetailPage] initState with videoId: ${widget.videoId}, highlightCommentId: ${widget.highlightCommentId}');
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    print('[VideoDetailPage] Loading video: ${widget.videoId}');
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
      _isVideoNotFound = false;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;

      final video = await _videoService.getVideoById(
        widget.videoId,
        currentUserId: currentUserId,
      );

      if (mounted) {
        if (video != null) {
          setState(() {
            _video = video;
            _isLoading = false;
          });
          
          // Show comments if there's a highlighted comment
          if (widget.highlightCommentId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showCommentsWithHighlight();
            });
          }
        } else {
          setState(() {
            _isLoading = false;
            _isVideoNotFound = true;
            _errorMessage = 'Video không tồn tại hoặc đã bị xóa';
          });
        }
      }
    } catch (e) {
      print('[VideoDetailPage] Error loading video: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          
          if (e.toString().contains('404') || 
              e.toString().contains('not found') ||
              e.toString().contains('Video not found')) {
            _isVideoNotFound = true;
            _errorMessage = 'Video không tồn tại hoặc đã bị xóa';
          } else if (e.toString().contains('Connection refused') || 
                     e.toString().contains('Failed host lookup')) {
            _errorMessage = 'Không thể kết nối đến server';
          } else {
            _errorMessage = 'Lỗi khi tải video: ${e.toString()}';
          }
        });
      }
    }
  }

  void _showCommentsWithHighlight() {
    if (_video == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(
        videoId: _video!.id,
        initialCommentsCount: _video!.commentsCount,
        highlightCommentId: widget.highlightCommentId,
        onCommentsCountChanged: (newCount) {
          if (mounted) {
            setState(() {
              _video = _video!.copyWith(commentsCount: newCount);
            });
          }
        },
      ),
    );
  }

  Future<void> _handleLikeVideo() async {
    if (_video == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để thích video!'))
      );
      return;
    }

    // Optimistic update
    final originalVideo = _video!;
    final updatedVideo = _video!.copyWith(
      isLikedByCurrentUser: !_video!.isLikedByCurrentUser,
      likesCount: _video!.isLikedByCurrentUser ? _video!.likesCount - 1 : _video!.likesCount + 1,
    );
    
    setState(() {
      _video = updatedVideo;
    });

    try {
      final result = await _videoService.toggleLikeVideo(
        _video!.id,
        authService.currentUser!.id,
      );
      
      // Update với kết quả từ server
      setState(() {
        _video = originalVideo.copyWith(
          isLikedByCurrentUser: result.isLiked,
          likesCount: result.likesCount,
        );
      });
    } catch (e) {
      // Revert nếu có lỗi
      setState(() {
        _video = originalVideo;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi thích video: $e'))
      );
    }
  }

  Future<void> _handleSaveVideo() async {
    if (_video == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để lưu video!'))
      );
      return;
    }

    // Optimistic update
    final originalVideo = _video!;
    final updatedVideo = _video!.copyWith(
      isSavedByCurrentUser: !_video!.isSavedByCurrentUser,
    );
    
    setState(() {
      _video = updatedVideo;
    });

    try {
      final result = await _videoService.toggleSaveVideo(
        _video!.id,
        authService.currentUser!.id,
      );
      
      // Update với kết quả từ server
      setState(() {
        _video = originalVideo.copyWith(
          isSavedByCurrentUser: result.isSaved,
        );
      });
    } catch (e) {
      // Revert nếu có lỗi
      setState(() {
        _video = originalVideo;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu video: $e'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        title: const Text(
          'Video',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_video != null)
            IconButton(
              onPressed: () => _showCommentsWithHighlight(),
              icon: const Icon(Icons.comment, color: Colors.white),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_isVideoNotFound) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 20),
            Text(
              'Video không tồn tại',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Video này có thể đã bị xóa hoặc không tồn tại. Vui lòng kiểm tra lại.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadVideo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Quay lại'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Lỗi khi tải video',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadVideo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Quay lại'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_video == null) {
      return Center(
        child: Text(
          'Không có dữ liệu video',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
      );
    }

    // Show video
    return FullScreenVideoItem(
      key: ValueKey(_video!.id),
      videoPost: _video!,
      isActive: true,
      onVideoInitialized: (controller) {
        // Video controller initialized
      },
      onDispose: () {
        // Video disposed
      },
      onLikeButtonPressed: _handleLikeVideo,
      onSaveButtonPressed: _handleSaveVideo,
    );
  }
}