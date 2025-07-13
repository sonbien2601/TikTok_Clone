// tiktok_frontend/lib/src/features/inbox/presentation/pages/inbox_page.dart - ENHANCED WITH NOTIFICATION TEST
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/domain/services/auth_service.dart';
import '../../../notifications/presentation/widgets/notification_popup_settings.dart';
import '../../../notifications/domain/models/notification_model.dart';

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
        title: const Text('Inbox'),
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Vui lòng đăng nhập để xem inbox',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome message
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            authService.currentUser!.username[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xin chào, ${authService.currentUser!.username}!',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Quản lý thông báo và tin nhắn của bạn',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Enhanced Notification Test Demo
                _buildNotificationTestDemo(),

                const SizedBox(height: 16),

                // Notification Popup Settings
                const NotificationPopupSettings(),

                const SizedBox(height: 16),

                // Inbox sections
                _buildInboxSection(
                  'Hoạt động',
                  Icons.notifications,
                  'Thông báo về like, comment, follow',
                  () => _navigateToNotifications(),
                ),

                const SizedBox(height: 12),

                _buildInboxSection(
                  'Tin nhắn',
                  Icons.message,
                  'Chat với bạn bè và người theo dõi',
                  () => _navigateToMessages(),
                ),

                const SizedBox(height: 12),

                _buildInboxSection(
                  'Yêu cầu kết bạn',
                  Icons.people,
                  'Quản lý yêu cầu follow',
                  () => _navigateToFollowRequests(),
                ),

                const SizedBox(height: 12),

                _buildInboxSection(
                  'Video được chia sẻ',
                  Icons.share,
                  'Video được gửi cho bạn',
                  () => _navigateToSharedVideos(),
                ),

                const SizedBox(height: 24),

                // Statistics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thống kê tài khoản',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.science,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '🔔 Test Notification Popup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Test các loại thông báo popup đẹp với animation:',
              style: TextStyle(fontSize: 16),
            ),
            
            const SizedBox(height: 20),
            
            // Test buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
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
            
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hướng dẫn test',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Nhấn các nút trên để xem popup demo\n'
                    '• Popup sẽ tự động ẩn sau 6 giây\n'
                    '• Nhấn vào popup để test navigation\n'
                    '• Nhấn X để đóng popup ngay lập tức\n'
                    '• Animation mượt mà với shimmer effect',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 14,
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
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showTestPopup(String type) {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
        const SnackBar(
          content: Text('Vui lòng đăng nhập để test notification'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
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
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications, color: Colors.white),
            SizedBox(width: 8),
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
      const SnackBar(
        content: Text('Chức năng tin nhắn đang được phát triển'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _navigateToFollowRequests() {
    print('[InboxPage] Navigating to follow requests');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chức năng yêu cầu follow đang được phát triển'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _navigateToSharedVideos() {
    print('[InboxPage] Navigating to shared videos');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              const Text(
                '🔔 Cài đặt thông báo popup',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Settings content
              const NotificationPopupSettings(),
              
              const SizedBox(height: 16),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}