// tiktok_frontend/lib/src/features/video_detail/presentation/pages/video_detail_page.dart
import 'package:flutter/material.dart';

class VideoDetailPage extends StatelessWidget {
  final String videoId;
  final String? highlightCommentId;

  const VideoDetailPage({
    super.key,
    required this.videoId,
    this.highlightCommentId,
  });

  @override
  Widget build(BuildContext context) {
    print('[VideoDetailPage] Build called with videoId: $videoId, highlightCommentId: $highlightCommentId');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Detail'),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_library,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Video ID: $videoId',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (highlightCommentId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Highlight Comment: $highlightCommentId',
                style: TextStyle(fontSize: 14, color: Colors.blue.shade600),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              '🎉 Navigation thành công!\nĐây là trang video detail.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }
}