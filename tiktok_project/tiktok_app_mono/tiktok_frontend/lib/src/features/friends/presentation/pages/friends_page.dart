// tiktok_frontend/lib/src/features/friends/presentation/pages/friends_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friends', style: TextStyle(fontSize: 20.sp)),
      ),
      body: Center(
        child: Text(
          'Friends Page Content',
          style: TextStyle(fontSize: 24.sp),
        ),
      ),
    );
  }
}