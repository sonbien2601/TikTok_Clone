// tiktok_frontend/lib/src/features/feed/domain/models/comment_model.dart
class CommentModel {
  final String id;
  final String videoId;
  final String userId;
  final String username;
  final String? userAvatarUrl;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likesCount;
  final List<String> likes;
  final String? parentCommentId;
  final int repliesCount;

  CommentModel({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    required this.likesCount,
    required this.likes,
    this.parentCommentId,
    required this.repliesCount,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    try {
      print('[CommentModel] Parsing JSON: ${json.toString()}');
      
      return CommentModel(
        id: _parseString(json['_id'], 'id'),
        videoId: _parseString(json['videoId'], 'videoId'),
        userId: _parseString(json['userId'], 'userId'),
        username: _parseString(json['username'], 'username', defaultValue: 'Anonymous'),
        userAvatarUrl: json['userAvatarUrl'] as String?,
        text: _parseString(json['text'], 'text', defaultValue: ''),
        createdAt: _parseDateTime(json['createdAt']),
        updatedAt: _parseDateTime(json['updatedAt']),
        likesCount: _parseInt(json['likesCount']),
        likes: _parseStringList(json['likes']),
        parentCommentId: json['parentCommentId'] as String?,
        repliesCount: _parseInt(json['repliesCount']),
      );
    } catch (e, stackTrace) {
      print('[CommentModel] Error parsing JSON: $e');
      print('[CommentModel] Stack trace: $stackTrace');
      print('[CommentModel] Problematic JSON: $json');
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
    
    print('[CommentModel] Warning: $fieldName is not a string, got ${value.runtimeType}. Converting to string.');
    return value.toString();
  }

  // Helper method để parse int an toàn
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    
    print('[CommentModel] Warning: Expected int but got ${value.runtimeType}. Using 0.');
    return 0;
  }

  // Helper method để parse DateTime an toàn
  static DateTime _parseDateTime(dynamic dateData) {
    if (dateData == null) {
      print('[CommentModel] Warning: DateTime is null, using current time');
      return DateTime.now();
    }
    
    if (dateData is String) {
      final parsed = DateTime.tryParse(dateData);
      if (parsed != null) return parsed;
      
      print('[CommentModel] Warning: Invalid date string: $dateData, using current time');
      return DateTime.now();
    }
    
    print('[CommentModel] Warning: DateTime is not a string, got ${dateData.runtimeType}, using current time');
    return DateTime.now();
  }

  // Helper method để parse string list an toàn
  static List<String> _parseStringList(dynamic listData) {
    if (listData == null) {
      print('[CommentModel] Warning: List is null, returning empty list');
      return <String>[];
    }
    
    if (listData is! List) {
      print('[CommentModel] Warning: Expected List but got ${listData.runtimeType}, returning empty list');
      return <String>[];
    }
    
    try {
      return (listData as List).map((item) {
        if (item is String) return item;
        return item.toString();
      }).toList();
    } catch (e) {
      print('[CommentModel] Error parsing list: $e, returning empty list');
      return <String>[];
    }
  }

  // Helper method to get relative time
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  // Check if comment is liked by current user
  bool isLikedByUser(String? currentUserId) {
    if (currentUserId == null) return false;
    return likes.contains(currentUserId);
  }

  // Check if comment is a reply
  bool get isReply => parentCommentId != null;

  @override
  String toString() {
    return 'CommentModel(id: $id, username: $username, text: $text, createdAt: $createdAt, likesCount: $likesCount)';
  }
}

// Pagination response model
class CommentPaginationResponse {
  final List<CommentModel> comments;
  final CommentPagination pagination;

  CommentPaginationResponse({
    required this.comments,
    required this.pagination,
  });

  factory CommentPaginationResponse.fromJson(Map<String, dynamic> json) {
    try {
      print('[CommentPaginationResponse] Parsing response JSON...');
      print('[CommentPaginationResponse] JSON keys: ${json.keys.toList()}');
      
      // Safely parse comments array
      final commentsData = json['comments'];
      print('[CommentPaginationResponse] Comments data type: ${commentsData.runtimeType}');
      
      List<CommentModel> commentsList = [];
      
      if (commentsData == null) {
        print('[CommentPaginationResponse] Warning: comments field is null');
      } else if (commentsData is! List) {
        print('[CommentPaginationResponse] Error: comments field is not a List, it is ${commentsData.runtimeType}');
        throw Exception('Comments field must be an array');
      } else {
        final List rawComments = commentsData;
        print('[CommentPaginationResponse] Comments array length: ${rawComments.length}');
        
        for (int i = 0; i < rawComments.length; i++) {
          final item = rawComments[i];
          print('[CommentPaginationResponse] Processing comment $i, type: ${item.runtimeType}');
          
          if (item is! Map<String, dynamic>) {
            print('[CommentPaginationResponse] Warning: Comment $i is not a Map, skipping');
            continue;
          }
          
          try {
            final comment = CommentModel.fromJson(item);
            commentsList.add(comment);
          } catch (e) {
            print('[CommentPaginationResponse] Error parsing comment $i: $e');
            // Continue với các comment khác thay vì fail toàn bộ
          }
        }
      }

      // Safely parse pagination
      final paginationData = json['pagination'];
      print('[CommentPaginationResponse] Pagination data type: ${paginationData.runtimeType}');
      
      CommentPagination pagination;
      
      if (paginationData == null) {
        print('[CommentPaginationResponse] Warning: pagination field is null, using default');
        pagination = CommentPagination(
          currentPage: 1,
          totalPages: 1,
          totalComments: commentsList.length,
          limit: 20,
          hasNextPage: false,
          hasPrevPage: false,
        );
      } else if (paginationData is! Map<String, dynamic>) {
        print('[CommentPaginationResponse] Error: pagination field is not a Map, it is ${paginationData.runtimeType}');
        // Sử dụng default pagination thay vì throw error
        pagination = CommentPagination(
          currentPage: 1,
          totalPages: 1,
          totalComments: commentsList.length,
          limit: 20,
          hasNextPage: false,
          hasPrevPage: false,
        );
      } else {
        pagination = CommentPagination.fromJson(paginationData);
      }

      print('[CommentPaginationResponse] Successfully parsed ${commentsList.length} comments');
      
      return CommentPaginationResponse(
        comments: commentsList,
        pagination: pagination,
      );
    } catch (e, stackTrace) {
      print('[CommentPaginationResponse] Error parsing JSON: $e');
      print('[CommentPaginationResponse] Stack trace: $stackTrace');
      print('[CommentPaginationResponse] Problematic JSON: $json');
      
      // Trả về response rỗng thay vì crash
      return CommentPaginationResponse(
        comments: [],
        pagination: CommentPagination(
          currentPage: 1,
          totalPages: 1,
          totalComments: 0,
          limit: 20,
          hasNextPage: false,
          hasPrevPage: false,
        ),
      );
    }
  }
}

class CommentPagination {
  final int currentPage;
  final int totalPages;
  final int totalComments;
  final int limit;
  final bool hasNextPage;
  final bool hasPrevPage;

  CommentPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalComments,
    required this.limit,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory CommentPagination.fromJson(Map<String, dynamic> json) {
    return CommentPagination(
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 1,
      totalComments: json['totalComments'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
      hasPrevPage: json['hasPrevPage'] as bool? ?? false,
    );
  }
}