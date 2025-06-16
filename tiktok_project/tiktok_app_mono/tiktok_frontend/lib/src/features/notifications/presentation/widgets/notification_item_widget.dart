// tiktok_frontend/lib/src/features/notifications/presentation/widgets/notification_item_widget.dart
import 'package:flutter/material.dart';
import 'package:tiktok_frontend/src/features/notifications/domain/models/notification_model.dart';
import 'package:tiktok_frontend/src/features/video_detail/presentation/pages/video_detail_page.dart';

class NotificationItemWidget extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const NotificationItemWidget({
    super.key,
    required this.notification,
    this.onTap,
    this.onDelete,
  });

  void _handleNotificationTap(BuildContext context) {
    print('[NotificationItemWidget] Notification tapped!');
    print('[NotificationItemWidget] Related Video ID: ${notification.relatedVideoId}');
    print('[NotificationItemWidget] Related Comment ID: ${notification.relatedCommentId}');
    
    // Call the original onTap if provided (for marking as read)
    if (onTap != null) {
      print('[NotificationItemWidget] Calling onTap callback for marking as read');
      onTap!();
    }
    
    // Navigate to video if relatedVideoId exists
    if (notification.relatedVideoId != null && notification.relatedVideoId!.isNotEmpty) {
      print('[NotificationItemWidget] Navigating to video: ${notification.relatedVideoId}');
      print('[NotificationItemWidget] With highlight comment: ${notification.relatedCommentId}');
      
      try {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoDetailPage(
              videoId: notification.relatedVideoId!,
              highlightCommentId: notification.relatedCommentId,
            ),
          ),
        );
        print('[NotificationItemWidget] Navigation initiated successfully');
      } catch (e) {
        print('[NotificationItemWidget] Navigation error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi điều hướng: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      print('[NotificationItemWidget] No relatedVideoId found');
      // Show message if no video is associated
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có video liên quan đến thông báo này'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        print('[NotificationItemWidget] InkWell tapped, calling _handleNotificationTap');
        _handleNotificationTap(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead ? Colors.grey.shade200 : Colors.blue.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getIconBackgroundColor(),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getNotificationIcon(),
                color: Colors.white,
                size: 20,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Notification content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message
                  Text(
                    notification.formattedMessage,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Time and type
                  Row(
                    children: [
                      Text(
                        notification.relativeTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTypeBackgroundColor(),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getTypeDisplayName(),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getTypeTextColor(),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Related content indicator with navigation hint
                  if (notification.hasRelatedVideo || notification.hasRelatedComment) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            notification.hasRelatedVideo ? Icons.play_circle_outline : Icons.chat_bubble_outline,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            notification.hasRelatedVideo ? 'Video' : 'Comment',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (notification.hasRelatedVideo) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 10,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  
                  // Navigation hint for video notifications
                  if (notification.hasRelatedVideo) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 12,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Nhấn để xem video',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Debug info (remove in production)
                  if (notification.relatedVideoId != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Video ID: ${notification.relatedVideoId}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Actions
            Column(
              children: [
                // Unread indicator
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // Delete button
                if (onDelete != null)
                  InkWell(
                    onTap: () => _showDeleteConfirmation(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon() {
    switch (notification.type) {
      case 'comment':
        return Icons.chat_bubble;
      case 'reply':
        return Icons.reply;
      case 'comment_like':
      case 'video_like':
        return Icons.favorite;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconBackgroundColor() {
    switch (notification.type) {
      case 'comment':
        return Colors.blue.shade600;
      case 'reply':
        return Colors.green.shade600;
      case 'comment_like':
      case 'video_like':
        return Colors.red.shade600;
      case 'follow':
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getTypeBackgroundColor() {
    switch (notification.type) {
      case 'comment':
        return Colors.blue.shade100;
      case 'reply':
        return Colors.green.shade100;
      case 'comment_like':
      case 'video_like':
        return Colors.red.shade100;
      case 'follow':
        return Colors.purple.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getTypeTextColor() {
    switch (notification.type) {
      case 'comment':
        return Colors.blue.shade700;
      case 'reply':
        return Colors.green.shade700;
      case 'comment_like':
      case 'video_like':
        return Colors.red.shade700;
      case 'follow':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _getTypeDisplayName() {
    switch (notification.type) {
      case 'comment':
        return 'Bình luận';
      case 'reply':
        return 'Trả lời';
      case 'comment_like':
        return 'Thích comment';
      case 'video_like':
        return 'Thích video';
      case 'follow':
        return 'Theo dõi';
      default:
        return 'Thông báo';
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xóa thông báo'),
          content: const Text(
            'Bạn có chắc chắn muốn xóa thông báo này?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (onDelete != null) {
                  onDelete!();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text(
                'Xóa',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}