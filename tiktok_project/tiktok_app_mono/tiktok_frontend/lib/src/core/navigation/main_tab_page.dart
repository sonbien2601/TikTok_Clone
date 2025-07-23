// tiktok_frontend/lib/src/core/navigation/main_tab_page.dart - UPDATED WITH NOTIFICATION POPUP
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/feed/presentation/views/video_feed_view.dart';
import 'package:tiktok_frontend/src/features/friends/presentation/pages/friends_page.dart';
import 'package:tiktok_frontend/src/features/search/presentation/pages/search_page.dart';
import 'package:tiktok_frontend/src/features/inbox/presentation/pages/inbox_page.dart';
import 'package:tiktok_frontend/src/features/profile/presentation/pages/profile_page.dart';
import 'package:tiktok_frontend/src/features/upload/presentation/pages/upload_video_page.dart';
import 'package:tiktok_frontend/src/core/config/network_debug_helper.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _bottomNavIndex = 0;

  // ĐÚNG 5 TRANG CHO 5 TAB
  static final List<Widget> _pages = <Widget>[
    const VideoFeedView(), // 0 - Home
    const FriendsPage(), // 1 - Friends
    const SearchPage(), // 2 - Search ← QUAN TRỌNG!
    const InboxPage(), // 3 - Inbox
    const ProfilePage(), // 4 - Profile
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (!authService.isAuthenticated || authService.currentUser == null) {
        print("[MainTabPage] User not authenticated");
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
      print('[MainTabPage] 🔔 Initializing notification popup service');
      authService.initializeNotificationPopup(context);
      
      // Enable notification popups by default
      authService.setNotificationPopupsEnabled(true);
      
      print('[MainTabPage] ✅ Notification popup service initialized for user: ${authService.currentUser!.username}');
    }
  }

  void _onItemTapped(int index) {
    // IN RA ĐỂ DEBUG
    print('🔍 DEBUG: Tapped tab index $index');
    print('🔍 DEBUG: Current pages length: ${_pages.length}');
    print('🔍 DEBUG: Page at index $index: ${_pages[index].runtimeType}');

    // Khi chuyển tab, dừng tất cả video đang phát
    VideoFeedView.pauseAllVideos();

    // CHỈ CHUYỂN TAB - KHÔNG CÓ LOGIC ĐỘC LẠ!
    if (_bottomNavIndex != index && index < _pages.length) {
      setState(() {
        _bottomNavIndex = index;
        print('🔍 DEBUG: Changed to tab $index');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ĐẢNG BẢO INDEX AN TOÀN
    final safeIndex = (_bottomNavIndex >= 0 && _bottomNavIndex < _pages.length)
        ? _bottomNavIndex
        : 0;

    print('🔍 DEBUG: Building with safeIndex: $safeIndex');
    print('🔍 DEBUG: Showing page: ${_pages[safeIndex].runtimeType}');

    return Scaffold(
      appBar: kDebugMode
          ? AppBar(
              title: Text('TikTok Clone - ${_getPageName(safeIndex)}'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                // NEW: Notification popup toggle button for debug
                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    if (!authService.isAuthenticated) return const SizedBox.shrink();
                    
                    return PopupMenuButton<String>(
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Notification Settings',
                      onSelected: (value) {
                        switch (value) {
                          case 'toggle':
                            // Toggle notification popups
                            final currentState = authService.notificationPopupService;
                            // You might want to add a getter for enabled state
                            print('[MainTabPage] 🔔 Toggling notification popups');
                            break;
                          case 'test':
                            // Test notification popup
                            _testNotificationPopup();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(Icons.notifications_active),
                              SizedBox(width: 8),
                              Text('Toggle Popups'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'test',
                          child: Row(
                            children: [
                              Icon(Icons.bug_report),
                              SizedBox(width: 8),
                              Text('Test Popup'),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.network_check),
                  onPressed: () => NetworkDebugHelper.showDebugDialog(context),
                  tooltip: 'Network Debug',
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: safeIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[700],
        selectedFontSize: 10.0,
        unselectedFontSize: 10.0,
        iconSize: 24,

        // ĐÚNG 5 TAB
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.mail), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: safeIndex,
        onTap: _onItemTapped,
      ),

      // NÚT UPLOAD RIÊNG
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print('🔍 DEBUG: Opening Upload page');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadVideoPage()),
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // NEW: Test notification popup for debugging
  void _testNotificationPopup() {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (authService.isAuthenticated && authService.currentUser != null) {
      print('[MainTabPage] 🧪 Testing notification popup');
      
      // Trigger a test notification check
      authService.notificationPopupService.checkNotificationsOnLogin(
        authService.currentUser!.id
      ).then((_) {
        print('[MainTabPage] ✅ Test notification popup completed');
      }).catchError((e) {
        print('[MainTabPage] ❌ Test notification popup failed: $e');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test notification failed: $e'),
            backgroundColor: Colors.red,
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
        return 'Friends';
      case 2:
        return 'Search';
      case 3:
        return 'Inbox';
      case 4:
        return 'Profile';
      default:
        return 'Unknown';
    }
  }
}