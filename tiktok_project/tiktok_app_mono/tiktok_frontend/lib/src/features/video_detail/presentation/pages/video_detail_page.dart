// tiktok_frontend/lib/src/features/video_detail/presentation/pages/video_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/feed/domain/models/video_post_model.dart';
import 'package:tiktok_frontend/src/features/feed/domain/services/video_service.dart';
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
  VideoPlayerController? _videoController;
  VideoPost? _videoPost;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlaying = false;
  
  // Comments state
  final GlobalKey<CommentBottomSheetState> _commentSheetKey = GlobalKey<CommentBottomSheetState>();
  int _commentsCount = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('[VideoDetailPage] initState with videoId: ${widget.videoId}, highlightCommentId: ${widget.highlightCommentId}');
    _loadVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadVideo() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      debugPrint('[VideoDetailPage] Loading video: ${widget.videoId}');
      
      final video = await _videoService.getVideoById(widget.videoId, currentUserId: currentUserId);
      
      if (video == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Video not found';
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _videoPost = video;
          _commentsCount = video.commentsCount;
          _isLoading = false;
        });
      }

      // Initialize video player
      await _initializeVideoPlayer();
      
      // Show comments immediately if we have a highlight comment
      if (widget.highlightCommentId != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCommentsWithHighlight();
        });
      }

    } catch (e) {
      debugPrint('[VideoDetailPage] Error loading video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_videoPost == null || _videoPost!.videoUrl.isEmpty) return;

    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(_videoPost!.videoUrl),
      );

      await _videoController!.initialize();
      await _videoController!.setLooping(true);

      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
        _videoController!.play();
      }
    } catch (e) {
      debugPrint('[VideoDetailPage] Error initializing video player: $e');
    }
  }

  void _togglePlayPause() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  void _showCommentsWithHighlight() {
    debugPrint('[VideoDetailPage] Showing comments with highlight: ${widget.highlightCommentId}');
    
    // Pause video when showing comments
    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.pause();
      setState(() {
        _isPlaying = false;
      });
    }

    // Show comment bottom sheet with highlight
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(
        key: _commentSheetKey,
        videoId: widget.videoId,
        initialCommentsCount: _commentsCount,
        highlightCommentId: widget.highlightCommentId,
        onCommentsCountChanged: (newCount) {
          if (mounted) {
            setState(() {
              _commentsCount = newCount;
            });
          }
        },
      ),
    ).then((_) {
      // Resume video when comments are closed
      if (_videoController != null && _videoController!.value.isInitialized) {
        _videoController!.play();
        setState(() {
          _isPlaying = true;
        });
      }
    });
  }

  void _showCommentsNormal() {
    debugPrint('[VideoDetailPage] Showing comments without highlight');
    
    // Pause video when showing comments
    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.pause();
      setState(() {
        _isPlaying = false;
      });
    }

    // Show comment bottom sheet without highlight
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(
        key: _commentSheetKey,
        videoId: widget.videoId,
        initialCommentsCount: _commentsCount,
        highlightCommentId: null, // No highlight
        onCommentsCountChanged: (newCount) {
          if (mounted) {
            setState(() {
              _commentsCount = newCount;
            });
          }
        },
      ),
    ).then((_) {
      // Resume video when comments are closed
      if (_videoController != null && _videoController!.value.isInitialized) {
        _videoController!.play();
        setState(() {
          _isPlaying = true;
        });
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_videoPost == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập để thích video!'))
        );
      }
      return;
    }

    try {
      final result = await _videoService.toggleLikeVideo(
        _videoPost!.id,
        authService.currentUser!.id,
      );

      if (mounted) {
        setState(() {
          // Create a new VideoPost instance with updated values
          _videoPost = _videoPost!.copyWith(
            isLikedByCurrentUser: result.isLiked,
            likesCount: result.likesCount,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thích video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleSave() async {
    if (_videoPost == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập để lưu video!'))
        );
      }
      return;
    }

    try {
      final result = await _videoService.toggleSaveVideo(
        _videoPost!.id,
        authService.currentUser!.id,
      );

      if (mounted) {
        setState(() {
          // Create a new VideoPost instance with updated values
          _videoPost = _videoPost!.copyWith(
            isSavedByCurrentUser: result.isSaved,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.highlightCommentId != null ? 'Video từ thông báo' : 'Chi tiết Video',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          if (widget.highlightCommentId != null)
            IconButton(
              onPressed: _showCommentsWithHighlight,
              icon: const Icon(Icons.comment_outlined),
              tooltip: 'Xem comment được highlight',
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

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Lỗi tải video',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadVideo,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_videoPost == null) {
      return const Center(
        child: Text(
          'Video không tồn tại',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return Stack(
      children: [
        // Video player
        GestureDetector(
          onTap: _togglePlayPause,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: _videoController != null && _videoController!.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
        ),

        // Play/Pause overlay
        if (!_isPlaying && _videoController != null && _videoController!.value.isInitialized)
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _togglePlayPause,
                icon: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          ),

        // Bottom content overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Colors.transparent,
                  Colors.black54,
                ],
              ),
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Video info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // User info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _videoPost!.user.avatarUrl != null
                                  ? NetworkImage(_videoPost!.user.avatarUrl!)
                                  : null,
                              child: _videoPost!.user.avatarUrl == null
                                  ? const Icon(Icons.person, size: 20)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '@${_videoPost!.user.username}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Description
                        Text(
                          _videoPost!.description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Hashtags
                        if (_videoPost!.hashtags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _videoPost!.hashtags.map((h) => '#$h').join(' '),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        // Highlight comment indicator
                        if (widget.highlightCommentId != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Comment được highlight',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action buttons
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Like button
                      _buildActionButton(
                        icon: _videoPost!.isLikedByCurrentUser
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: _videoPost!.likesCount.toString(),
                        onPressed: _toggleLike,
                        iconColor: _videoPost!.isLikedByCurrentUser
                            ? Colors.red
                            : Colors.white,
                      ),
                      const SizedBox(height: 16),

                      // Comment button
                      _buildActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: _commentsCount.toString(),
                        onPressed: _showCommentsNormal,
                      ),
                      const SizedBox(height: 16),

                      // Save button
                      _buildActionButton(
                        icon: _videoPost!.isSavedByCurrentUser
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        label: 'Save',
                        onPressed: _toggleSave,
                        iconColor: _videoPost!.isSavedByCurrentUser
                            ? Colors.yellow
                            : Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color iconColor = Colors.white,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 30,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}