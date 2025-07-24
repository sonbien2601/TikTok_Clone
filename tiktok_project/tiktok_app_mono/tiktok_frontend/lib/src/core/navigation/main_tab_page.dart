// tiktok_frontend/lib/src/core/navigation/main_tab_page.dart - UPDATED WITH TIKTOK THEME
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/feed/presentation/views/video_feed_view.dart';
import 'package:tiktok_frontend/src/features/search/presentation/pages/search_page.dart';
import 'package:tiktok_frontend/src/features/inbox/presentation/pages/inbox_page.dart';
import 'package:tiktok_frontend/src/features/profile/presentation/pages/profile_page.dart';
import 'package:tiktok_frontend/src/features/upload/presentation/pages/upload_video_page.dart';
import 'package:tiktok_frontend/src/core/config/network_debug_helper.dart';
import 'package:tiktok_frontend/src/core/config/network_config.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _bottomNavIndex = 0;

  // 4 TRANG CHính + NÚT CREATE Ở GIỮA
  static final List<Widget> _pages = <Widget>[
    const VideoFeedView(), // 0 - Home
    const SearchPage(), // 1 - Search (Discover)
    const InboxPage(), // 2 - Inbox
    const ProfilePage(), // 3 - Profile
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (!authService.isAuthenticated || authService.currentUser == null) {
        return;
      }

      // NEW: Initialize notification popup service with context
      _initializeNotificationPopup();
    });
  }

  // NEW: Initialize notification popup service
  void _initializeNotificationPopup() {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (authService.isAuthenticated && authService.currentUser != null) {
      authService.initializeNotificationPopup(context);
      
      // Enable notification popups by default
      authService.setNotificationPopupsEnabled(true);
      
    }
  }

  void _onItemTapped(int index) {
    // Khi chuyển tab, dừng tất cả video đang phát
    VideoFeedView.pauseAllVideos();

    // CHỈ CHUYỂN TAB - KHÔNG CÓ LOGIC ĐỘC LẠ!
    if (_bottomNavIndex != index && index < _pages.length) {
      setState(() {
        _bottomNavIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ĐẢNG BẢO INDEX AN TOÀN
    final safeIndex = (_bottomNavIndex >= 0 && _bottomNavIndex < _pages.length)
        ? _bottomNavIndex
        : 0;

    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.black, // TikTok background màu đen
      appBar: kDebugMode
          ? AppBar(
              title: Text(
                'TikTok Clone - ${_getPageName(safeIndex)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              centerTitle: true, // Căn giữa title
              backgroundColor: Colors.black,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
      body: IndexedStack(
        index: safeIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(
              color: Color(0xFF2A2A2A), // Subtle border
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Container(
            height: 65, // TikTok bottom nav height
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Home',
                  isSelected: safeIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),
                _buildNavItem(
                  icon: Icons.search_outlined,
                  selectedIcon: Icons.search,
                  label: 'Discover',
                  isSelected: safeIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),
                _buildUploadButton(),
                _buildNavItem(
                  icon: Icons.chat_bubble_outline,
                  selectedIcon: Icons.chat_bubble,
                  label: 'Inbox',
                  isSelected: safeIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),
                _buildProfileNavItem(
                  user: user,
                  isSelected: safeIndex == 3,
                  onTap: () => _onItemTapped(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 50,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? Colors.white : const Color(0xFF8A8A8E),
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8A8A8E),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UploadVideoPage()),
        );
      },
      child: Container(
        width: 50,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF0050), // TikTok pink
                    Color(0xFF00F2EA), // TikTok cyan
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Create',
              style: TextStyle(
                color: Color(0xFF8A8A8E),
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileNavItem({
    required dynamic user,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 50,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: user != null && user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? FutureBuilder<String>(
                      future: NetworkConfig.getFileBaseUrl(),
                      builder: (context, snapshot) {
                        final fileBaseUrl = snapshot.data ?? '';
                        return ClipOval(
                          child: Image.network(
                            fileBaseUrl + user.avatarUrl!,
                            width: 22,
                            height: 22,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF8A8A8E),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF8A8A8E),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            Text(
              'Profile',
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8A8A8E),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Test notification popup for debugging
  void _testNotificationPopup() {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (authService.isAuthenticated && authService.currentUser != null) {
      authService.notificationPopupService.checkNotificationsOnLogin(
        authService.currentUser!.id
      ).then((_) {
      }).catchError((e) {
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test notification failed: $e'),
            backgroundColor: const Color(0xFFFF0050), // TikTok pink for error
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      });
    }
  }

  String _getPageName(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Discover';
      case 2:
        return 'Inbox';
      case 3:
        return 'Profile';
      default:
        return 'Unknown';
    }
  }
}