import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/notifications/domain/models/notification_model.dart';
import 'package:tiktok_frontend/src/features/notifications/domain/services/notification_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../widgets/notification_item_widget.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  final ScrollController _scrollController = ScrollController();
  
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  
  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasNextPage = false;
  bool _isLoadingMore = false;
  int _unreadCount = 0;

  // Track operations
  final Set<String> _markingAsRead = {};
  final Set<String> _deleting = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadUnreadCount();
    
    // Listen for scroll to load more notifications
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasNextPage && !_isLoadingMore) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _loadNotifications() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final response = await _notificationService.getUserNotifications(
        authService.currentUser!.id, 
        page: 1, 
        limit: 20
      );
      
      if (mounted) {
        setState(() {
          _notifications = response.notifications;
          _currentPage = response.pagination.currentPage;
          _totalPages = response.pagination.totalPages;
          _hasNextPage = response.pagination.hasNextPage;
          _unreadCount = response.unreadCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadMoreNotifications() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    if (_isLoadingMore || !_hasNextPage) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _notificationService.getUserNotifications(
        authService.currentUser!.id, 
        page: _currentPage + 1, 
        limit: 20
      );
      
      if (mounted) {
        setState(() {
          _notifications.addAll(response.notifications);
          _currentPage = response.pagination.currentPage;
          _hasNextPage = response.pagination.hasNextPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải thêm thông báo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    try {
      final count = await _notificationService.getUnreadCount(authService.currentUser!.id);
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      // No debug print here
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    if (notification.isRead || _markingAsRead.contains(notification.id)) {
      return;
    }

    setState(() {
      _markingAsRead.add(notification.id);
    });

    try {
      final newUnreadCount = await _notificationService.markNotificationAsRead(
        notification.id,
        authService.currentUser!.id,
      );

      if (mounted) {
        setState(() {
          // Update notification in list
          final index = _notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            _notifications[index] = _notifications[index].copyWith(isRead: true);
          }
          _unreadCount = newUnreadCount;
          _markingAsRead.remove(notification.id);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _markingAsRead.remove(notification.id);
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    try {
      await _notificationService.markAllNotificationsAsRead(authService.currentUser!.id);

      if (mounted) {
        setState(() {
          // Mark all notifications as read
          _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
          _unreadCount = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    if (_deleting.contains(notification.id)) {
      return;
    }

    setState(() {
      _deleting.add(notification.id);
    });

    try {
      final newUnreadCount = await _notificationService.deleteNotification(
        notification.id,
        authService.currentUser!.id,
      );

      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == notification.id);
          _unreadCount = newUnreadCount;
          _deleting.remove(notification.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thông báo đã được xóa'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting.remove(notification.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa thông báo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _currentPage = 1;
      _notifications.clear();
    });
    
    await Future.wait([
      _loadNotifications(),
      _loadUnreadCount(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Thông báo', style: TextStyle(fontSize: 20.sp)),
            if (_unreadCount > 0) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  _unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all),
              tooltip: 'Đánh dấu tất cả đã đọc',
            ),
          IconButton(
            onPressed: _refreshNotifications,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_hasError && _notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: Colors.grey.shade400),
            SizedBox(height: 16.h),
            Text(
              'Lỗi khi tải thông báo',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (_errorMessage != null) 
              Padding(
                padding: EdgeInsets.all(8.w),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12.sp),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 48.sp, color: Colors.grey.shade400),
            SizedBox(height: 16.h),
            Text(
              'Chưa có thông báo nào',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 8.h),
            Text(
              'Các thông báo mới sẽ xuất hiện ở đây',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14.sp),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.all(16.w),
      itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        if (index == _notifications.length) {
          // Loading more indicator
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final notification = _notifications[index];
        final isMarkingAsRead = _markingAsRead.contains(notification.id);
        final isDeleting = _deleting.contains(notification.id);
        
        return AnimatedOpacity(
          opacity: isDeleting ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Stack(
            children: [
              NotificationItemWidget(
                notification: notification,
                onTap: () => _markAsRead(notification),
                onDelete: isDeleting ? null : () => _deleteNotification(notification),
              ),
              if (isMarkingAsRead || isDeleting)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: CircularProgressIndicator(strokeWidth: 2.sp),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            isMarkingAsRead ? 'Đang đánh dấu...' : 'Đang xóa...',
                            style: TextStyle(
                              fontSize: 12.sp,
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
        );
      },
    );
  }
}