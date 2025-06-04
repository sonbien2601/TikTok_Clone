// tiktok_frontend/lib/src/features/admin/presentation/pages/admin_dashboard_page.dart
import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blueGrey[700], // Màu khác biệt cho admin
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildDashboardCard(
            context,
            icon: Icons.people_alt_outlined,
            title: 'Quản lý Người dùng',
            subtitle: 'Xem, chỉnh sửa, cấm người dùng',
            onTap: () {
              // TODO: Điều hướng đến trang quản lý người dùng chi tiết
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chức năng quản lý người dùng sắp ra mắt!')),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildDashboardCard(
            context,
            icon: Icons.videocam_outlined,
            title: 'Quản lý Video',
            subtitle: 'Xem, kiểm duyệt, xóa video',
            onTap: () {
              // TODO: Điều hướng đến trang quản lý video chi tiết
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chức năng quản lý video sắp ra mắt!')),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildDashboardCard(
            context,
            icon: Icons.report_problem_outlined,
            title: 'Nội dung Báo cáo',
            subtitle: 'Xem xét các báo cáo từ người dùng',
            onTap: () {
              // TODO: Điều hướng đến trang nội dung báo cáo
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chức năng xem báo cáo sắp ra mắt!')),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildDashboardCard(
            context,
            icon: Icons.settings_outlined,
            title: 'Cài đặt Ứng dụng',
            subtitle: 'Quản lý các cài đặt chung',
            onTap: () {
              // TODO: Điều hướng đến trang cài đặt ứng dụng
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chức năng cài đặt ứng dụng sắp ra mắt!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      ),
    );
  }
}