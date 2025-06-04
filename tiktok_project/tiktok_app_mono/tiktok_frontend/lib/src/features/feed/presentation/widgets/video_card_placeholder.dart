// tiktok_frontend/lib/src/features/feed/presentation/widgets/video_card_placeholder.dart
import 'package:flutter/material.dart';

class VideoCardPlaceholder extends StatelessWidget {
  final String userName;
  final String videoTitle;
  final Color placeholderColor;

  const VideoCardPlaceholder({
    super.key,
    required this.userName,
    required this.videoTitle,
    this.placeholderColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 2.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Placeholder cho video player
          Container(
            height: 200,
            color: placeholderColor.withOpacity(0.3),
            child: const Center(
              child: Icon(Icons.play_circle_outline, size: 50, color: Colors.white70),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  videoTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4.0),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: placeholderColor,
                      child: const Icon(Icons.person, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      userName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // TODO: Thêm các nút tương tác (like, comment, share)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(context, Icons.favorite_border, "Likes"),
                _buildActionButton(context, Icons.comment_outlined, "Comments"),
                _buildActionButton(context, Icons.share_outlined, "Share"),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
      ],
    );
  }
}