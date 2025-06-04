// tiktok_frontend/lib/src/features/feed/presentation/views/video_feed_view.dart
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

  @override
  void initState() {
    super.initState();
    print('[VideoFeedView] initState');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadVideos(); 
    });

    _pageController.addListener(() {
      final newPageDouble = _pageController.page;
      if (newPageDouble == null) return;
      final newPage = newPageDouble.round();
      if (newPage != _currentPageIndex) {
        print('[VideoFeedView] PageController scrolled to page $newPage. Old page: $_currentPageIndex');
        _videoControllers[_currentPageIndex]?.pause();
        _videoControllers[newPage]?.play();
        if (mounted) setState(() { _currentPageIndex = newPage; });
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Không có video nào. Hãy upload!'),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tải lại Feed'),
                  onPressed: _loadVideos,
                )
              ],
            ),
          );
        }

        print('[VideoFeedView] Displaying ${videosToDisplay.length} videos.');
        
        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: videosToDisplay.length,
          itemBuilder: (context, index) {
            final videoPost = videosToDisplay[index];
            return FullScreenVideoItem(
              key: ValueKey('video_${videoPost.id}'), // Simplified key to reduce rebuilds
              videoPost: videoPost,
              isActive: index == _currentPageIndex,
              onVideoInitialized: (controller) => _registerVideoController(index, controller),
              onDispose: () => _unregisterVideoController(index),
              onLikeButtonPressed: () => _handleLikeToggle(index),
              onSaveButtonPressed: () => _handleSaveToggle(index),
            );
          },
        );
      },
    );
  }
}