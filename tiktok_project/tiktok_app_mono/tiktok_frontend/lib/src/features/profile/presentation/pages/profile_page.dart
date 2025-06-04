// tiktok_frontend/lib/src/features/profile/presentation/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:tiktok_frontend/src/features/admin/presentation/pages/admin_dashboard_page.dart'; // Đảm bảo bạn đã tạo trang này
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart'; 

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sử dụng context.watch để widget này rebuild khi authService thay đổi (ví dụ sau logout)
    // hoặc khi currentUser thay đổi.
    final authService = context.watch<AuthService>(); 
    final UserFrontend? currentUser = authService.currentUser; // Lấy user hiện tại một cách an toàn

    print('[ProfilePage] Building. User: ${currentUser?.username}, isAdmin: ${authService.isAdmin}');

    return Scaffold(
      appBar: AppBar(
        title: Text(currentUser?.username ?? 'Profile'), // Hiển thị username nếu có, ngược lại là 'Profile'
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () { /* TODO: Navigate to settings */ },
          ),
          IconButton( 
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              // Sử dụng context.read trong callback để không gây rebuild không cần thiết khi gọi hàm
              print('[ProfilePage] Logout button pressed.');
              await context.read<AuthService>().logout();
              // App.dart sẽ tự động điều hướng về LoginPage
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: [
            const Center(
              child: CircleAvatar(
                radius: 50,
                // TODO: Hiển thị ảnh đại diện người dùng thực tế từ currentUser.avatarUrl (nếu có)
                child: Icon(Icons.person, size: 50),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                currentUser?.username ?? 'User Name Placeholder', 
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                currentUser?.email ?? '@username_or_email_placeholder',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
            // Hiển thị thêm thông tin nếu có từ currentUser
            if (currentUser?.dateOfBirth != null) 
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(child: Text("DOB: ${currentUser!.dateOfBirth!}", style: Theme.of(context).textTheme.bodySmall)),
              ),
            if (currentUser?.gender != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Center(child: Text("Gender: ${currentUser!.gender!}", style: Theme.of(context).textTheme.bodySmall)),
              ),
             if (currentUser?.interests.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Center(child: Text("Interests: ${currentUser!.interests.join(', ')}", style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center,)),
              ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Profile'),
              onTap: () { /* TODO: Navigate to edit profile screen */ },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border_outlined),
              title: const Text('Liked Videos'),
              onTap: () { /* TODO: Navigate to liked videos */ },
            ),
            if (authService.isAdmin) ...[ 
              const Divider(),
              ListTile(
                leading: Icon(Icons.admin_panel_settings_outlined, color: Colors.blueGrey[700]),
                title: Text('Admin Dashboard', style: TextStyle(color: Colors.blueGrey[700], fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminDashboardPage()), // Đảm bảo AdminDashboardPage đã được tạo
                  );
                },
              ),
            ],
            const Spacer(), 
          ],
        ),
      ),
    );
  }
}
