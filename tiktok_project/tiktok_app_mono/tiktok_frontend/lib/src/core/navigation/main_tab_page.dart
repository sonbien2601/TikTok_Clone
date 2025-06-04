// tiktok_frontend/lib/src/core/navigation/main_tab_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/feed/presentation/views/video_feed_view.dart';
import 'package:tiktok_frontend/src/features/friends/presentation/pages/friends_page.dart';
import 'package:tiktok_frontend/src/features/inbox/presentation/pages/inbox_page.dart';
import 'package:tiktok_frontend/src/features/profile/presentation/pages/profile_page.dart';
import 'package:tiktok_frontend/src/features/upload/presentation/pages/upload_video_page.dart'; 

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _bottomNavIndex = 0; 

  static final List<Widget> _pages = <Widget>[
    const VideoFeedView(),    
    const FriendsPage(),      
    // Nút Upload sẽ không có trang tương ứng trong _pages này
    // mà sẽ điều hướng riêng. Chúng ta vẫn cần 4 trang cho 4 tab chính.
    const InboxPage(),        
    const ProfilePage(),      
  ];

  @override
  void initState() {
    super.initState();
    print('[MainTabPage] initState. Initial _bottomNavIndex: $_bottomNavIndex');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; 
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated || authService.currentUser == null) {
        print("[MainTabPage] initState - PostFrameCallback: User not authenticated or currentUser is null. AuthService will trigger navigation.");
        // App.dart sẽ xử lý việc này dựa trên trạng thái của AuthService
        // authService.logout(); // Có thể không cần gọi logout ở đây nữa nếu App.dart xử lý tốt
      } else {
        print('[MainTabPage] initState - PostFrameCallback: User is authenticated. User: ${authService.currentUser?.username}');
      }
    });
  }

  void _onItemTapped(int index) {
    print('[MainTabPage] _onItemTapped: index $index');
    if (index == 2) { // Index 2 là nút Upload (dấu +)
      print("[MainTabPage] Upload button (index 2) tapped - Navigating to UploadVideoPage");
      Navigator.push( // Sử dụng Navigator.push để mở UploadVideoPage
        context,
        MaterialPageRoute(builder: (context) => const UploadVideoPage()),
      );
      // Không thay đổi _bottomNavIndex vì nó không phải là một tab có trang riêng trong _pages
      // Trạng thái highlight của BottomNav sẽ không thay đổi khi mở trang Upload theo cách này.
      // Nếu muốn nút Upload được "chọn" khi ở trang Upload, bạn cần logic phức tạp hơn.
      return; 
    }
    // Chỉ gọi setState nếu index thực sự thay đổi và là một trong các tab chính
    if (_bottomNavIndex != index && index < 5 && index !=2 ) { 
      setState(() {
        _bottomNavIndex = index;
        print('[MainTabPage] setState: _bottomNavIndex changed to $index');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[MainTabPage] build method called. Current _bottomNavIndex for BottomNav: $_bottomNavIndex');

    int stackIndex;
    if (_bottomNavIndex < 2) { 
      stackIndex = _bottomNavIndex;
    } else if (_bottomNavIndex > 2) { 
      stackIndex = _bottomNavIndex - 1; 
    } else {
      // Nếu _bottomNavIndex là 2 (dù _onItemTapped đã return), 
      // chúng ta cần một stackIndex hợp lệ.
      // Giữ nguyên trang đang hiển thị trước đó bằng cách không thay đổi _bottomNavIndex
      // Hoặc mặc định về trang Home (index 0 của _pages)
      // Để đơn giản, nếu _bottomNavIndex là 2, ta sẽ hiển thị trang Home.
      // Tuy nhiên, vì _onItemTapped đã return, _bottomNavIndex sẽ không được setState thành 2.
      // Nếu _bottomNavIndex vẫn bằng 2 ở đây (ví dụ, giá trị khởi tạo là 2), thì mặc định về Home.
      print('[MainTabPage] _bottomNavIndex is 2 (Upload or unexpected state). Defaulting stackIndex to 0 (Home).');
      stackIndex = 0; 
    }
    
    if (stackIndex < 0 || stackIndex >= _pages.length) {
        print('[MainTabPage] CRITICAL WARNING: Calculated stackIndex $stackIndex is out of bounds for _pages (length: ${_pages.length}). Defaulting to 0.');
        stackIndex = 0; 
    }
    print('[MainTabPage] Displaying page at stackIndex: $stackIndex (corresponds to BottomNavIndex: $_bottomNavIndex)');

    return Scaffold(
      body: IndexedStack( 
        index: stackIndex, 
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: stackIndex == 0 ? Colors.black.withOpacity(0.9) : Theme.of(context).bottomAppBarTheme.color,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: stackIndex == 0 ? Colors.white : Theme.of(context).primaryColor,
        unselectedItemColor: stackIndex == 0 ? Colors.grey[600] : Colors.grey[700],
        selectedFontSize: 10.0,
        unselectedFontSize: 10.0,
        iconSize: 24,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),       
          const BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: 'Friends'),  
          BottomNavigationBarItem(                                                              
            icon: Container(
              width: 45, height: 30,
              decoration: BoxDecoration(
                color: Colors.transparent, 
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_bottomNavIndex == 2 || stackIndex == 0) ? Colors.white.withOpacity(0.8) : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54), 
                  width: 1.5), 
              ),
              child: Icon(Icons.add, 
                color: (_bottomNavIndex == 2 || stackIndex == 0) ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), 
                size: 22),
            ),
            label: '', 
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.message_outlined), label: 'Inbox'),  
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),  
        ],
        currentIndex: _bottomNavIndex, 
        onTap: _onItemTapped,
      ),
    );
  }
}