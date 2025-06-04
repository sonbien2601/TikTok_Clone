// tiktok_backend/lib/src/features/comments/models/comment_model.dart
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class Comment {
  final ObjectId? id;
  final ObjectId videoId; 
  final ObjectId userId;  
  final String username;  
  final String? userAvatarUrl; 
  final String text;
  final DateTime createdAt;

  Comment({
    this.id,
    required this.videoId,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    required this.text,
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['_id'] as ObjectId?,
      videoId: map['videoId'] is String ? ObjectId.fromHexString(map['videoId']) : map['videoId'] as ObjectId,
      userId: map['userId'] is String ? ObjectId.fromHexString(map['userId']) : map['userId'] as ObjectId,
      username: map['username'] as String? ?? 'Unknown User',
      userAvatarUrl: map['userAvatarUrl'] as String?,
      text: map['text'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
