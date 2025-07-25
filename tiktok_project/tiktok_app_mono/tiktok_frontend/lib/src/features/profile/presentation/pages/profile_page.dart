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
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  int _unreadNotificationCount = 0;
  bool _isLoadingNotifications = false;

  late FollowStateManager _followStateManager;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _profileController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _profileAnimation;

  @override
  void initState() {
    super.initState();

    _followStateManager = FollowStateManager();
    _followStateManager.addListener(_onFollowStateChanged);

    _loadUnreadCount();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _profileController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _profileAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _profileController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _slideController.forward();
    
    // Delay profile animation
    Future.delayed(const Duration(milliseconds: 300), () {
      _profileController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _profileController.dispose();
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
      await authService.refreshUserData();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle error silently
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
    _showSnackBar(
      'Chức năng "Video của tôi" sẽ được thêm trong phiên bản tiếp theo',
      icon: Icons.info_outline,
      backgroundColor: const Color(0xFF25F4EE),
    );
  }

  void _navigateToSettings() {
    _showSnackBar(
      'Trang cài đặt sẽ được phát triển trong tương lai',
      icon: Icons.settings,
      backgroundColor: Colors.grey[600]!,
    );
  }

  void _showSnackBar(String message, {required IconData icon, required Color backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
            ).createShader(bounds),
            child: const Text(
              'Đăng xuất',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Hủy',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Đăng xuất',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      try {
        await context.read<AuthService>().logout();
        if (mounted) {
          _showSnackBar(
            'Đã đăng xuất thành công',
            icon: Icons.check_circle,
            backgroundColor: Colors.green[600]!,
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar(
            'Lỗi khi đăng xuất: $e',
            icon: Icons.error,
            backgroundColor: Colors.red[600]!,
          );
        }
      }
    }
  }

  Widget _buildGlassMorphicAppBar() {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
                    ).createShader(bounds),
                    child: Text(
                      user?.username ?? 'Profile',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (user != null && _followStateManager.hasRecentUpdate(user.id)) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green, Colors.lightGreen],
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              
              // Notification Button
              _buildIconButton(
                icon: Icons.notifications_outlined,
                onPressed: _navigateToNotifications,
                badge: _unreadNotificationCount > 0 ? _unreadNotificationCount : null,
                isLoading: _isLoadingNotifications,
              ),
              
              const SizedBox(width: 8),
              
              // Settings Button
              _buildIconButton(
                icon: Icons.settings_outlined,
                onPressed: _navigateToSettings,
              ),
              
              const SizedBox(width: 8),
              
              // Logout Button
              _buildIconButton(
                icon: Icons.logout,
                onPressed: _handleLogout,
                color: Colors.red[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    int? badge,
    bool isLoading = false,
    Color? color,
  }) {
    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!.withOpacity(0.5)),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: color ?? Colors.grey[300],
              size: 20,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
        if (badge != null && badge > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF0050), Color(0xFFFF4081)],
                ),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                badge > 99 ? '99+' : badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (isLoading)
          Positioned(
            right: 2,
            top: 2,
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.grey[400]!,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileHeader(UserFrontend? user) {
    return ScaleTransition(
      scale: _profileAnimation,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2A2A2A).withOpacity(0.8),
              const Color(0xFF1A1A1A).withOpacity(0.9),
            ],
          ),
          border: Border.all(
            color: Colors.grey[700]!.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Avatar with gradient border and edit button
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF0050).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2A2A2A),
                    ),
                    child: ClipOval(
                      child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                          ? FutureBuilder<String>(
                              future: NetworkConfig.getFileBaseUrl(),
                              builder: (context, snapshot) {
                                final fileBaseUrl = snapshot.data ?? '';
                                return Image.network(
                                  fileBaseUrl + user.avatarUrl!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                                );
                              },
                            )
                          : _buildDefaultAvatar(),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2A2A2A), width: 2),
                    ),
                    child: IconButton(
                      onPressed: _navigateToEditProfile,
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 16,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'Chỉnh sửa hồ sơ',
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Username
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
              ).createShader(bounds),
              child: Text(
                user?.username ?? 'Tên người dùng',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Email container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[700]!.withOpacity(0.5)),
              ),
              child: Text(
                user?.email ?? 'email@example.com',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[300],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Follow stats
            _buildFollowStatsRow(user),
            
            // Additional info
            if (user?.dateOfBirth != null || user?.gender != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (user?.dateOfBirth != null)
                    _buildInfoChip(
                      icon: Icons.cake,
                      text: user!.dateOfBirth!,
                    ),
                  if (user?.gender != null)
                    _buildInfoChip(
                      icon: user!.gender == 'male' ? Icons.male : 
                           user.gender == 'female' ? Icons.female : Icons.person,
                      text: user.gender!.toUpperCase(),
                    ),
                ],
              ),
            ],
            
            // Interests
            if (user?.interests.isNotEmpty ?? false) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: user!.interests.map((interest) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0050).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          interest,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.grey[700]!, Colors.grey[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.person, size: 60, color: Colors.grey),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[300],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowStatsRow(UserFrontend? currentUser) {
    final followersCount = currentUser?.followersCount ?? 0;
    final followingCount = currentUser?.followingCount ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A1A).withOpacity(0.8),
            const Color(0xFF2A2A2A).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey[700]!.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
                      ).createShader(bounds),
                      child: Text(
                        _formatCount(followersCount),
                        key: ValueKey(followersCount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Người theo dõi',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (currentUser != null &&
                      _followStateManager.hasRecentUpdate(currentUser.id))
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green, Colors.lightGreen],
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.grey[600]!.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          InkWell(
            onTap: _navigateToFollowing,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF25F4EE), Color(0xFFFF0050)],
                    ).createShader(bounds),
                    child: Text(
                      _formatCount(followingCount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đang theo dõi',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[200],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
    int index = 0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF2A2A2A).withOpacity(0.8),
                border: Border.all(
                  color: Colors.grey[700]!.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (iconColor ?? const Color(0xFFFF0050)).withOpacity(0.2),
                        (iconColor ?? const Color(0xFF25F4EE)).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (iconColor ?? const Color(0xFFFF0050)).withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? const Color(0xFFFF0050),
                    size: 24,
                  ),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor ?? Colors.grey[200],
                    fontSize: 16,
                  ),
                ),
                subtitle: subtitle != null ? Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ) : null,
                trailing: trailing ?? Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[500],
                ),
                onTap: onTap,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[600]!, Colors.red[700]!],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout, color: Colors.white),
          label: const Text(
            'Đăng xuất',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Custom App Bar
            _buildGlassMorphicAppBar(),
            
            // Content
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadUnreadCount();
                    await _refreshFollowCounts();
                  },
                  backgroundColor: const Color(0xFF2A2A2A),
                  color: const Color(0xFFFF0050),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    child: Column(
                      children: [
                        // Profile Header
                        _buildProfileHeader(user),
                        
                        // Menu Sections
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Cá nhân'),
                            _buildMenuTile(
                              icon: Icons.edit_outlined,
                              title: 'Chỉnh sửa hồ sơ',
                              subtitle: 'Cập nhật thông tin cá nhân',
                              onTap: _navigateToEditProfile,
                              iconColor: const Color(0xFF25F4EE),
                              index: 0,
                            ),
                            _buildMenuTile(
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
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFF0050), Color(0xFFFF4081)],
                                        ),
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
                              iconColor: Colors.orange[400],
                              index: 1,
                            ),
                            
                            const SizedBox(height: 16),
                            _buildSectionHeader('Mạng xã hội'),
                            _buildMenuTile(
                              icon: Icons.people_outlined,
                              title: 'Người theo dõi',
                              subtitle: 'Xem ai đang theo dõi bạn',
                              onTap: _navigateToFollowers,
                              iconColor: const Color(0xFF25F4EE),
                              index: 2,
                            ),
                            _buildMenuTile(
                              icon: Icons.person_search_outlined,
                              title: 'Đang theo dõi',
                              subtitle: 'Xem ai bạn đang theo dõi',
                              onTap: _navigateToFollowing,
                              iconColor: Colors.green[400],
                              index: 3,
                            ),
                            
                            const SizedBox(height: 16),
                            _buildSectionHeader('Nội dung video'),
                            _buildMenuTile(
                              icon: Icons.favorite_border_outlined,
                              title: 'Video đã thích',
                              subtitle: 'Xem các video bạn đã thích',
                              onTap: _navigateToLikedVideos,
                              iconColor: Colors.red[400],
                              index: 4,
                            ),
                            _buildMenuTile(
                              icon: Icons.bookmark_border_outlined,
                              title: 'Video đã lưu',
                              subtitle: 'Xem các video bạn đã lưu',
                              onTap: _navigateToSavedVideos,
                              iconColor: Colors.amber[400],
                              index: 5,
                            ),
                            _buildMenuTile(
                              icon: Icons.video_library_outlined,
                              title: 'Video của tôi',
                              subtitle: 'Quản lý video đã đăng',
                              onTap: _navigateToMyVideos,
                              iconColor: const Color(0xFF25F4EE),
                              index: 6,
                            ),
                            _buildMenuTile(
                              icon: Icons.history,
                              title: 'Lịch sử Donate',
                              subtitle: 'Xem lịch sử ủng hộ của bạn',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const DonateHistoryPage(),
                                  ),
                                );
                              },
                              iconColor: Colors.purple[400],
                              index: 7,
                            ),
                            
                            if (authService.isAdmin) ...[
                              const SizedBox(height: 16),
                              _buildSectionHeader('Quản trị'),
                              _buildMenuTile(
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
                                iconColor: const Color(0xFF25F4EE),
                                textColor: const Color(0xFF25F4EE),
                                index: 8,
                              ),
                            ],
                            
                            const SizedBox(height: 24),
                            // Logout Button
                            _buildLogoutButton(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}