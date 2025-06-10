// tiktok_backend/lib/src/features/notifications/controllers/notification_controller.dart
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify, SelectorBuilder;
import 'package:shelf/shelf.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';

class NotificationController {
  
  // Get notifications for a user
  static Future<Response> getUserNotificationsHandler(Request request, String userId, int page, int limit) async {
    print('[NotificationController] Getting notifications for userId: $userId (page: $page, limit: $limit)');
    
    try {
      // Validate userId
      ObjectId userObjectId;
      try { 
        userObjectId = ObjectId.fromHexString(userId); 
      } catch (e) { 
        return Response(400, 
          body: jsonEncode({'error': 'Invalid userId format'}),
          headers: {'Content-Type': 'application/json'}
        ); 
      }

      // Validate pagination parameters
      if (page < 1) page = 1;
      if (limit < 1 || limit > 100) limit = 20;
      
      final skip = (page - 1) * limit;

      final notificationsCollection = DatabaseService.db.collection('notifications');
      
      // Get total count
      final totalNotifications = await notificationsCollection.count(
        where.eq('receiverId', userObjectId)
      );

      // Get notifications with pagination
      final notificationsCursor = notificationsCollection.find(
        SelectorBuilder()
          .eq('receiverId', userObjectId)
          .sortBy('createdAt', descending: true)
          .skip(skip)
          .limit(limit)
      );
      
      final List<Map<String, dynamic>> notificationsList = [];
      await for (var doc in notificationsCursor) {
        final formattedNotification = <String, dynamic>{
          '_id': (doc['_id'] as ObjectId).toHexString(),
          'receiverId': (doc['receiverId'] as ObjectId).toHexString(),
          'senderId': (doc['senderId'] as ObjectId).toHexString(),
          'senderUsername': doc['senderUsername'] as String? ?? 'Unknown User',
          'type': doc['type'] as String? ?? 'unknown',
          'message': doc['message'] as String? ?? '',
          'isRead': doc['isRead'] as bool? ?? false,
          'createdAt': doc['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        };
        
        // Add optional related fields
        if (doc['relatedVideoId'] != null) {
          formattedNotification['relatedVideoId'] = (doc['relatedVideoId'] as ObjectId).toHexString();
        }
        
        if (doc['relatedCommentId'] != null) {
          formattedNotification['relatedCommentId'] = (doc['relatedCommentId'] as ObjectId).toHexString();
        }
        
        if (doc['relatedParentCommentId'] != null) {
          formattedNotification['relatedParentCommentId'] = (doc['relatedParentCommentId'] as ObjectId).toHexString();
        }
        
        notificationsList.add(formattedNotification);
      }

      final totalPages = totalNotifications > 0 ? (totalNotifications / limit).ceil() : 1;
      final hasNextPage = page < totalPages;
      final hasPrevPage = page > 1;

      final responseData = {
        'notifications': notificationsList,
        'pagination': {
          'currentPage': page,
          'totalPages': totalPages,
          'totalNotifications': totalNotifications,
          'limit': limit,
          'hasNextPage': hasNextPage,
          'hasPrevPage': hasPrevPage,
        },
        'unreadCount': await _getUnreadCount(userObjectId),
      };

      return Response.ok(
        jsonEncode(responseData), 
        headers: {'Content-Type': 'application/json'}
      );
      
    } catch (e, s) {
      print('[NotificationController.getUserNotificationsHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch notifications: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Mark notification as read
  static Future<Response> markNotificationAsReadHandler(Request request, String notificationId, String userId) async {
    print('[NotificationController] Marking notification as read: $notificationId by user: $userId');
    
    try {
      // Convert IDs
      ObjectId notificationObjectId; 
      ObjectId userObjectId;
      try {
        notificationObjectId = ObjectId.fromHexString(notificationId);
        userObjectId = ObjectId.fromHexString(userId);
      } catch (e) {
        return Response(400, 
          body: jsonEncode({'error': 'Invalid notificationId or userId format'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final notificationsCollection = DatabaseService.db.collection('notifications');
      
      // Find and verify notification belongs to user
      final notificationDoc = await notificationsCollection.findOne(where.id(notificationObjectId));
      if (notificationDoc == null) {
        return Response(404, 
          body: jsonEncode({'error': 'Notification not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final receiverId = notificationDoc['receiverId'] as ObjectId;
      if (receiverId != userObjectId) {
        return Response(403, 
          body: jsonEncode({'error': 'You can only mark your own notifications as read'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Update notification
      final updateResult = await notificationsCollection.updateOne(
        where.id(notificationObjectId),
        modify.set('isRead', true)
      );
      
      if (updateResult.isSuccess) {
        final unreadCount = await _getUnreadCount(userObjectId);
        
        return Response.ok(
          jsonEncode({
            'message': 'Notification marked as read',
            'notificationId': notificationId,
            'unreadCount': unreadCount
          }), 
          headers: {'Content-Type': 'application/json'}
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to mark notification as read'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
    } catch (e, s) {
      print('[NotificationController.markNotificationAsReadHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Mark all notifications as read
  static Future<Response> markAllNotificationsAsReadHandler(Request request, String userId) async {
    print('[NotificationController] Marking all notifications as read for user: $userId');
    
    try {
      // Convert ID
      ObjectId userObjectId;
      try {
        userObjectId = ObjectId.fromHexString(userId);
      } catch (e) {
        return Response(400, 
          body: jsonEncode({'error': 'Invalid userId format'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final notificationsCollection = DatabaseService.db.collection('notifications');
      
      // Update all unread notifications for this user
      final updateResult = await notificationsCollection.updateMany(
        where.eq('receiverId', userObjectId).eq('isRead', false),
        modify.set('isRead', true)
      );
      
      print('[NotificationController] Marked ${updateResult.nModified} notifications as read');
      
      return Response.ok(
        jsonEncode({
          'message': 'All notifications marked as read',
          'markedCount': updateResult.nModified,
          'unreadCount': 0
        }), 
        headers: {'Content-Type': 'application/json'}
      );
    } catch (e, s) {
      print('[NotificationController.markAllNotificationsAsReadHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Get unread count for a user
  static Future<Response> getUnreadCountHandler(Request request, String userId) async {
    print('[NotificationController] Getting unread count for user: $userId');
    
    try {
      // Convert ID
      ObjectId userObjectId;
      try {
        userObjectId = ObjectId.fromHexString(userId);
      } catch (e) {
        return Response(400, 
          body: jsonEncode({'error': 'Invalid userId format'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final unreadCount = await _getUnreadCount(userObjectId);
      
      return Response.ok(
        jsonEncode({
          'unreadCount': unreadCount,
          'userId': userId
        }),
        headers: {'Content-Type': 'application/json'}
      );
    } catch (e, s) {
      print('[NotificationController.getUnreadCountHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Delete notification
  static Future<Response> deleteNotificationHandler(Request request, String notificationId, String userId) async {
    print('[NotificationController] Deleting notification: $notificationId by user: $userId');
    
    try {
      // Convert IDs
      ObjectId notificationObjectId; 
      ObjectId userObjectId;
      try {
        notificationObjectId = ObjectId.fromHexString(notificationId);
        userObjectId = ObjectId.fromHexString(userId);
      } catch (e) {
        return Response(400, 
          body: jsonEncode({'error': 'Invalid notificationId or userId format'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final notificationsCollection = DatabaseService.db.collection('notifications');
      
      // Find and verify notification belongs to user
      final notificationDoc = await notificationsCollection.findOne(where.id(notificationObjectId));
      if (notificationDoc == null) {
        return Response(404, 
          body: jsonEncode({'error': 'Notification not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final receiverId = notificationDoc['receiverId'] as ObjectId;
      if (receiverId != userObjectId) {
        return Response(403, 
          body: jsonEncode({'error': 'You can only delete your own notifications'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Delete notification
      final deleteResult = await notificationsCollection.deleteOne(where.id(notificationObjectId));
      
      if (deleteResult.isSuccess) {
        final unreadCount = await _getUnreadCount(userObjectId);
        
        return Response.ok(
          jsonEncode({
            'message': 'Notification deleted successfully',
            'deletedNotificationId': notificationId,
            'unreadCount': unreadCount
          }), 
          headers: {'Content-Type': 'application/json'}
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to delete notification'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
    } catch (e, s) {
      print('[NotificationController.deleteNotificationHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Helper method to get unread count
  static Future<int> _getUnreadCount(ObjectId userId) async {
    try {
      final notificationsCollection = DatabaseService.db.collection('notifications');
      return await notificationsCollection.count(
        where.eq('receiverId', userId).eq('isRead', false)
      );
    } catch (e) {
      print('[NotificationController] Error getting unread count: $e');
      return 0;
    }
  }
}