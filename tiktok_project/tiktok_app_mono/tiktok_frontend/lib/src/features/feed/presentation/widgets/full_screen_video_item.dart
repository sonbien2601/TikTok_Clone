// tiktok_frontend/lib/src/features/feed/presentation/widgets/full_screen_video_item.dart - UPDATED WITH ANALYTICS
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/feed/domain/models/video_post_model.dart';
import 'package:tiktok_frontend/src/features/feed/presentation/widgets/comment_bottom_sheet.dart';
import 'package:tiktok_frontend/src/features/follow/presentation/widgets/follow_button_widget.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/analytics/domain/services/analytics_service.dart'; // NEW IMPORT

class FullScreenVideoItem extends StatefulWidget {
  final VideoPost videoPost;
  final bool isActive; 
  final Function(VideoPlayerController) onVideoInitialized;
  final VoidCallback onDispose; 
  final VoidCallback onLikeButtonPressed; 
  final VoidCallback onSaveButtonPressed; 

  const FullScreenVideoItem({
    super.key,
    required this.videoPost,
    required this.isActive,
    required this.onVideoInitialized,
    required this.onDispose,
    required this.onLikeButtonPressed,
    required this.onSaveButtonPressed,
  });

  @override
  State<FullScreenVideoItem> createState() => _FullScreenVideoItemState();
}

class _FullScreenVideoItemState extends State<FullScreenVideoItem> with WidgetsBindingObserver {
  VideoPlayerController? _videoPlayerController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControlsOverlay = false; 
  bool _isBuffering = false;
  bool _hasError = false;
  
  // Local state for comments count
  late int _localCommentsCount;
  
  // NEW: Analytics tracking variables
  DateTime? _playStartTime;
  Duration _totalWatchTime = Duration.zero;
  bool _hasTrackedInitialView = false;
  bool _isViewingActivelyTracked = false;
  late AnalyticsService _analyticsService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localCommentsCount = widget.videoPost.commentsCount;
    
    // NEW: Initialize analytics service
    _analyticsService = Provider.of<AnalyticsService>(context, listen: false);
    
    // Debug user info
    print("[FullScreenVideoItem: ${widget.videoPost.id}] === INIT STATE ===");
    print("[FullScreenVideoItem: ${widget.videoPost.id}] Username: '${widget.videoPost.user.username}'");
    print("[FullScreenVideoItem: ${widget.videoPost.id}] Views: ${widget.videoPost.viewsCount}");
    print("[FullScreenVideoItem: ${widget.videoPost.id}] Unique Views: ${widget.videoPost.uniqueViewsCount}");
    print("[FullScreenVideoItem: ${widget.videoPost.id}] URL: ${widget.videoPost.videoUrl}");
    print("[FullScreenVideoItem: ${widget.videoPost.id}] ================");
    
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    await _videoPlayerController?.dispose(); 
    _isInitialized = false; _isPlaying = false; _isBuffering = true; _hasError = false;
    if (mounted) setState((){});

    if (widget.videoPost.videoUrl.isEmpty || !Uri.tryParse(widget.videoPost.videoUrl)!.isAbsolute) {
      print("[FullScreenVideoItem: ${widget.videoPost.id}] Video URL is empty or invalid: '${widget.videoPost.videoUrl}'. Cannot initialize player.");
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoPost.videoUrl));
      
      _videoPlayerController!.addListener(_videoPlayerListener);

      await _videoPlayerController!.initialize();
      print("[FullScreenVideoItem: ${widget.videoPost.id}] Player Initialized. Duration: ${_videoPlayerController!.value.duration}");
      
      await _videoPlayerController!.setLooping(true);
      
      if (mounted) {
        setState(() { _isInitialized = true; _isBuffering = false; });
        widget.onVideoInitialized(_videoPlayerController!); 

        if (widget.isActive) {
          await _videoPlayerController!.play();
          print("[FullScreenVideoItem: ${widget.videoPost.id}] Auto-playing because isActive is true.");
          
          // NEW: Track initial view when video starts playing
          _trackVideoPlay();
        } else {
          await _videoPlayerController!.pause();
        }
      }
    } catch (e, s) {
      print("[FullScreenVideoItem: ${widget.videoPost.id}] Error initializing video player for ${widget.videoPost.videoUrl}: $e");
      print(s);
      if (mounted) setState(() { _isInitialized = false; _hasError = true; _isBuffering = false; });
    }
  }
  
  void _videoPlayerListener() {
    if (!mounted || _videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    final value = _videoPlayerController!.value;
    bool needsSetState = false;
    
    // Handle play/pause state changes
    if (_isPlaying != value.isPlaying) { 
      _isPlaying = value.isPlaying; 
      needsSetState = true;
      
      // NEW: Track play/pause for analytics
      if (_isPlaying) {
        _trackVideoPlay();
      } else {
        _trackVideoPause();
      }
    }
    
    if (_isBuffering != value.isBuffering) { _isBuffering = value.isBuffering; needsSetState = true; }
    if (value.hasError && !_hasError) { 
      print("[FullScreenVideoItem: ${widget.videoPost.id}] VideoPlayerError: ${value.errorDescription}");
      _hasError = true; needsSetState = true;
      
      // NEW: Track error for analytics
      _trackVideoError(value.errorDescription);
    }
    if (needsSetState) setState(() {});
  }

  // NEW: Analytics tracking methods
  void _trackVideoPlay() {
    if (!_isViewingActivelyTracked) {
      _playStartTime = DateTime.now();
      _isViewingActivelyTracked = true;
      
      // Track initial view if not already tracked
      if (!_hasTrackedInitialView) {
        _trackInitialView();
        _hasTrackedInitialView = true;
      }
      
      print("[FullScreenVideoItem: ${widget.videoPost.id}] 📊 Started tracking video play at ${_playStartTime}");
    }
  }

  void _trackVideoPause() {
    if (_isViewingActivelyTracked && _playStartTime != null) {
      final watchDuration = DateTime.now().difference(_playStartTime!);
      _totalWatchTime += watchDuration;
      _isViewingActivelyTracked = false;
      
      print("[FullScreenVideoItem: ${widget.videoPost.id}] 📊 Paused video, watch duration: ${watchDuration.inSeconds}s, total: ${_totalWatchTime.inSeconds}s");
      
      // Track view with duration if watched for at least 1 second
      if (watchDuration.inSeconds >= 1) {
        _trackViewWithDuration(watchDuration.inSeconds);
      }
    }
  }

  void _trackInitialView() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.id;
    
    // Track the initial view
    _analyticsService.autoTrackView(
      videoId: widget.videoPost.id,
      userId: currentUserId,
      viewDuration: 0, // Initial view, no duration yet
      viewSource: 'feed',
    );
    
    print("[FullScreenVideoItem: ${widget.videoPost.id}] 📊 Tracked initial view for user: $currentUserId");
  }

  void _trackViewWithDuration(int durationSeconds) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.id;
    
    // Track view with duration
    _analyticsService.autoTrackView(
      videoId: widget.videoPost.id,
      userId: currentUserId,
      viewDuration: durationSeconds,
      viewSource: 'feed',
    );
    
    print("[FullScreenVideoItem: ${widget.videoPost.id}] 📊 Tracked view with duration: ${durationSeconds}s for user: $currentUserId");
  }

  void _trackVideoError(String? errorDescription) {
    print("[FullScreenVideoItem: ${widget.videoPost.id}] 📊 Video error tracked: $errorDescription");
    // Could implement error tracking to analytics service if needed
  }

  void _trackVideoComplete() {
    // Track when video playback completes (reaches end)
    _trackVideoPause(); // This will handle the final duration tracking
    print("[FullScreenVideoItem: ${widget.videoPost.id}] 📊 Video playback completed");
  }

  @override
  void didUpdateWidget(FullScreenVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Debug when widget updates
    if (widget.videoPost.user.username != oldWidget.videoPost.user.username) {
      print("[FullScreenVideoItem: ${widget.videoPost.id}] ⚠️ Username changed from '${oldWidget.videoPost.user.username}' to '${widget.videoPost.user.username}'");
    }
    
    if (widget.isActive != oldWidget.isActive) {
      print("[FullScreenVideoItem: ${widget.videoPost.id}] isActive changed to ${widget.isActive}");
      if (_isInitialized && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        if (widget.isActive) {
          _videoPlayerController!.play();
        } else {
          _videoPlayerController!.pause();
        }
      }
    }
    
    // NEW: Reset analytics tracking if video changed
    if (widget.videoPost.id != oldWidget.videoPost.id) {
      _resetAnalyticsTracking();
    }
    
    if (widget.videoPost.videoUrl != oldWidget.videoPost.videoUrl) {
        print("[FullScreenVideoItem: ${widget.videoPost.id}] Video URL changed. Re-initializing player.");
        _resetAnalyticsTracking();
        _initializeVideoPlayer();
    }
    if (widget.videoPost.isLikedByCurrentUser != oldWidget.videoPost.isLikedByCurrentUser ||
        widget.videoPost.likesCount != oldWidget.videoPost.likesCount ||
        widget.videoPost.isSavedByCurrentUser != oldWidget.videoPost.isSavedByCurrentUser) {
      if (mounted) {
        print("[FullScreenVideoItem: ${widget.videoPost.id}] Like/Save state updated from prop. Rebuilding.");
        setState(() {});
      }
    }
    // Update local comments count if changed
    if (widget.videoPost.commentsCount != oldWidget.videoPost.commentsCount) {
      setState(() {
        _localCommentsCount = widget.videoPost.commentsCount;
      });
    }
  }

  // NEW: Reset analytics tracking state
  void _resetAnalyticsTracking() {
    _trackVideoPause(); // Track any remaining time from previous video
    _playStartTime = null;
    _totalWatchTime = Duration.zero;
    _hasTrackedInitialView = false;
    _isViewingActivelyTracked = false;
    print("[FullScreenVideoItem: ${widget.videoPost.id}] 📊 Analytics tracking reset");
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_isInitialized || _videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    
    if (state == AppLifecycleState.paused) {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
        // Analytics tracking will be handled by _videoPlayerListener
      }
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isActive) {
        _videoPlayerController!.play();
        // Analytics tracking will be handled by _videoPlayerListener
      }
    }
  }

  @override
  void dispose() {
    print("[FullScreenVideoItem: ${widget.videoPost.id}] dispose called.");
    
    // NEW: Track final analytics before disposing
    _trackVideoPause(); // Track any remaining watch time
    
    WidgetsBinding.instance.removeObserver(this);
    widget.onDispose(); 
    _videoPlayerController?.removeListener(_videoPlayerListener);
    _videoPlayerController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized || _videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    setState(() {
      _videoPlayerController!.value.isPlaying ? _videoPlayerController!.pause() : _videoPlayerController!.play();
      _showControlsOverlay = true; 
    });
    Future.delayed(const Duration(seconds: 1), () { 
      if (mounted && _showControlsOverlay) setState(() => _showControlsOverlay = false);
    });
  }

  void _showComments() {
    // Pause video when showing comments
    if (_isInitialized && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      _videoPlayerController!.pause();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(
        videoId: widget.videoPost.id,
        initialCommentsCount: _localCommentsCount,
        onCommentsCountChanged: (newCount) {
          if (mounted) {
            setState(() {
              _localCommentsCount = newCount;
            });
          }
        },
      ),
    ).then((_) {
      // Resume video when comments are closed (if still active)
      if (widget.isActive && _isInitialized && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        _videoPlayerController!.play();
      }
    });
  }

  // Check if current user should see follow button
  bool _shouldShowFollowButton() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return false;
    }
    
    // Don't show follow button for own videos
    return authService.currentUser!.id != widget.videoPost.user.id;
  }

  @override
  Widget build(BuildContext context) {
    // Debug info in build
    print('[FullScreenVideoItem: ${widget.videoPost.id}] === BUILD ===');
    print('[FullScreenVideoItem: ${widget.videoPost.id}] Username: "${widget.videoPost.user.username}"');
    print('[FullScreenVideoItem: ${widget.videoPost.id}] Views: ${widget.videoPost.formattedViewsCount}');
    print('[FullScreenVideoItem: ${widget.videoPost.id}] Likes: ${widget.videoPost.likesCount}');
    print('[FullScreenVideoItem: ${widget.videoPost.id}] Engagement: ${widget.videoPost.formattedEngagementRate}');
    print('[FullScreenVideoItem: ${widget.videoPost.id}] IsActive: ${widget.isActive}');
    print('[FullScreenVideoItem: ${widget.videoPost.id}] =============');
    
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: widget.onLikeButtonPressed,
      child: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Player
            if (_isInitialized && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover, 
                  child: SizedBox(
                    width: _videoPlayerController!.value.size.width, 
                    height: _videoPlayerController!.value.size.height, 
                    child: VideoPlayer(_videoPlayerController!)
                  )
                )
              )
            else if (_hasError || widget.videoPost.videoUrl.isEmpty || !Uri.tryParse(widget.videoPost.videoUrl)!.isAbsolute)
               Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [ 
                    const Icon(Icons.error_outline, color: Colors.red, size: 48), 
                    const SizedBox(height: 8), 
                    Text(
                      widget.videoPost.videoUrl.isEmpty || !Uri.tryParse(widget.videoPost.videoUrl)!.isAbsolute ? "Video URL không hợp lệ." : "Không thể phát video.", 
                      style: const TextStyle(color: Colors.white, backgroundColor: Colors.black54)
                    )
                  ]
                )
              )
            else 
              const Center(child: CircularProgressIndicator(color: Colors.white)),
              
            // Buffering indicator
            if (_isBuffering && !_isPlaying) 
              const Center(child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)),
              
            // Play/Pause overlay
            if (_isInitialized && _showControlsOverlay) 
              Center(
                child: Icon(
                  _isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline, 
                  color: Colors.white.withOpacity(0.7), 
                  size: 70
                )
              ),
            
            // Top navigation
            Positioned(
              top: MediaQuery.of(context).padding.top + 10, 
              left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Following", 
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7), 
                      fontSize: 16, 
                      fontWeight: FontWeight.w500
                    )
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 12, 
                    width: 1, 
                    color: Colors.white.withOpacity(0.7)
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "For You", 
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 17, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ],
              )
            ),
            
            // NEW: Analytics overlay (top right) - showing view count
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      widget.videoPost.formattedViewsCount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom content
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 16.0, 
                  right: 10.0, 
                  bottom: kBottomNavigationBarHeight + bottomPadding + 10.0, 
                  top: 10
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.0), 
                      Colors.black.withOpacity(0.3), 
                      Colors.black.withOpacity(0.7)
                    ], 
                    begin: Alignment.topCenter, 
                    end: Alignment.bottomCenter
                  )
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left side - User info and description
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min, 
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User info row with follow button
                          Row(
                            children: [
                              // User avatar
                              CircleAvatar(
                                radius: 16, 
                                backgroundColor: Colors.grey[300], 
                                backgroundImage: widget.videoPost.user.avatarUrl != null && widget.videoPost.user.avatarUrl!.isNotEmpty 
                                  ? NetworkImage(widget.videoPost.user.avatarUrl!) 
                                  : null,
                                child: (widget.videoPost.user.avatarUrl == null || widget.videoPost.user.avatarUrl!.isEmpty) 
                                  ? const Icon(Icons.person, size: 20, color: Colors.black87) 
                                  : null,
                              ),
                              const SizedBox(width: 8),
                              // Username with enhanced debug info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '@${widget.videoPost.user.username}', 
                                            style: const TextStyle(
                                              color: Colors.white, 
                                              fontSize: 16, 
                                              fontWeight: FontWeight.bold, 
                                              shadows: <Shadow>[
                                                Shadow(
                                                  offset: Offset(0.0, 1.0), 
                                                  blurRadius: 2.0, 
                                                  color: Colors.black54
                                                )
                                              ]
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Follow button
                                        if (_shouldShowFollowButton()) ...[
                                          const SizedBox(width: 8),
                                          FollowButtonWidget(
                                            targetUserId: widget.videoPost.user.id,
                                            targetUsername: widget.videoPost.user.username,
                                            initialIsFollowing: false,
                                            initialFollowerCount: 0,
                                            style: FollowButtonStyle.compact,
                                            onFollowChanged: () {
                                              print('[FullScreenVideoItem] Follow state changed for ${widget.videoPost.user.username}');
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          ),
                          const SizedBox(height: 8),
                          
                          // Description
                          Text(
                            widget.videoPost.description, 
                            maxLines: 2, 
                            overflow: TextOverflow.ellipsis, 
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 14, 
                              shadows: <Shadow>[
                                Shadow(
                                  offset: Offset(0.0, 1.0), 
                                  blurRadius: 2.0, 
                                  color: Colors.black54
                                )
                              ]
                            )
                          ),
                          
                          // Hashtags
                          if (widget.videoPost.hashtags.isNotEmpty) 
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0), 
                              child: Text(
                                widget.videoPost.hashtags.map((h) => '#$h').join(' '), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis, 
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 13, 
                                  fontWeight: FontWeight.w500
                                )
                              )
                            ),
                          const SizedBox(height: 8),
                          
                          // Audio info with analytics
                          Row(
                            children: [
                              const Icon(Icons.music_note, color: Colors.white, size: 16), 
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.videoPost.audioName ?? "Original Sound", 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis, 
                                  style: const TextStyle(
                                    color: Colors.white, 
                                    fontSize: 13, 
                                    shadows: <Shadow>[
                                      Shadow(
                                        offset: Offset(0.0, 1.0), 
                                        blurRadius: 2.0, 
                                        color: Colors.black54
                                      )
                                    ]
                                  )
                                )
                              ),
                              // NEW: Show trending indicator
                              if (widget.videoPost.isTrending)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'TRENDING',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ]
                          ),
                        ],
                      ),
                    ),
                    
                    // Right side - Interaction buttons
                    SizedBox(
                      width: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 25), 
                          
                          // Like button
                          _buildInteractionButton(
                            icon: widget.videoPost.isLikedByCurrentUser ? Icons.favorite_rounded : Icons.favorite_border_outlined, 
                            label: widget.videoPost.formattedLikesCount, 
                            onPressed: widget.onLikeButtonPressed, 
                            iconColor: widget.videoPost.isLikedByCurrentUser ? Colors.redAccent[400] : Colors.white
                          ),
                          const SizedBox(height: 20),
                          
                          // Comment button
                          _buildInteractionButton(
                            icon: Icons.chat_bubble_outline_rounded, 
                            label: _localCommentsCount.toString(), 
                            onPressed: _showComments
                          ),
                          const SizedBox(height: 20),
                          
                          // Save button
                          _buildInteractionButton(
                            icon: widget.videoPost.isSavedByCurrentUser ? Icons.bookmark_rounded : Icons.bookmark_border_outlined, 
                            label: "Save", 
                            onPressed: widget.onSaveButtonPressed, 
                            iconColor: widget.videoPost.isSavedByCurrentUser ? Colors.amberAccent[400] : Colors.white
                          ),
                          const SizedBox(height: 20),
                          
                          // Share button
                          _buildInteractionButton(
                            icon: Icons.reply_rounded, 
                            label: widget.videoPost.formattedSharesCount, 
                            onPressed: () { 
                              print("Share button tapped for video: ${widget.videoPost.id}"); 
                            }
                          ),
                          const SizedBox(height: 20), 
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon, 
    String? label, 
    required VoidCallback onPressed, 
    Color? iconColor
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            color: iconColor ?? Colors.white, 
            size: 30
          ),
          const SizedBox(height: 4),
          Text(
            label ?? "0",
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 12, 
              fontWeight: FontWeight.w600, 
              shadows: <Shadow>[
                Shadow(
                  offset: Offset(0.0, 1.0), 
                  blurRadius: 2.0, 
                  color: Colors.black45
                )
              ]
            ),
          ),
        ],
      ),
    );
  }
}