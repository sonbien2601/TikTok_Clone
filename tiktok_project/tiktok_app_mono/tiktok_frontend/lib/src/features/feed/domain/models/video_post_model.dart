// UPDATED tiktok_frontend/lib/src/features/feed/domain/models/video_post_model.dart - WITH SHARES COUNT
import 'video_user_model.dart';
import 'package:flutter/foundation.dart';

class VideoPost {
  final String id;
  final VideoUser user;
  final String description;
  final String videoUrl;
  final String? thumbnailUrl;
  final List<String> hashtags;
  final String? audioName;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;               // ENHANCED: Now properly tracked and displayed
  
  // Analytics fields
  final int viewsCount;
  final int uniqueViewsCount;
  final Map<String, dynamic> analyticsData;
  final DateTime? lastViewedAt;
  
  final bool isLikedByCurrentUser;
  final bool isSavedByCurrentUser;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VideoPost({
    required this.id,
    required this.user,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    this.hashtags = const [],
    this.audioName,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,         // Required parameter
    
    // Analytics defaults
    this.viewsCount = 0,
    this.uniqueViewsCount = 0,
    this.analyticsData = const {},
    this.lastViewedAt,
    
    required this.isLikedByCurrentUser,
    required this.isSavedByCurrentUser,
    required this.createdAt,
    this.updatedAt,
  });

  factory VideoPost.fromJson(
    Map<String, dynamic> json,
    String fileBaseUrl, {
    String? currentUserId,
  }) {
    // Parse user data
    final userData = json['user'] as Map<String, dynamic>? ?? {};

    // Extract user ID from different possible fields
    String userId = '';
    if (userData['id'] != null) {
      userId = userData['id'].toString();
    } else if (userData['_id'] != null) {
      userId = userData['_id'].toString();
    } else if (json['userId'] != null) {
      userId = json['userId'].toString();
    }

    // Extract username safely
    String username = 'Unknown User';
    if (userData['username'] != null &&
        userData['username'].toString().isNotEmpty) {
      username = userData['username'].toString();
    } else if (json['username'] != null &&
        json['username'].toString().isNotEmpty) {
      username = json['username'].toString();
    }

    // Create VideoUser with all required fields
    final videoUser = VideoUser(
      id: userId,
      username: username,
      avatarUrl: userData['avatarUrl'] as String?,
      bio: userData['bio'] as String?,
      isVerified: userData['isVerified'] as bool? ?? false,
      followersCount: userData['followersCount'] as int? ?? 0,
      followingCount: userData['followingCount'] as int? ?? 0,
      isFollowing: userData['isFollowing'] as bool? ?? false,
    );

    // Parse hashtags
    List<String> hashtagsList = [];
    if (json['hashtags'] is List) {
      hashtagsList = List<String>.from(json['hashtags'] as List);
    } else if (json['hashtags'] is String) {
      final hashtagsStr = json['hashtags'] as String;
      hashtagsList = hashtagsStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Parse likes and check if current user liked
    final likes = json['likes'] as List? ?? [];
    bool isLikedByCurrentUser = false;
    if (currentUserId != null) {
      isLikedByCurrentUser = likes.contains(currentUserId);
    }

    // Parse saves and check if current user saved
    final saves = json['saves'] as List? ?? [];
    bool isSavedByCurrentUser = false;
    if (currentUserId != null) {
      isSavedByCurrentUser = saves.contains(currentUserId);
    }

    // Parse video URL - FIX DOUBLE SLASH ISSUE
    String videoUrl = '';
    if (json['videoUrl'] is String && (json['videoUrl'] as String).isNotEmpty) {
      final rawVideoUrl = json['videoUrl'] as String;
      if (rawVideoUrl.startsWith('http://') ||
          rawVideoUrl.startsWith('https://')) {
        videoUrl = rawVideoUrl;
      } else {
        // ENHANCED URL BUILDING TO PREVENT DOUBLE SLASHES
        videoUrl = _buildCleanUrl(fileBaseUrl, rawVideoUrl);
      }
    }

    // Parse thumbnail URL - FIX DOUBLE SLASH ISSUE
    String? thumbnailUrl;
    if (json['thumbnailUrl'] is String &&
        (json['thumbnailUrl'] as String).isNotEmpty) {
      final rawThumbnailUrl = json['thumbnailUrl'] as String;
      if (rawThumbnailUrl.startsWith('http://') ||
          rawThumbnailUrl.startsWith('https://')) {
        thumbnailUrl = rawThumbnailUrl;
      } else {
        // ENHANCED URL BUILDING TO PREVENT DOUBLE SLASHES
        thumbnailUrl = _buildCleanUrl(fileBaseUrl, rawThumbnailUrl);
      }
    }

    return VideoPost(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      user: videoUser,
      description: json['description'] as String? ?? '',
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      hashtags: hashtagsList,
      audioName: json['audioName'] as String?,
      likesCount: json['likesCount'] as int? ?? likes.length,
      commentsCount: json['commentsCount'] as int? ?? 0,
      sharesCount: json['sharesCount'] as int? ?? 0,  // Parse shares count from backend
      
      // Analytics fields
      viewsCount: json['viewsCount'] as int? ?? 0,
      uniqueViewsCount: json['uniqueViewsCount'] as int? ?? 0,
      analyticsData: Map<String, dynamic>.from(json['analyticsData'] as Map? ?? {}),
      lastViewedAt: json['lastViewedAt'] != null 
        ? DateTime.tryParse(json['lastViewedAt'] as String)
        : null,
      
      isLikedByCurrentUser: isLikedByCurrentUser,
      isSavedByCurrentUser: isSavedByCurrentUser,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String? ?? '')
          : null,
    );
  }

  // ROBUST URL BUILDER TO PREVENT DOUBLE SLASHES
  static String _buildCleanUrl(String baseUrl, String path) {
    debugPrint('[VideoPost] _buildCleanUrl - Input baseUrl: "$baseUrl"');
    debugPrint('[VideoPost] _buildCleanUrl - Input path: "$path"');
    
    try {
      // Use Uri.resolve for proper URL building
      final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
      final pathToResolve = path.startsWith('/') ? path.substring(1) : path;
      final resolved = base.resolve(pathToResolve);
      final result = resolved.toString();
      
      debugPrint('[VideoPost] _buildCleanUrl - URI resolved result: "$result"');
      return result;
    } catch (e) {
      debugPrint('[VideoPost] _buildCleanUrl - URI resolve failed: $e');
      
      // Fallback: Manual string manipulation
      String result = '$baseUrl/$path';
      
      // Fix multiple slashes but preserve protocol
      result = result.replaceAll(RegExp(r'(?<!:)//+'), '/');
      
      debugPrint('[VideoPost] _buildCleanUrl - Fallback result: "$result"');
      return result;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'hashtags': hashtags,
      'audioName': audioName,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,           // Include shares count in JSON
      
      // Analytics fields
      'viewsCount': viewsCount,
      'uniqueViewsCount': uniqueViewsCount,
      'analyticsData': analyticsData,
      'lastViewedAt': lastViewedAt?.toIso8601String(),
      
      'isLikedByCurrentUser': isLikedByCurrentUser,
      'isSavedByCurrentUser': isSavedByCurrentUser,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  VideoPost copyWith({
    String? id,
    VideoUser? user,
    String? description,
    String? videoUrl,
    String? thumbnailUrl,
    List<String>? hashtags,
    String? audioName,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,                     // Allow updating shares count
    
    // Analytics fields
    int? viewsCount,
    int? uniqueViewsCount,
    Map<String, dynamic>? analyticsData,
    DateTime? lastViewedAt,
    
    bool? isLikedByCurrentUser,
    bool? isSavedByCurrentUser,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoPost(
      id: id ?? this.id,
      user: user ?? this.user,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      hashtags: hashtags ?? this.hashtags,
      audioName: audioName ?? this.audioName,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,   // Update shares count
      
      // Analytics fields
      viewsCount: viewsCount ?? this.viewsCount,
      uniqueViewsCount: uniqueViewsCount ?? this.uniqueViewsCount,
      analyticsData: analyticsData ?? this.analyticsData,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isSavedByCurrentUser: isSavedByCurrentUser ?? this.isSavedByCurrentUser,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  String get formattedLikesCount => _formatCount(likesCount);
  String get formattedCommentsCount => _formatCount(commentsCount);
  String get formattedSharesCount => _formatCount(sharesCount);     // NEW: Format shares count
  
  // Analytics helper methods
  String get formattedViewsCount => _formatCount(viewsCount);
  String get formattedUniqueViewsCount => _formatCount(uniqueViewsCount);
  
  double get engagementRate {
    if (viewsCount == 0) return 0.0;
    final totalEngagements = likesCount + commentsCount + sharesCount;  // Include shares in engagement
    return (totalEngagements / viewsCount) * 100;
  }
  
  String get formattedEngagementRate => '${engagementRate.toStringAsFixed(1)}%';
  
  double get uniqueViewRate {
    if (viewsCount == 0) return 0.0;
    return (uniqueViewsCount / viewsCount) * 100;
  }
  
  String get formattedUniqueViewRate => '${uniqueViewRate.toStringAsFixed(1)}%';
  
  // NEW: Share rate calculation
  double get shareRate {
    if (viewsCount == 0) return 0.0;
    return (sharesCount / viewsCount) * 100;
  }
  
  String get formattedShareRate => '${shareRate.toStringAsFixed(1)}%';
  
  // NEW: Check if video has viral potential
  bool get hasViralPotential {
    return shareRate > 2.0 && engagementRate > 5.0; // 2% share rate + 5% engagement rate
  }
  
  // Check if video is trending (enhanced with shares)
  bool get isTrending {
    final hoursSinceCreated = DateTime.now().difference(createdAt).inHours;
    if (hoursSinceCreated == 0) return false;
    
    final viewsPerHour = viewsCount / hoursSinceCreated;
    final sharesPerHour = sharesCount / hoursSinceCreated;
    final engagementThreshold = 5.0; // 5% engagement rate
    
    return viewsPerHour > 10 && 
           engagementRate > engagementThreshold && 
           (sharesPerHour > 0.5 || hasViralPotential); // Include share metrics in trending calculation
  }

  // NEW: Get engagement breakdown
  Map<String, dynamic> get engagementBreakdown {
    final total = likesCount + commentsCount + sharesCount;
    if (total == 0) {
      return {
        'likes': 0.0,
        'comments': 0.0,
        'shares': 0.0,
      };
    }
    
    return {
      'likes': (likesCount / total) * 100,
      'comments': (commentsCount / total) * 100,
      'shares': (sharesCount / total) * 100,
    };
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
  }

  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  String toString() {
    return 'VideoPost(id: $id, user: ${user.username}, description: $description, likesCount: $likesCount, sharesCount: $sharesCount, viewsCount: $viewsCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoPost && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}