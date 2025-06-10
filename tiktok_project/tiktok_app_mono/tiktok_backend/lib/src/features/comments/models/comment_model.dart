// tiktok_backend/lib/src/features/comments/models/comment_model.dart
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class Comment {
  final ObjectId? id;
  final ObjectId videoId;
  final ObjectId userId;
  final String username;        
  final String? userAvatarUrl; 
  final String text;
  final List<ObjectId> likes;      
  final int likesCount;            
  final int repliesCount;         
  final ObjectId? parentCommentId; // For replies
  final DateTime createdAt;
  final DateTime updatedAt;

  Comment({
    this.id,
    required this.videoId,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    required this.text,
    this.likes = const [],
    this.likesCount = 0,
    this.repliesCount = 0,
    this.parentCommentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : this.createdAt = createdAt ?? DateTime.now(),
       this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'videoId': videoId,
      'userId': userId,
      'username': username,
      'text': text,
      'likes': likes.map((id) => id).toList(),
      'likesCount': likesCount,
      'repliesCount': repliesCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
    
    // Only add userAvatarUrl if it's not null
    if (userAvatarUrl != null) {
      map['userAvatarUrl'] = userAvatarUrl;
    }
    
    // Only add parentCommentId if it's not null
    if (parentCommentId != null) {
      map['parentCommentId'] = parentCommentId;
    }
    
    return map;
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['_id'] as ObjectId?,
      videoId: map['videoId'] is String ? ObjectId.fromHexString(map['videoId']) : map['videoId'] as ObjectId,
      userId: map['userId'] is String ? ObjectId.fromHexString(map['userId']) : map['userId'] as ObjectId,
      username: map['username'] as String? ?? 'Anonymous',
      userAvatarUrl: map['userAvatarUrl'] as String?,
      text: map['text'] as String? ?? '',
      likes: _parseLikes(map['likes']),
      likesCount: map['likesCount'] as int? ?? 0,
      repliesCount: map['repliesCount'] as int? ?? 0,
      parentCommentId: _parseObjectId(map['parentCommentId']),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // Helper method to safely parse likes array
  static List<ObjectId> _parseLikes(dynamic likesData) {
    if (likesData == null) return [];
    
    if (likesData is List) {
      return likesData.map((id) {
        if (id is String) {
          return ObjectId.fromHexString(id);
        } else if (id is ObjectId) {
          return id;
        } else {
          throw ArgumentError('Invalid like ID type: ${id.runtimeType}');
        }
      }).toList();
    }
    
    return [];
  }

  // Helper method to safely parse ObjectId
  static ObjectId? _parseObjectId(dynamic idData) {
    if (idData == null) return null;
    
    if (idData is String) {
      return ObjectId.fromHexString(idData);
    } else if (idData is ObjectId) {
      return idData;
    }
    
    return null;
  }

  // Helper method to validate comment text
  static String? validateText(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 'Comment text cannot be empty';
    }
    if (text.length > 500) {
      return 'Comment text cannot exceed 500 characters';
    }
    return null; // Valid
  }

  // Helper method to check if comment is valid
  bool get isValid {
    return text.trim().isNotEmpty && 
           username.trim().isNotEmpty &&
           text.length <= 500;
  }

  // Helper method to check if comment is a reply
  bool get isReply => parentCommentId != null;

  @override
  String toString() {
    return 'Comment(id: $id, username: $username, text: $text, createdAt: $createdAt, likesCount: $likesCount, isReply: $isReply)';
  }
}