// tiktok_frontend/lib/src/features/notifications/domain/models/notification_model.dart

class NotificationModel {
  final String id;
  final String receiverId;
  final String senderId;
  final String senderUsername;
  final String type;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? relatedVideoId;
  final String? relatedCommentId;
  final String? relatedParentCommentId;

  NotificationModel({
    required this.id,
    required this.receiverId,
    required this.senderId,
    required this.senderUsername,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.relatedVideoId,
    this.relatedCommentId,
    this.relatedParentCommentId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    try {
      print('[NotificationModel] Parsing JSON: ${json.toString()}');
      
      return NotificationModel(
        id: _parseString(json['_id'], 'id'),
        receiverId: _parseString(json['receiverId'], 'receiverId'),
        senderId: _parseString(json['senderId'], 'senderId'),
        senderUsername: _parseString(json['senderUsername'], 'senderUsername', defaultValue: 'Unknown User'),
        type: _parseString(json['type'], 'type', defaultValue: 'unknown'),
        message: _parseString(json['message'], 'message', defaultValue: ''),
        isRead: _parseBool(json['isRead']),
        createdAt: _parseDateTime(json['createdAt']),
        relatedVideoId: json['relatedVideoId'] as String?,
        relatedCommentId: json['relatedCommentId'] as String?,
        relatedParentCommentId: json['relatedParentCommentId'] as String?,
      );
    } catch (e, stackTrace) {
      print('[NotificationModel] Error parsing JSON: $e');
      print('[NotificationModel] Stack trace: $stackTrace');
      print('[NotificationModel] Problematic JSON: $json');
      rethrow;
    }
  }

  // Helper method để parse string an toàn
  static String _parseString(dynamic value, String fieldName, {String? defaultValue}) {
    if (value == null) {
      if (defaultValue != null) return defaultValue;
      throw Exception('Required field $fieldName is null');
    }
    
    if (value is String) {
      return value;
    }
    
    print('[NotificationModel] Warning: $fieldName is not a string, got ${value.runtimeType}. Converting to string.');
    return value.toString();
  }

  // Helper method để parse bool an toàn
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    if (value is int) {
      return value != 0;
    }
    
    print('[NotificationModel] Warning: Expected bool but got ${value.runtimeType}. Using false.');
    return false;
  }

  // Helper method để parse DateTime an toàn
  static DateTime _parseDateTime(dynamic dateData) {
    if (dateData == null) {
      print('[NotificationModel] Warning: DateTime is null, using current time');
      return DateTime.now();
    }
    
    if (dateData is String) {
      final parsed = DateTime.tryParse(dateData);
      if (parsed != null) return parsed;
      
      print('[NotificationModel] Warning: Invalid date string: $dateData, using current time');
      return DateTime.now();
    }
    
    print('[NotificationModel] Warning: DateTime is not a string, got ${dateData.runtimeType}, using current time');
    return DateTime.now();
  }

  // Helper method to get relative time
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} năm trước';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} tháng trước';
    } else if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} tuần trước';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }

  // Get notification icon based on type
  String get iconName {
    switch (type) {
      case 'comment':
        return 'chat_bubble_outline';
      case 'reply':
        return 'reply';
      case 'comment_like':
        return 'favorite';
      case 'video_like':
        return 'favorite';
      case 'follow':
        return 'person_add';
      default:
        return 'notifications';
    }
  }

  // Get notification color based on type
  String get notificationColor {
    switch (type) {
      case 'comment':
        return 'blue';
      case 'reply':
        return 'green';
      case 'comment_like':
      case 'video_like':
        return 'red';
      case 'follow':
        return 'purple';
      default:
        return 'grey';
    }
  }

  // Get formatted message
  String get formattedMessage {
    final username = senderUsername.isNotEmpty ? '@$senderUsername' : 'Ai đó';
    return '$username $message';
  }

  // Check if notification has related content
  bool get hasRelatedVideo => relatedVideoId != null;
  bool get hasRelatedComment => relatedCommentId != null;

  // Create a copy with updated fields
  NotificationModel copyWith({
    String? id,
    String? receiverId,
    String? senderId,
    String? senderUsername,
    String? type,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    String? relatedVideoId,
    String? relatedCommentId,
    String? relatedParentCommentId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      receiverId: receiverId ?? this.receiverId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      type: type ?? this.type,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      relatedVideoId: relatedVideoId ?? this.relatedVideoId,
      relatedCommentId: relatedCommentId ?? this.relatedCommentId,
      relatedParentCommentId: relatedParentCommentId ?? this.relatedParentCommentId,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, type: $type, senderUsername: $senderUsername, message: $message, isRead: $isRead, createdAt: $createdAt)';
  }
}

// Pagination response model for notifications
class NotificationPaginationResponse {
  final List<NotificationModel> notifications;
  final NotificationPagination pagination;
  final int unreadCount;

  NotificationPaginationResponse({
    required this.notifications,
    required this.pagination,
    required this.unreadCount,
  });

  factory NotificationPaginationResponse.fromJson(Map<String, dynamic> json) {
    try {
      print('[NotificationPaginationResponse] Parsing response JSON...');
      print('[NotificationPaginationResponse] JSON keys: ${json.keys.toList()}');
      
      // Safely parse notifications array
      final notificationsData = json['notifications'];
      print('[NotificationPaginationResponse] Notifications data type: ${notificationsData.runtimeType}');
      
      List<NotificationModel> notificationsList = [];
      
      if (notificationsData == null) {
        print('[NotificationPaginationResponse] Warning: notifications field is null');
      } else if (notificationsData is! List) {
        print('[NotificationPaginationResponse] Error: notifications field is not a List, it is ${notificationsData.runtimeType}');
        throw Exception('Notifications field must be an array');
      } else {
        final List rawNotifications = notificationsData;
        print('[NotificationPaginationResponse] Notifications array length: ${rawNotifications.length}');
        
        for (int i = 0; i < rawNotifications.length; i++) {
          final item = rawNotifications[i];
          print('[NotificationPaginationResponse] Processing notification $i, type: ${item.runtimeType}');
          
          if (item is! Map<String, dynamic>) {
            print('[NotificationPaginationResponse] Warning: Notification $i is not a Map, skipping');
            continue;
          }
          
          try {
            final notification = NotificationModel.fromJson(item);
            notificationsList.add(notification);
          } catch (e) {
            print('[NotificationPaginationResponse] Error parsing notification $i: $e');
            // Continue với các notification khác thay vì fail toàn bộ
          }
        }
      }

      // Safely parse pagination
      final paginationData = json['pagination'];
      print('[NotificationPaginationResponse] Pagination data type: ${paginationData.runtimeType}');
      
      NotificationPagination pagination;
      
      if (paginationData == null) {
        print('[NotificationPaginationResponse] Warning: pagination field is null, using default');
        pagination = NotificationPagination(
          currentPage: 1,
          totalPages: 1,
          totalNotifications: notificationsList.length,
          limit: 20,
          hasNextPage: false,
          hasPrevPage: false,
        );
      } else if (paginationData is! Map<String, dynamic>) {
        print('[NotificationPaginationResponse] Error: pagination field is not a Map, it is ${paginationData.runtimeType}');
        pagination = NotificationPagination(
          currentPage: 1,
          totalPages: 1,
          totalNotifications: notificationsList.length,
          limit: 20,
          hasNextPage: false,
          hasPrevPage: false,
        );
      } else {
        pagination = NotificationPagination.fromJson(paginationData);
      }

      // Parse unread count
      final unreadCount = json['unreadCount'] as int? ?? 0;

      print('[NotificationPaginationResponse] Successfully parsed ${notificationsList.length} notifications, unread: $unreadCount');
      
      return NotificationPaginationResponse(
        notifications: notificationsList,
        pagination: pagination,
        unreadCount: unreadCount,
      );
    } catch (e, stackTrace) {
      print('[NotificationPaginationResponse] Error parsing JSON: $e');
      print('[NotificationPaginationResponse] Stack trace: $stackTrace');
      print('[NotificationPaginationResponse] Problematic JSON: $json');
      
      // Trả về response rỗng thay vì crash
      return NotificationPaginationResponse(
        notifications: [],
        pagination: NotificationPagination(
          currentPage: 1,
          totalPages: 1,
          totalNotifications: 0,
          limit: 20,
          hasNextPage: false,
          hasPrevPage: false,
        ),
        unreadCount: 0,
      );
    }
  }
}

class NotificationPagination {
  final int currentPage;
  final int totalPages;
  final int totalNotifications;
  final int limit;
  final bool hasNextPage;
  final bool hasPrevPage;

  NotificationPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalNotifications,
    required this.limit,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory NotificationPagination.fromJson(Map<String, dynamic> json) {
    return NotificationPagination(
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 1,
      totalNotifications: json['totalNotifications'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
      hasPrevPage: json['hasPrevPage'] as bool? ?? false,
    );
  }
}