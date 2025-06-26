// tiktok_frontend/lib/src/features/feed/presentation/views/video_feed_view.dart - FIXED VERSION
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/feed/domain/models/video_post_model.dart';
import 'package:tiktok_frontend/src/features/feed/domain/services/video_service.dart';
import 'package:tiktok_frontend/src/features/feed/presentation/widgets/full_screen_video_item.dart';
import 'package:video_player/video_player.dart';

class VideoFeedView extends StatefulWidget {
  const VideoFeedView({super.key});

  @override
  State<VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends State<VideoFeedView>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final VideoService _videoService = VideoService();
  final PageController _pageController = PageController();
  final Map<int, VideoPlayerController> _videoControllers = {};

  List<VideoPost> _videos = [];
  int _currentVideoIndex = 0;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;

  // Platform detection
  final bool _isWeb = kIsWeb;

  @override
  void initState() {
    super.initState();
    debugPrint('[VideoFeedView] Initializing video feed...');
    WidgetsBinding.instance.addObserver(this);
    _loadVideos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    // Dispose all video controllers
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    debugPrint('[VideoFeedView] Disposed');
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // Pause current video when app goes to background
      _pauseCurrentVideo();
    } else if (state == AppLifecycleState.resumed) {
      // Resume current video when app comes back
      _playCurrentVideo();
    }
  }

  void _pauseCurrentVideo() {
    if (_videoControllers.containsKey(_currentVideoIndex)) {
      final controller = _videoControllers[_currentVideoIndex];
      if (controller?.value.isInitialized == true && controller!.value.isPlaying) {
        controller.pause();
      }
    }
  }

  void _playCurrentVideo() {
    if (_videoControllers.containsKey(_currentVideoIndex)) {
      final controller = _videoControllers[_currentVideoIndex];
      if (controller?.value.isInitialized == true && !controller!.value.isPlaying) {
        controller.play();
      }
    }
  }

  Future<void> _loadVideos() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    debugPrint('[VideoFeedView] Loading videos, page: $_currentPage');

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      final response = await _videoService.getVideoFeed(
        page: _currentPage,
        limit: 10,
        currentUserId: currentUserId,
      );

      if (mounted) {
        setState(() {
          if (_currentPage == 1) {
            _videos = response.videos;
          } else {
            _videos.addAll(response.videos);
          }
          _hasNextPage = response.pagination.hasNextPage;
          _isLoading = false;
        });
        
        debugPrint('[VideoFeedView] Loaded ${response.videos.length} videos');
        debugPrint('[VideoFeedView] Total videos: ${_videos.length}');
      }
    } catch (e) {
      debugPrint('[VideoFeedView] Error loading videos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        
        // Show error snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Lỗi tải video: $e'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Thử lại',
                textColor: Colors.white,
                onPressed: _loadVideos,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasNextPage) return;

    debugPrint('[VideoFeedView] Loading more videos...');

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      await _loadVideos();
    } catch (e) {
      debugPrint('[VideoFeedView] Error loading more videos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshVideos() async {
    debugPrint('[VideoFeedView] Refreshing videos...');
    
    // Reset pagination
    _currentPage = 1;
    _hasNextPage = true;
    
    // Clear existing videos and controllers
    setState(() {
      _videos.clear();
    });
    
    // Dispose old controllers
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    
    await _loadVideos();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentVideoIndex = index;
    });

    debugPrint('[VideoFeedView] Page changed to: $index');

    // Pause previous video
    _videoControllers.forEach((key, controller) {
      if (key != index && controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
      }
    });

    // Load more videos when near the end
    if (index >= _videos.length - 2 && _hasNextPage && !_isLoadingMore) {
      _loadMoreVideos();
    }
  }

  void _onVideoInitialized(int index, VideoPlayerController controller) {
    _videoControllers[index] = controller;
    
    // Auto-play current video
    if (index == _currentVideoIndex) {
      controller.play();
    }
  }

  void _onVideoDispose(int index) {
    if (_videoControllers.containsKey(index)) {
      _videoControllers.remove(index);
    }
  }

  // FIXED: Use copyWith instead of direct assignment
  Future<void> _handleLikeVideo(int index) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      _showLoginRequiredSnackBar();
      return;
    }

    final video = _videos[index];
    debugPrint('[VideoFeedView] Toggling like for video: ${video.id}');

    // Store original state for potential revert
    final originalVideo = video;

    // Optimistic update using copyWith
    final updatedVideo = video.copyWith(
      isLikedByCurrentUser: !video.isLikedByCurrentUser,
      likesCount: video.isLikedByCurrentUser ? video.likesCount - 1 : video.likesCount + 1,
    );
    
    setState(() {
      _videos[index] = updatedVideo;
    });

    try {
      final result = await _videoService.toggleLikeVideo(
        video.id,
        authService.currentUser!.id,
      );
      
      // Update with actual result from server
      final serverUpdatedVideo = originalVideo.copyWith(
        isLikedByCurrentUser: result.isLiked,
        likesCount: result.likesCount,
      );
      
      setState(() {
        _videos[index] = serverUpdatedVideo;
      });
      
      debugPrint('[VideoFeedView] Like toggled successfully: ${result.isLiked}');
    } catch (e) {
      debugPrint('[VideoFeedView] Error toggling like: $e');
      
      // Revert optimistic update
      setState(() {
        _videos[index] = originalVideo;
      });
      
      _showErrorSnackBar('Lỗi khi thích video: $e');
    }
  }

  // FIXED: Use copyWith instead of direct assignment
  Future<void> _handleSaveVideo(int index) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      _showLoginRequiredSnackBar();
      return;
    }

    final video = _videos[index];
    debugPrint('[VideoFeedView] Toggling save for video: ${video.id}');

    // Store original state for potential revert
    final originalVideo = video;

    // Optimistic update using copyWith
    final updatedVideo = video.copyWith(
      isSavedByCurrentUser: !video.isSavedByCurrentUser,
    );
    
    setState(() {
      _videos[index] = updatedVideo;
    });

    try {
      final result = await _videoService.toggleSaveVideo(
        video.id,
        authService.currentUser!.id,
      );
      
      // Update with actual result from server
      final serverUpdatedVideo = originalVideo.copyWith(
        isSavedByCurrentUser: result.isSaved,
      );
      
      setState(() {
        _videos[index] = serverUpdatedVideo;
      });
      
      debugPrint('[VideoFeedView] Save toggled successfully: ${result.isSaved}');
    } catch (e) {
      debugPrint('[VideoFeedView] Error toggling save: $e');
      
      // Revert optimistic update
      setState(() {
        _videos[index] = originalVideo;
      });
      
      _showErrorSnackBar('Lỗi khi lưu video: $e');
    }
  }

  void _showLoginRequiredSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vui lòng đăng nhập để thực hiện hành động này!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Loading state
    if (_isLoading && _videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    // Error state
    if (_hasError && _videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Không thể tải video',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
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
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshVideos,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (_videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 64,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có video nào',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hãy tải lên video đầu tiên!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshVideos,
                icon: const Icon(Icons.refresh),
                label: const Text('Làm mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Video feed
    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _refreshVideos,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _onPageChanged,
          itemCount: _videos.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Loading indicator for more videos
            if (index >= _videos.length) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            }

            final video = _videos[index];
            final isActive = index == _currentVideoIndex;

            return FullScreenVideoItem(
              key: ValueKey(video.id),
              videoPost: video,
              isActive: isActive,
              onVideoInitialized: (controller) => _onVideoInitialized(index, controller),
              onDispose: () => _onVideoDispose(index),
              onLikeButtonPressed: () => _handleLikeVideo(index),
              onSaveButtonPressed: () => _handleSaveVideo(index),
            );
          },
        ),
      ),
    );
  }
}