// tiktok_frontend/lib/src/features/feed/presentation/views/video_feed_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

class _VideoFeedViewState extends State<VideoFeedView> {
  Future<List<VideoPost>>? _feedVideosFuture;
  final VideoService _videoService = VideoService();
  
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  final Map<int, VideoPlayerController> _videoControllers = {}; 
  List<VideoPost> _currentVideos = [];
  
  // Track pending operations to prevent multiple API calls
  final Set<String> _pendingLikes = {};
  final Set<String> _pendingSaves = {};

  // Pull to refresh variables - cross-platform compatible
  bool _isRefreshing = false;
  double _refreshProgress = 0.0;
  late double _refreshThreshold;
  bool _canPullToRefresh = true;
  bool _isDragging = false;
  double _startDragPosition = 0.0;
  
  // For web compatibility
  bool _isWeb = kIsWeb;

  @override
  void initState() {
    super.initState();
    print('[VideoFeedView] initState - Platform: ${_isWeb ? "Web" : "Mobile"}');
    
    // Calculate responsive threshold based on screen size and platform
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenHeight = MediaQuery.of(context).size.height;
        // Web needs smaller threshold due to mouse scroll sensitivity
        _refreshThreshold = _isWeb 
          ? (screenHeight * 0.05).clamp(30.0, 60.0)  // 5% for web, 30-60px
          : (screenHeight * 0.1).clamp(60.0, 120.0); // 10% for mobile, 60-120px
        print('[VideoFeedView] Refresh threshold set to: $_refreshThreshold');
        _loadVideos();
      }
    });

    _pageController.addListener(() {
      final newPageDouble = _pageController.page;
      if (newPageDouble == null) return;
      final newPage = newPageDouble.round();
      if (newPage != _currentPageIndex) {
        print('[VideoFeedView] PageController scrolled to page $newPage. Old page: $_currentPageIndex');
        _videoControllers[_currentPageIndex]?.pause();
        _videoControllers[newPage]?.play();
        if (mounted) {
          setState(() { 
            _currentPageIndex = newPage;
            // Enable pull to refresh only on first video
            _canPullToRefresh = newPage == 0;
            // Reset refresh progress when changing videos
            if (newPage != 0) {
              _refreshProgress = 0.0;
            }
          });
        }
      }
    });
  }

  void _loadVideos() {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final String? currentUserId = authService.currentUser?.id;
    print('[VideoFeedView] _loadVideos called. CurrentUserId: $currentUserId');
    
    setState(() {
      _feedVideosFuture = _videoService.getFeedVideos(currentUserId: currentUserId, limit: 10).then((videos) {
        if(mounted) {
          setState(() { _currentVideos = videos; });
        }
        return videos;
      }).catchError((error, stackTrace) {
        print('[VideoFeedView] Error in _loadVideos future: $error');
        print('[VideoFeedView] StackTrace for _loadVideos error: $stackTrace');
        if(mounted) {
           setState(() { _currentVideos = []; });
        }
        throw error; 
      });
    });
  }

  Future<void> _refreshVideos() async {
    if (_isRefreshing) return;
    
    print('[VideoFeedView] Pull to refresh triggered');
    setState(() {
      _isRefreshing = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final String? currentUserId = authService.currentUser?.id;
      
      // Pause current video during refresh
      _videoControllers[_currentPageIndex]?.pause();
      
      final newVideos = await _videoService.getFeedVideos(currentUserId: currentUserId, limit: 10);
      
      if (mounted) {
        setState(() {
          _currentVideos = newVideos;
          _currentPageIndex = 0; // Reset to first video
        });
        
        // Reset page controller to first page smoothly
        if (_pageController.hasClients) {
          await _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        
        // Play first video after refresh
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _videoControllers[0] != null) {
            _videoControllers[0]?.play();
          }
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.refresh, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Feed đã được làm mới!'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('[VideoFeedView] Error refreshing videos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Lỗi khi làm mới: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _refreshProgress = 0.0;
          _isDragging = false;
        });
      }
    }
  }

  // Universal drag start handler (works for both touch and mouse)
  void _handleDragStart(DragStartDetails details) {
    if (!_canPullToRefresh || _isRefreshing || _currentPageIndex != 0) return;
    
    _startDragPosition = details.globalPosition.dy;
    _isDragging = true;
    print('[VideoFeedView] Drag start at: $_startDragPosition (${_isWeb ? "Web" : "Mobile"})');
  }

  // Universal drag update handler
  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_canPullToRefresh || _isRefreshing || _currentPageIndex != 0 || !_isDragging) return;
    
    final currentPosition = details.globalPosition.dy;
    final dragDistance = currentPosition - _startDragPosition;
    
    // Only allow downward drag
    if (dragDistance > 0) {
      setState(() {
        // Web needs different sensitivity
        final sensitivity = _isWeb ? 1.5 : 1.0;
        _refreshProgress = (dragDistance * sensitivity).clamp(0.0, _refreshThreshold * 1.5);
      });
      
      print('[VideoFeedView] Drag distance: $dragDistance, Progress: $_refreshProgress, Threshold: $_refreshThreshold');
    }
  }

  // Universal drag end handler
  void _handleDragEnd(DragEndDetails details) {
    if (!_canPullToRefresh || _isRefreshing || _currentPageIndex != 0) {
      setState(() {
        _refreshProgress = 0.0;
        _isDragging = false;
      });
      return;
    }
    
    print('[VideoFeedView] Drag end. Progress: $_refreshProgress, Threshold: $_refreshThreshold');
    
    // Trigger refresh if threshold is reached
    if (_refreshProgress >= _refreshThreshold) {
      _refreshVideos();
    } else {
      // Animate progress back to 0
      _animateProgressToZero();
    }
    
    _isDragging = false;
  }

  void _animateProgressToZero() {
    if (!mounted) return;
    
    const duration = Duration(milliseconds: 200);
    const steps = 10;
    final stepValue = _refreshProgress / steps;
    
    for (int i = 1; i <= steps; i++) {
      Future.delayed(Duration(milliseconds: (duration.inMilliseconds / steps * i).round()), () {
        if (mounted && !_isRefreshing) {
          setState(() {
            _refreshProgress = (_refreshProgress - stepValue).clamp(0.0, double.infinity);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    print('[VideoFeedView] dispose called. Disposing all video controllers.');
    _pageController.dispose();
    _videoControllers.forEach((index, controller) {
      print('[VideoFeedView] Disposing controller for index $index from VideoFeedView dispose.');
      controller.dispose();
    });
    _videoControllers.clear();
    super.dispose();
  }

  void _registerVideoController(int index, VideoPlayerController controller) {
    print('[VideoFeedView] Registering controller for video at index $index. Initialized: ${controller.value.isInitialized}');
    _videoControllers[index] = controller;
    if (index == _currentPageIndex && controller.value.isInitialized && mounted && !controller.value.isPlaying) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && index == _currentPageIndex && !controller.value.isPlaying) {
            print('[VideoFeedView] Auto-playing video at index $index after registration.');
            controller.play();
        }
       });
    }
  }

  void _unregisterVideoController(int index) {
    print('[VideoFeedView] Unregistering controller for video at index $index');
    _videoControllers.remove(index);
  }

  Future<void> _handleLikeToggle(int videoIndexInList) async {
    if (videoIndexInList < 0 || videoIndexInList >= _currentVideos.length) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để thích video!'))
      );
      return;
    }
    
    final String currentUserId = authService.currentUser!.id;
    final VideoPost videoToUpdate = _currentVideos[videoIndexInList];
    final String videoId = videoToUpdate.id;

    // Prevent multiple simultaneous requests for the same video
    if (_pendingLikes.contains(videoId)) {
      print('[VideoFeedView] Like request already pending for video: $videoId');
      return;
    }

    print('[VideoFeedView] Toggling like for video: $videoId by user: $currentUserId');
    
    // Store original values for rollback
    final originalIsLiked = videoToUpdate.isLikedByCurrentUser;
    final originalLikesCount = videoToUpdate.likesCount;

    // Optimistic UI update
    setState(() {
      videoToUpdate.isLikedByCurrentUser = !videoToUpdate.isLikedByCurrentUser;
      videoToUpdate.likesCount += videoToUpdate.isLikedByCurrentUser ? 1 : -1;
    });

    _pendingLikes.add(videoId);

    try {
      final result = await _videoService.toggleLikeVideo(videoId, currentUserId);
      
      if (mounted) {
        setState(() {
          // Update from server response to ensure consistency
          videoToUpdate.isLikedByCurrentUser = result['isLikedByCurrentUser'] as bool? ?? originalIsLiked;
          videoToUpdate.likesCount = result['likesCount'] as int? ?? originalLikesCount;
        });
      }
    } catch (e) {
      print('[VideoFeedView] Error toggling like: $e');
      
      if (mounted) {
        // Rollback optimistic update on error
        setState(() {
          videoToUpdate.isLikedByCurrentUser = originalIsLiked;
          videoToUpdate.likesCount = originalLikesCount;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thích video: ${e.toString()}'),
            backgroundColor: Colors.red,
          )
        );
      }
    } finally {
      _pendingLikes.remove(videoId);
    }
  }

  Future<void> _handleSaveToggle(int videoIndexInList) async {
    if (videoIndexInList < 0 || videoIndexInList >= _currentVideos.length) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để lưu video!'))
      );
      return;
    }
    
    final String currentUserId = authService.currentUser!.id;
    final VideoPost videoToUpdate = _currentVideos[videoIndexInList];
    final String videoId = videoToUpdate.id;

    // Prevent multiple simultaneous requests
    if (_pendingSaves.contains(videoId)) {
      print('[VideoFeedView] Save request already pending for video: $videoId');
      return;
    }

    print('[VideoFeedView] Toggling save for video: $videoId');

    final originalIsSaved = videoToUpdate.isSavedByCurrentUser;
    
    // Optimistic UI update
    setState(() {
      videoToUpdate.isSavedByCurrentUser = !videoToUpdate.isSavedByCurrentUser;
    });

    _pendingSaves.add(videoId);

    try {
      final result = await _videoService.toggleSaveVideo(videoId, currentUserId);
      
      if (mounted) {
        setState(() {
          videoToUpdate.isSavedByCurrentUser = result['isSavedByCurrentUser'] as bool? ?? originalIsSaved;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Đã cập nhật trạng thái lưu'),
            duration: const Duration(seconds: 1),
          )
        );
      }
    } catch (e) {
      print('[VideoFeedView] Error toggling save: $e');
      
      if (mounted) {
        // Rollback optimistic update on error
        setState(() {
          videoToUpdate.isSavedByCurrentUser = originalIsSaved;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu video: ${e.toString()}'),
            backgroundColor: Colors.red,
          )
        );
      }
    } finally {
      _pendingSaves.remove(videoId);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[VideoFeedView] build called. Current page index: $_currentPageIndex');
    
    return FutureBuilder<List<VideoPost>>(
      future: _feedVideosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _currentVideos.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        } 
        
        if (snapshot.hasError && _currentVideos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Lỗi tải video: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                  onPressed: _loadVideos,
                )
              ],
            ),
          );
        }
        
        final videosToDisplay = _currentVideos.isNotEmpty ? _currentVideos : (snapshot.data ?? []);
        
        if (videosToDisplay.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshVideos,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Không có video nào. Hãy upload!'),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tải lại Feed'),
                        onPressed: _loadVideos,
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        print('[VideoFeedView] Displaying ${videosToDisplay.length} videos.');
        
        return Stack(
          children: [
            // Main PageView with cross-platform drag detection
            GestureDetector(
              // Use both pan and vertical drag for better cross-platform support
              onPanStart: _handleDragStart,
              onPanUpdate: _handleDragUpdate,
              onPanEnd: _handleDragEnd,
              // Add vertical drag for better web support
              onVerticalDragStart: _handleDragStart,
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: videosToDisplay.length,
                itemBuilder: (context, index) {
                  final videoPost = videosToDisplay[index];
                  return FullScreenVideoItem(
                    key: ValueKey('video_${videoPost.id}'),
                    videoPost: videoPost,
                    isActive: index == _currentPageIndex,
                    onVideoInitialized: (controller) => _registerVideoController(index, controller),
                    onDispose: () => _unregisterVideoController(index),
                    onLikeButtonPressed: () => _handleLikeToggle(index),
                    onSaveButtonPressed: () => _handleSaveToggle(index),
                  );
                },
              ),
            ),
            
            // Cross-platform pull to refresh indicator
            if (_canPullToRefresh && _currentPageIndex == 0 && (_refreshProgress > 0 || _isRefreshing))
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: _isRefreshing ? 0 : 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isRefreshing)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              value: (_refreshProgress / _refreshThreshold).clamp(0.0, 1.0),
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _refreshProgress >= _refreshThreshold ? Colors.green : Colors.white,
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Text(
                          _isRefreshing 
                            ? 'Đang làm mới...' 
                            : _refreshProgress >= _refreshThreshold 
                              ? 'Thả để làm mới!' 
                              : _isWeb ? 'Kéo xuống để làm mới (Web)' : 'Kéo xuống để làm mới',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Enhanced refresh hint with platform-specific instructions
            if (_canPullToRefresh && _currentPageIndex == 0 && _refreshProgress == 0 && !_isRefreshing)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh,
                        color: Colors.white.withOpacity(0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isWeb ? 'Drag' : 'Pull',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}