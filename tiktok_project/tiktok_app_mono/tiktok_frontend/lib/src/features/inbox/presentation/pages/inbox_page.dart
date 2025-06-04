  // tiktok_frontend/lib/src/features/inbox/presentation/pages/inbox_page.dart
  import 'package:flutter/material.dart';

  class InboxPage extends StatelessWidget {
    const InboxPage({super.key});

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Inbox'),
          actions: [
            IconButton(
              icon: const Icon(Icons.send_outlined), // Ví dụ icon tạo tin nhắn mới
              onPressed: () {},
            ),
          ],
        ),
        body: const Center(
          child: Text(
            'Inbox Page Content',
            style: TextStyle(fontSize: 24),
          ),
        ),
      );
    }
  }