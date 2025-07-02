// tiktok_backend/lib/src/features/videos/video_model.dart - UPDATED WITH SHARES TRACKING
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
  final int sharesCount;           // ENHANCED: Now properly tracked
  final List<ObjectId> saves;
  
  // Analytics fields
  final int viewsCount;                    
  final int uniqueViewsCount;              
  final List<ObjectId> uniqueViewers;      
  final Map<String, dynamic> analyticsData; 
  final DateTime? lastViewedAt;            
  
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
    this.sharesCount = 0,              // Default to 0
    this.saves = const [],
    
    // Analytics defaults
    this.viewsCount = 0,
    this.uniqueViewsCount = 0,
    this.uniqueViewers = const [],
    this.analyticsData = const {},
    this.lastViewedAt,
    
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
      'sharesCount': sharesCount,        // Include shares count in map
      'saves': saves.map((id) => id).toList(),
      
      // Analytics fields
      'viewsCount': viewsCount,
      'uniqueViewsCount': uniqueViewsCount,
      'uniqueViewers': uniqueViewers.map((id) => id).toList(),
      'analyticsData': analyticsData,
      'lastViewedAt': lastViewedAt?.toIso8601String(),
      
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
      sharesCount: map['sharesCount'] as int? ?? 0,  // Parse shares count
      saves: (map['saves'] as List?)?.map((id) => id is String ? ObjectId.fromHexString(id) : id as ObjectId).toList() ?? [],
      
      // Analytics fields
      viewsCount: map['viewsCount'] as int? ?? 0,
      uniqueViewsCount: map['uniqueViewsCount'] as int? ?? 0,
      uniqueViewers: (map['uniqueViewers'] as List?)?.map((id) => id is String ? ObjectId.fromHexString(id) : id as ObjectId).toList() ?? [],
      analyticsData: Map<String, dynamic>.from(map['analyticsData'] as Map? ?? {}),
      lastViewedAt: map['lastViewedAt'] != null ? DateTime.tryParse(map['lastViewedAt'] as String) : null,
      
      hashtags: List<String>.from(map['hashtags'] as List? ?? []),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // Helper methods for analytics
  bool hasUserViewed(ObjectId userId) {
    return uniqueViewers.contains(userId);
  }

  double get engagementRate {
    if (viewsCount == 0) return 0.0;
    final totalEngagements = likesCount + commentsCount + sharesCount;  // Include shares in engagement
    return (totalEngagements / viewsCount) * 100;
  }

  // NEW: Share-to-view ratio
  double get shareRate {
    if (viewsCount == 0) return 0.0;
    return (sharesCount / viewsCount) * 100;
  }

  // NEW: Check if video has good viral potential
  bool get hasViralPotential {
    return shareRate > 2.0 && engagementRate > 5.0; // 2% share rate + 5% engagement rate
  }

  Map<String, dynamic> getAnalyticsSummary() {
    return {
      'videoId': id?.toHexString(),
      'viewsCount': viewsCount,
      'uniqueViewsCount': uniqueViewsCount,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,           // Include shares in analytics
      'engagementRate': engagementRate,
      'shareRate': shareRate,               // NEW: Share rate metric
      'hasViralPotential': hasViralPotential, // NEW: Viral potential indicator
      'lastViewedAt': lastViewedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}