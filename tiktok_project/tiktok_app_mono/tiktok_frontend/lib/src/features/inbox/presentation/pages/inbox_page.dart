// tiktok_frontend/lib/src/features/inbox/presentation/pages/inbox_page.dart - ENHANCED WITH NOTIFICATION TEST
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/domain/services/auth_service.dart';
import '../../../notifications/presentation/widgets/notification_popup_settings.dart';
import '../../../notifications/domain/models/notification_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Inbox', style: TextStyle(fontSize: 20.sp)),
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, size: 24.sp),
            onPressed: () {
              _showNotificationSettings();
            },
            tooltip: 'Notification Settings',
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          if (!authService.isAuthenticated) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login,
                    size: 64.sp,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Vui lòng đăng nhập để xem inbox',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome message
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24.r,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            authService.currentUser!.username[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xin chào, ${authService.currentUser!.username}!',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Quản lý thông báo và tin nhắn của bạn',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Enhanced Notification Test Demo
                _buildNotificationTestDemo(),

                SizedBox(height: 16.h),

                // Notification Popup Settings
                const NotificationPopupSettings(),

                SizedBox(height: 16.h),

                // Inbox sections
                _buildInboxSection(
                  'Hoạt động',
                  Icons.notifications,
                  'Thông báo về like, comment, follow',
                  () => _navigateToNotifications(),
                ),

                SizedBox(height: 12.h),

                _buildInboxSection(
                  'Tin nhắn',
                  Icons.message,
                  'Chat với bạn bè và người theo dõi',
                  () => _navigateToMessages(),
                ),

                SizedBox(height: 12.h),

                _buildInboxSection(
                  'Yêu cầu kết bạn',
                  Icons.people,
                  'Quản lý yêu cầu follow',
                  () => _navigateToFollowRequests(),
                ),

                SizedBox(height: 12.h),

                _buildInboxSection(
                  'Video được chia sẻ',
                  Icons.share,
                  'Video được gửi cho bạn',
                  () => _navigateToSharedVideos(),
                ),

                SizedBox(height: 24.h),

                // Statistics
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thống kê tài khoản',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              'Followers',
                              authService.currentUser!.followersCount.toString(),
                              Icons.people,
                            ),
                            _buildStatItem(
                              'Following',
                              authService.currentUser!.followingCount.toString(),
                              Icons.person_add,
                            ),
                            _buildStatItem(
                              'Videos',
                              '0', // You might want to add video count to user model
                              Icons.video_library,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationTestDemo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.science,
                    color: Colors.purple,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  '🔔 Test Notification Popup',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16.h),
            
            Text(
              'Test các loại thông báo popup đẹp với animation:',
              style: TextStyle(fontSize: 16.sp),
            ),
            
            SizedBox(height: 20.h),
            
            // Test buttons
            Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: [
                _buildTestButton(
                  'Follow Popup',
                  Icons.person_add,
                  const Color(0xFF6C63FF),
                  () => _showTestPopup('follow'),
                ),
                _buildTestButton(
                  'Like Popup',
                  Icons.favorite,
                  const Color(0xFFFF6B6B),
                  () => _showTestPopup('video_like'),
                ),
                _buildTestButton(
                  'Comment Popup',
                  Icons.chat_bubble,
                  const Color(0xFF4ECDC4),
                  () => _showTestPopup('comment'),
                ),
                _buildTestButton(
                  'Unread Count',
                  Icons.notifications_active,
                  Colors.orange,
                  () => _showUnreadCountPopup(),
                ),
              ],
            ),
            
            SizedBox(height: 20.h),
            
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Hướng dẫn test',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '• Nhấn các nút trên để xem popup demo\n'
                    '• Popup sẽ tự động ẩn sau 6 giây\n'
                    '• Nhấn vào popup để test navigation\n'
                    '• Nhấn X để đóng popup ngay lập tức\n'
                    '• Animation mượt mà với shimmer effect',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 14.sp,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18.sp),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  void _showTestPopup(String type) {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng đăng nhập để test notification'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Use the real notification popup service
    authService.notificationPopupService.checkNotificationsOnLogin(
      authService.currentUser!.id
    ).then((_) {
      print('[InboxPage] ✅ Test notification popup completed');
    }).catchError((e) {
      print('[InboxPage] ❌ Test notification popup failed: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test notification failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _showUnreadCountPopup() {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng đăng nhập để test notification'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20.w,
              height: 20.h,
              child: CircularProgressIndicator(
                strokeWidth: 2.sp,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12.w),
            Text('Đang test notification popup...'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );

    // Use the real notification popup service
    authService.notificationPopupService.checkNotificationsOnLogin(
      authService.currentUser!.id
    );
  }

  Widget _buildInboxSection(String title, IconData icon, String subtitle, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 24.sp,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Theme.of(context).primaryColor,
          size: 24.sp,
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _navigateToNotifications() {
    // Navigate to notifications page
    print('[InboxPage] Navigating to notifications');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications, color: Colors.white, size: 20.sp),
            SizedBox(width: 8.w),
            Text('Trang thông báo đang được phát triển'),
          ],
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _navigateToMessages() {
    print('[InboxPage] Navigating to messages');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chức năng tin nhắn đang được phát triển'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _navigateToFollowRequests() {
    print('[InboxPage] Navigating to follow requests');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chức năng yêu cầu follow đang được phát triển'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _navigateToSharedVideos() {
    print('[InboxPage] Navigating to shared videos');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chức năng video chia sẻ đang được phát triển'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: 20.h,
            left: 20.w,
            right: 20.w,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              
              SizedBox(height: 20.h),
              
              // Title
              Text(
                '🔔 Cài đặt thông báo popup',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              SizedBox(height: 20.h),
              
              // Settings content
              const NotificationPopupSettings(),
              
              SizedBox(height: 16.h),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                  ),
                  child: Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}