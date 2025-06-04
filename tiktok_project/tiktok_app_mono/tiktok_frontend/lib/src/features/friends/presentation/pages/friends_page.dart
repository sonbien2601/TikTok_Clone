// tiktok_frontend/lib/src/features/friends/presentation/pages/friends_page.dart
import 'package:flutter/material.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      body: const Center(
        child: Text(
          'Friends Page Content',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}