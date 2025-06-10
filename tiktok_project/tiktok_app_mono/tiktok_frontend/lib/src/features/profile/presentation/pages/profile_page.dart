// tiktok_frontend/lib/src/features/profile/presentation/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:tiktok_frontend/src/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/notifications/presentation/pages/notifications_page.dart';
import 'package:tiktok_frontend/src/features/notifications/domain/services/notification_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final NotificationService _notificationService = NotificationService();
  int _unreadNotificationCount = 0;
  bool _isLoadingNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    setState(() {
      _isLoadingNotifications = true;
    });

    try {
      final count = await _notificationService.getUnreadCount(authService.currentUser!.id);
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
          _isLoadingNotifications = false;
        });
      }
    } catch (e) {
      print('[ProfilePage] Error loading unread count: $e');
      if (mounted) {
        setState(() {
          _isLoadingNotifications = false;
        });
      }
    }
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsPage()),
    ).then((_) {
      // Reload unread count when returning from notifications page
      _loadUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng context.watch để widget này rebuild khi authService thay đổi
    final authService = context.watch<AuthService>(); 
    final UserFrontend? currentUser = authService.currentUser;

    print('[ProfilePage] Building. User: ${currentUser?.username}, isAdmin: ${authService.isAdmin}');

    return Scaffold(
      appBar: AppBar(
        title: Text(currentUser?.username ?? 'Profile'),
        actions: [
          // Notification icon with badge
          Stack(
            children: [
              IconButton(
                onPressed: _navigateToNotifications,
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Thông báo',
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotificationCount > 99 ? '99+' : _unreadNotificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (_isLoadingNotifications)
                Positioned(
                  right: 8,
                  top: 8,
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () { /* TODO: Navigate to settings */ },
          ),
          IconButton( 
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              print('[ProfilePage] Logout button pressed.');
              await context.read<AuthService>().logout();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: [
            // Profile header
            Center(
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        width: 3,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 47,
                      child: Icon(Icons.person, size: 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Username
                  Text(
                    currentUser?.username ?? 'User Name Placeholder', 
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Email
                  Text(
                    currentUser?.email ?? '@username_or_email_placeholder',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Additional info
                  if (currentUser?.dateOfBirth != null) 
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cake, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            currentUser!.dateOfBirth!, 
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (currentUser?.gender != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            currentUser!.gender == 'male' ? Icons.male : 
                            currentUser.gender == 'female' ? Icons.female : Icons.person,
                            size: 16, 
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            currentUser.gender!.toUpperCase(), 
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (currentUser?.interests.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: currentUser!.interests.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              interest,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // Menu options
            Expanded(
              child: ListView(
                children: [
                  // Notifications
                  _buildMenuTile(
                    context,
                    icon: Icons.notifications_outlined,
                    title: 'Thông báo',
                    subtitle: _unreadNotificationCount > 0 
                        ? '$_unreadNotificationCount thông báo chưa đọc'
                        : 'Quản lý thông báo của bạn',
                    onTap: _navigateToNotifications,
                    trailing: _unreadNotificationCount > 0 
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _unreadNotificationCount > 99 ? '99+' : _unreadNotificationCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                  
                  // Edit Profile
                  _buildMenuTile(
                    context,
                    icon: Icons.edit_outlined,
                    title: 'Chỉnh sửa hồ sơ',
                    subtitle: 'Cập nhật thông tin cá nhân',
                    onTap: () { /* TODO: Navigate to edit profile screen */ },
                  ),
                  
                  // Liked Videos
                  _buildMenuTile(
                    context,
                    icon: Icons.favorite_border_outlined,
                    title: 'Video đã thích',
                    subtitle: 'Xem các video bạn đã thích',
                    onTap: () { /* TODO: Navigate to liked videos */ },
                  ),
                  
                  // Saved Videos
                  _buildMenuTile(
                    context,
                    icon: Icons.bookmark_border_outlined,
                    title: 'Video đã lưu',
                    subtitle: 'Xem các video bạn đã lưu',
                    onTap: () { /* TODO: Navigate to saved videos */ },
                  ),
                  
                  // Admin Dashboard (only for admins)
                  if (authService.isAdmin) ...[
                    const Divider(),
                    _buildMenuTile(
                      context,
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Bảng điều khiển Admin',
                      subtitle: 'Quản lý hệ thống',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
                        );
                      },
                      iconColor: Colors.blueGrey[700],
                      textColor: Colors.blueGrey[700],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (iconColor ?? Theme.of(context).primaryColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: iconColor ?? Theme.of(context).primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        subtitle: subtitle != null ? Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ) : null,
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}