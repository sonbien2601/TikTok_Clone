// tiktok_backend/lib/src/features/videos/video_model.dart
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class Video {
  final ObjectId? id;
  final ObjectId userId;
  final String username;        
  final String? userAvatarUrl; 
  final String description;
  final String videoUrl;
  final String? audioName;
  final List<ObjectId> likes;      
  final int likesCount;            
  int commentsCount;         
  final int sharesCount;           
  final List<ObjectId> saves;      
  final List<String> hashtags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Video({
    this.id,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    required this.description,
    required this.videoUrl,
    this.audioName,
    this.likes = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.saves = const [],
    this.hashtags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : this.createdAt = createdAt ?? DateTime.now(),
       this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'description': description,
      'videoUrl': videoUrl,
      'audioName': audioName,
      'likes': likes.map((id) => id).toList(),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'saves': saves.map((id) => id).toList(),
      'hashtags': hashtags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Video.fromMap(Map<String, dynamic> map) {
    return Video(
      id: map['_id'] as ObjectId?,
      userId: map['userId'] is String ? ObjectId.fromHexString(map['userId']) : map['userId'] as ObjectId,
      username: map['username'] as String? ?? 'Unknown User',
      userAvatarUrl: map['userAvatarUrl'] as String?,
      description: map['description'] as String? ?? '',
      videoUrl: map['videoUrl'] as String? ?? '',
      audioName: map['audioName'] as String?,
      likes: (map['likes'] as List?)?.map((id) => id is String ? ObjectId.fromHexString(id) : id as ObjectId).toList() ?? [],
      likesCount: map['likesCount'] as int? ?? 0,
      commentsCount: map['commentsCount'] as int? ?? 0,
      sharesCount: map['sharesCount'] as int? ?? 0,
      saves: (map['saves'] as List?)?.map((id) => id is String ? ObjectId.fromHexString(id) : id as ObjectId).toList() ?? [],
      hashtags: List<String>.from(map['hashtags'] as List? ?? []),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
