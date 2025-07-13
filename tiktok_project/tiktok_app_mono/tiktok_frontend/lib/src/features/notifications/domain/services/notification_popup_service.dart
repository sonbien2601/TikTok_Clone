import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';
import '../../../auth/domain/services/auth_service.dart';
import '../../../video_detail/presentation/pages/video_detail_page.dart';

class NotificationPopupService {
  static final NotificationPopupService _instance = NotificationPopupService._internal();
  factory NotificationPopupService() => _instance;
  NotificationPopupService._internal();

  // Service dependencies
  final NotificationService _notificationService = NotificationService();
  
  // Popup state
  bool _isEnabled = true;
  BuildContext? _context;
  Timer? _autoCheckTimer;
  Set<String> _shownNotificationIds = <String>{};
  
  // Configuration
  static const Duration _autoCheckInterval = Duration(minutes: 2);
  static const Duration _popupDisplayDuration = Duration(seconds: 6); // Increased for better UX
  static const int _maxPopupsPerSession = 3;
  int _popupsShownThisSession = 0;

  // Navigation context
  GlobalKey<NavigatorState>? _navigatorKey;

  // Initialize service with context
  void initialize(BuildContext context) {
    _context = context;
    print('[NotificationPopupService] Initialized with context');
  }

  // Set navigator key for navigation
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    print('[NotificationPopupService] Navigator key set');
  }

  // Enable/disable popup notifications
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _stopAutoCheck();
    }
    print('[NotificationPopupService] Popup notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  // Check for new notifications on login
  Future<void> checkNotificationsOnLogin(String userId) async {
    if (!_isEnabled || _context == null) return;

    print('[NotificationPopupService] Checking notifications on login for user: $userId');
    
    try {
      // Get recent notifications (last 5)
      final response = await _notificationService.getUserNotifications(
        userId, 
        page: 1, 
        limit: 5
      );

      if (response.unreadCount > 0) {
        // Show unread count notification first
        await _showUnreadCountPopup(response.unreadCount, userId);
        
        // Then show individual important notifications
        final importantNotifications = response.notifications
            .where((n) => !n.isRead && _isImportantNotification(n))
            .take(2) // Limit to 2 individual notifications
            .toList();

        for (final notification in importantNotifications) {
          if (_popupsShownThisSession >= _maxPopupsPerSession) break;
          if (_shownNotificationIds.contains(notification.id)) continue;
          
          await _showIndividualNotificationPopup(notification, userId);
          _shownNotificationIds.add(notification.id);
          
          // Delay between popups
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      // Start auto-checking for new notifications
      _startAutoCheck(userId);
      
    } catch (e) {
      print('[NotificationPopupService] Error checking notifications on login: $e');
    }
  }

  // Start automatic checking for new notifications
  void _startAutoCheck(String userId) {
    _stopAutoCheck(); // Stop any existing timer
    
    _autoCheckTimer = Timer.periodic(_autoCheckInterval, (timer) {
      _checkForNewNotifications(userId);
    });
    
    print('[NotificationPopupService] Started auto-checking every ${_autoCheckInterval.inMinutes} minutes');
  }

  // Stop automatic checking
  void _stopAutoCheck() {
    _autoCheckTimer?.cancel();
    _autoCheckTimer = null;
    print('[NotificationPopupService] Stopped auto-checking');
  }

  // Check for new notifications periodically
  Future<void> _checkForNewNotifications(String userId) async {
    if (!_isEnabled || _context == null) return;
    if (_popupsShownThisSession >= _maxPopupsPerSession) return;

    try {
      final response = await _notificationService.getUserNotifications(
        userId, 
        page: 1, 
        limit: 3
      );

      final newNotifications = response.notifications
          .where((n) => !n.isRead && 
                      !_shownNotificationIds.contains(n.id) &&
                      _isImportantNotification(n))
          .take(1) // Only show 1 new notification at a time
          .toList();

      for (final notification in newNotifications) {
        await _showIndividualNotificationPopup(notification, userId);
        _shownNotificationIds.add(notification.id);
        break; // Only show one popup per check
      }
    } catch (e) {
      print('[NotificationPopupService] Error checking for new notifications: $e');
    }
  }

  // Show unread count popup with enhanced design
  Future<void> _showUnreadCountPopup(int unreadCount, String userId) async {
    if (_context == null) return;

    final overlay = Overlay.of(_context!);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _EnhancedUnreadCountPopup(
        unreadCount: unreadCount,
        onTap: () {
          overlayEntry.remove();
          _navigateToNotifications();
        },
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
    _popupsShownThisSession++;

    // Auto dismiss after duration
    Timer(_popupDisplayDuration, () {
      try {
        overlayEntry.remove();
      } catch (e) {
        // Overlay might already be removed
      }
    });
  }

  // Show individual notification popup with enhanced design
  Future<void> _showIndividualNotificationPopup(NotificationModel notification, String userId) async {
    if (_context == null) return;

    final overlay = Overlay.of(_context!);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _EnhancedNotificationPopup(
        notification: notification,
        onTap: () {
          overlayEntry.remove();
          _handleNotificationTap(notification, userId);
        },
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
    _popupsShownThisSession++;

    // Auto dismiss after duration
    Timer(_popupDisplayDuration, () {
      try {
        overlayEntry.remove();
      } catch (e) {
        // Overlay might already be removed
      }
    });
  }

  // Check if notification is important enough to show as popup
  bool _isImportantNotification(NotificationModel notification) {
    switch (notification.type) {
      case 'follow':
      case 'video_like':
      case 'comment':
        return true;
      case 'comment_like':
      case 'reply':
        return false; // Less important
      default:
        return false;
    }
  }

  // Enhanced notification tap handler with proper navigation
  Future<void> _handleNotificationTap(NotificationModel notification, String userId) async {
    print('[NotificationPopupService] Notification tapped: ${notification.id}, type: ${notification.type}');
    
    // Mark as read first
    await _markNotificationAsRead(notification, userId);
    
    // Navigate based on notification type and content
    try {
      switch (notification.type) {
        case 'video_like':
        case 'comment':
          if (notification.hasRelatedVideo) {
            await _navigateToVideo(
              notification.relatedVideoId!, 
              highlightCommentId: notification.type == 'comment' ? notification.relatedCommentId : null
            );
          } else {
            _navigateToNotifications();
          }
          break;
          
        case 'follow':
          await _navigateToUserProfile(notification.senderId, notification.senderUsername);
          break;
          
        case 'comment_like':
        case 'reply':
          if (notification.hasRelatedVideo) {
            await _navigateToVideo(
              notification.relatedVideoId!,
              highlightCommentId: notification.relatedCommentId
            );
          } else {
            _navigateToNotifications();
          }
          break;
          
        default:
          _navigateToNotifications();
          break;
      }
    } catch (e) {
      print('[NotificationPopupService] Error navigating from notification: $e');
      _navigateToNotifications(); // Fallback
    }
  }

  // Mark notification as read
  Future<void> _markNotificationAsRead(NotificationModel notification, String userId) async {
    try {
      await _notificationService.markNotificationAsRead(notification.id, userId);
      print('[NotificationPopupService] Marked notification as read: ${notification.id}');
    } catch (e) {
      print('[NotificationPopupService] Error marking notification as read: $e');
    }
  }

  // Navigate to notifications page
  void _navigateToNotifications() {
    if (_context == null) return;
    
    try {
      // For now, show a simple dialog until NotificationDetailPage is properly created
      showDialog(
        context: _context!,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.blue),
              SizedBox(width: 12),
              Text('Thông báo'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Trang chi tiết thông báo sẽ được hiển thị ở đây.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Hiện tại bạn có thể xem thông báo trong phần Inbox.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      print('[NotificationPopupService] Showed notifications dialog');
    } catch (e) {
      print('[NotificationPopupService] Error showing notifications: $e');
    }
  }

  // Navigate to specific video with optional comment highlight
  Future<void> _navigateToVideo(String videoId, {String? highlightCommentId}) async {
    if (_context == null) return;
    
    try {
      await Navigator.of(_context!).push(
        MaterialPageRoute(
          builder: (context) => VideoDetailPage(
            videoId: videoId,
            highlightCommentId: highlightCommentId,
          ),
        ),
      );
      print('[NotificationPopupService] Navigated to video: $videoId');
    } catch (e) {
      print('[NotificationPopupService] Error navigating to video: $e');
    }
  }

  // Navigate to user profile
  Future<void> _navigateToUserProfile(String userId, String username) async {
    if (_context == null) return;
    
    try {
      // For now, navigate to the main profile page and show user info in a dialog
      // Since ProfilePage constructor doesn't support userId/username parameters
      await _showUserProfileDialog(userId, username);
      print('[NotificationPopupService] Showed user profile dialog: $username');
    } catch (e) {
      print('[NotificationPopupService] Error showing user profile: $e');
    }
  }

  // Show user profile in a dialog
  Future<void> _showUserProfileDialog(String userId, String username) async {
    if (_context == null) return;
    
    showDialog(
      context: _context!,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                username[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'User ID: ${userId.substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bạn có thể xem thông tin chi tiết người dùng này trong phần Profile.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToNotifications();
                    },
                    icon: const Icon(Icons.notifications),
                    label: const Text('Xem thông báo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // Reset session counters (call on logout)
  void reset() {
    _stopAutoCheck();
    _shownNotificationIds.clear();
    _popupsShownThisSession = 0;
    print('[NotificationPopupService] Reset session data');
  }

  // Dispose service
  void dispose() {
    _stopAutoCheck();
    _context = null;
    _navigatorKey = null;
    _shownNotificationIds.clear();
    _popupsShownThisSession = 0;
    print('[NotificationPopupService] Disposed');
  }
}

// Enhanced unread count popup widget with improved design
class _EnhancedUnreadCountPopup extends StatefulWidget {
  final int unreadCount;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _EnhancedUnreadCountPopup({
    required this.unreadCount,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_EnhancedUnreadCountPopup> createState() => _EnhancedUnreadCountPopupState();
}

class _EnhancedUnreadCountPopupState extends State<_EnhancedUnreadCountPopup>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.bounceOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _slideController.forward();
    _scaleController.forward();
    
    // Start shimmer effect
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _shimmerController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 90,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Shimmer effect
                    AnimatedBuilder(
                      animation: _shimmerAnimation,
                      builder: (context, child) {
                        return Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.grey.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                                begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
                                end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Content
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF667eea),
                                Color(0xFF764ba2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              const Icon(
                                Icons.notifications_active,
                                color: Colors.white,
                                size: 24,
                              ),
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '${widget.unreadCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🎉 Bạn có thông báo mới!',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${widget.unreadCount} thông báo chưa đọc',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Xem chi tiết',
                                      style: TextStyle(
                                        color: Color(0xFF667eea),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: widget.onDismiss,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Enhanced individual notification popup widget
class _EnhancedNotificationPopup extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _EnhancedNotificationPopup({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_EnhancedNotificationPopup> createState() => _EnhancedNotificationPopupState();
}

class _EnhancedNotificationPopupState extends State<_EnhancedNotificationPopup>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.bounceOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _slideController.forward();
    _scaleController.forward();
    
    // Start shimmer effect
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _shimmerController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Color _getNotificationColor() {
    switch (widget.notification.type) {
      case 'follow':
        return const Color(0xFF6C63FF);
      case 'video_like':
        return const Color(0xFFFF6B6B);
      case 'comment':
        return const Color(0xFF4ECDC4);
      case 'comment_like':
        return const Color(0xFFFFD93D);
      case 'reply':
        return const Color(0xFF95E1D3);
      default:
        return const Color(0xFF95A5A6);
    }
  }

  IconData _getNotificationIcon() {
    switch (widget.notification.type) {
      case 'follow':
        return Icons.person_add_rounded;
      case 'video_like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'comment_like':
        return Icons.thumb_up_rounded;
      case 'reply':
        return Icons.reply_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _getActionText() {
    switch (widget.notification.type) {
      case 'follow':
        return 'Xem profile';
      case 'video_like':
        return 'Xem video';
      case 'comment':
        return 'Xem bình luận';
      case 'comment_like':
        return 'Xem bình luận';
      case 'reply':
        return 'Xem phản hồi';
      default:
        return 'Xem chi tiết';
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationColor = _getNotificationColor();
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 90,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: notificationColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: notificationColor.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Shimmer effect
                    AnimatedBuilder(
                      animation: _shimmerAnimation,
                      builder: (context, child) {
                        return Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  notificationColor.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                                begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
                                end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Content
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                notificationColor,
                                notificationColor.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: notificationColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getNotificationIcon(),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.notification.formattedMessage,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.notification.relativeTime,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: notificationColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getActionText(),
                                      style: TextStyle(
                                        color: notificationColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: widget.onDismiss,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}