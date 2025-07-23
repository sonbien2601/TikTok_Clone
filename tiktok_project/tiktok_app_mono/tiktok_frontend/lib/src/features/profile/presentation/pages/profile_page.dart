// tiktok_frontend/lib/src/features/profile/presentation/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/notifications/presentation/pages/notifications_page.dart';
import 'package:tiktok_frontend/src/features/notifications/domain/services/notification_service.dart';
import 'package:tiktok_frontend/src/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:tiktok_frontend/src/features/profile/presentation/pages/liked_videos_page.dart';
import 'package:tiktok_frontend/src/features/profile/presentation/pages/saved_videos_page.dart';
import 'package:tiktok_frontend/src/features/profile/presentation/pages/followers_page.dart';
import 'package:tiktok_frontend/src/features/profile/presentation/pages/following_page.dart';
import 'package:tiktok_frontend/src/features/follow/domain/services/follow_state_manager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:intl/intl.dart';
import 'package:tiktok_frontend/src/features/donate/presentation/pages/donate_page.dart';
import 'package:tiktok_frontend/src/features/donate/presentation/pages/donate_history_page.dart';
import 'package:tiktok_frontend/src/features/feed/presentation/views/video_feed_view.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final NotificationService _notificationService = NotificationService();
  int _unreadNotificationCount = 0;
  bool _isLoadingNotifications = false;

  late FollowStateManager _followStateManager;

  @override
  void initState() {
    super.initState();

    _followStateManager = FollowStateManager();
    _followStateManager.addListener(_onFollowStateChanged);

    _loadUnreadCount();
  }

  @override
  void dispose() {
    _followStateManager.removeListener(_onFollowStateChanged);
    super.dispose();
  }

  void _onFollowStateChanged() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    final currentUserId = authService.currentUser!.id;
    final followInfo = _followStateManager.getFollowInfo(currentUserId);

    if (followInfo['hasData'] == true) {
      final newFollowerCount = followInfo['followerCount'] as int;
      final currentFollowerCount = authService.currentUser!.followersCount;

      if (newFollowerCount != currentFollowerCount) {
        print(
            '[ProfilePage] Detected follower count change: $currentFollowerCount -> $newFollowerCount');

        authService.refreshUserData().then((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
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
      final count = await _notificationService
          .getUnreadCount(authService.currentUser!.id);
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

  Future<void> _refreshFollowCounts() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    try {
      print('[ProfilePage] Refreshing follow counts...');
      await authService.refreshUserData();

      if (mounted) {
        setState(() {});
        print('[ProfilePage] Follow counts refreshed successfully');
      }
    } catch (e) {
      print('[ProfilePage] Error refreshing follow counts: $e');
    }
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsPage()),
    ).then((_) {
      _loadUnreadCount();
    });
  }

  void _navigateToEditProfile() async {
    final avatarUrl = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
    if (avatarUrl != null && avatarUrl is String && avatarUrl.isNotEmpty) {
      // Tìm ancestor VideoFeedViewState và gọi cập nhật avatar
      final feedState = context.findAncestorStateOfType<TikTokVideoFeedViewState>();
      if (feedState != null) {
        await feedState.updateCurrentUserAvatarInVideos(avatarUrl);
      }
    }
    if (mounted) {
      setState(() {});
      _loadUnreadCount();
      _refreshFollowCounts();
    }
  }

  void _navigateToLikedVideos() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LikedVideosPage()),
    );
  }

  void _navigateToSavedVideos() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SavedVideosPage()),
    );
  }

  void _navigateToFollowers() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowersPage(
          userId: authService.currentUser!.id,
          username: authService.currentUser!.username,
        ),
      ),
    ).then((_) {
      _refreshFollowCounts();
    });
  }

  void _navigateToFollowing() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowingPage(
          userId: authService.currentUser!.id,
          username: authService.currentUser!.username,
        ),
      ),
    ).then((_) {
      _refreshFollowCounts();
    });
  }

  void _navigateToMyVideos() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Text(
                'Chức năng "Video của tôi" sẽ được thêm trong phiên bản tiếp theo'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _navigateToSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.settings, color: Colors.white),
            SizedBox(width: 8),
            Text('Trang cài đặt sẽ được phát triển trong tương lai'),
          ],
        ),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content:
              const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      print('[ProfilePage] Logout confirmed by user.');
      try {
        await context.read<AuthService>().logout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã đăng xuất thành công'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('[ProfilePage] Error during logout: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi đăng xuất: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    print(
        '[ProfilePage] Building. User: ${user?.username}, isAdmin: ${authService.isAdmin}');
    print(
        '[ProfilePage] Current follow counts - Followers: ${user?.followersCount}, Following: ${user?.followingCount}');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.person_outline),
            const SizedBox(width: 8),
            Text(user?.username ?? 'Profile'),
            if (user != null &&
                _followStateManager.hasRecentUpdate(user.id)) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        actions: [
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
                      _unreadNotificationCount > 99
                          ? '99+'
                          : _unreadNotificationCount.toString(),
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
            onPressed: _navigateToSettings,
            tooltip: 'Cài đặt',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUnreadCount();
          await _refreshFollowCounts();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.3),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                              ? ClipOval(
                                  child: FutureBuilder<String>(
                                    future: NetworkConfig.getFileBaseUrl(),
                                    builder: (context, snapshot) {
                                      final fileBaseUrl = snapshot.data ?? '';
                                      return Image.network(
                                        fileBaseUrl + user.avatarUrl!,
                                        width: 94,
                                        height: 94,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(Icons.person, size: 50, color: Colors.grey),
                                      );
                                    },
                                  ),
                                )
                              : Icon(Icons.person, size: 50, color: Colors.grey),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: IconButton(
                              onPressed: _navigateToEditProfile,
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 16,
                              ),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              tooltip: 'Chỉnh sửa hồ sơ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.username ?? 'Tên người dùng',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        user?.email ?? 'email@example.com',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[700],
                                ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFollowStatsRow(user),
                    if (user?.dateOfBirth != null ||
                        user?.gender != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (user?.dateOfBirth != null) ...[
                            Icon(Icons.cake, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              user!.dateOfBirth!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                          if (user?.dateOfBirth != null &&
                              user?.gender != null) ...[
                            const SizedBox(width: 16),
                            Container(
                              width: 1,
                              height: 12,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (user?.gender != null) ...[
                            Icon(
                              user!.gender == 'male'
                                  ? Icons.male
                                  : user.gender == 'female'
                                      ? Icons.female
                                      : Icons.person,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.gender!.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (user?.interests.isNotEmpty ?? false) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: user!.interests.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                                  Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.favorite,
                                  size: 14,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  interest,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  _buildSectionHeader('Cá nhân'),
                  const SizedBox(height: 8),
                  _buildMenuTile(
                    context,
                    icon: Icons.edit_outlined,
                    title: 'Chỉnh sửa hồ sơ',
                    subtitle: 'Cập nhật thông tin cá nhân',
                    onTap: _navigateToEditProfile,
                    iconColor: Colors.blue.shade600,
                  ),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _unreadNotificationCount > 99
                                  ? '99+'
                                  : _unreadNotificationCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    iconColor: Colors.orange.shade600,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Mạng xã hội'),
                  const SizedBox(height: 8),
                  _buildMenuTile(
                    context,
                    icon: Icons.people_outlined,
                    title: 'Người theo dõi',
                    subtitle: 'Xem ai đang theo dõi bạn',
                    onTap: _navigateToFollowers,
                    iconColor: Colors.blue.shade600,
                  ),
                  _buildMenuTile(
                    context,
                    icon: Icons.person_search_outlined,
                    title: 'Đang theo dõi',
                    subtitle: 'Xem ai bạn đang theo dõi',
                    onTap: _navigateToFollowing,
                    iconColor: Colors.green.shade600,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Nội dung video'),
                  const SizedBox(height: 8),
                  _buildMenuTile(
                    context,
                    icon: Icons.favorite_border_outlined,
                    title: 'Video đã thích',
                    subtitle: 'Xem các video bạn đã thích',
                    onTap: _navigateToLikedVideos,
                    iconColor: Colors.red.shade600,
                  ),
                  _buildMenuTile(
                    context,
                    icon: Icons.bookmark_border_outlined,
                    title: 'Video đã lưu',
                    subtitle: 'Xem các video bạn đã lưu',
                    onTap: _navigateToSavedVideos,
                    iconColor: Colors.amber.shade600,
                  ),
                  _buildMenuTile(
                    context,
                    icon: Icons.video_library_outlined,
                    title: 'Video của tôi',
                    subtitle: 'Quản lý video đã đăng',
                    onTap: _navigateToMyVideos,
                    iconColor: Colors.blue.shade600,
                  ),
                  if (authService.isAdmin) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('Quản trị'),
                    const SizedBox(height: 8),
                    _buildMenuTile(
                      context,
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Bảng điều khiển Admin',
                      subtitle: 'Quản lý hệ thống',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AdminDashboardPage()),
                        );
                      },
                      iconColor: Colors.blueGrey[700],
                      textColor: Colors.blueGrey[700],
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Đăng xuất'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Donate Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final authService =
                            Provider.of<AuthService>(context, listen: false);
                        if (authService.currentUser != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DonatePage(
                                toUserId: authService.currentUser!.id,
                                toUsername: authService.currentUser!.username,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.volunteer_activism),
                      label: const Text('Donate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Donate History Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DonateHistoryPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('Lịch sử Donate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.pinkAccent,
                        side: const BorderSide(color: Colors.pinkAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFollowStatsRow(UserFrontend? currentUser) {
    final followersCount = currentUser?.followersCount ?? 0;
    final followingCount = currentUser?.followingCount ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          InkWell(
            onTap: _navigateToFollowers,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _formatCount(followersCount),
                      key: ValueKey(followersCount),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Người theo dõi',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (currentUser != null &&
                      _followStateManager.hasRecentUpdate(currentUser.id))
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.shade300,
          ),
          InkWell(
            onTap: _navigateToFollowing,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Text(
                    _formatCount(followingCount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đang theo dõi',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
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
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (iconColor ?? Theme.of(context).primaryColor).withOpacity(0.1),
                (iconColor ?? Theme.of(context).primaryColor).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (iconColor ?? Theme.of(context).primaryColor)
                  .withOpacity(0.2),
            ),
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
            fontSize: 16,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              )
            : null,
        trailing: trailing ??
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
  }
}
