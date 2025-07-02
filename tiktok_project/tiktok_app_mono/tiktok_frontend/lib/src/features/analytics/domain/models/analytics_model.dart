// tiktok_frontend/lib/src/features/analytics/domain/models/analytics_model.dart
import 'package:flutter/foundation.dart';

// Video Analytics Model
class VideoAnalytics {
  final String videoId;
  final int viewsCount;
  final int uniqueViewsCount;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final double engagementRate;
  final double averageViewDuration;
  final int totalViewDuration;
  final Map<String, int> viewSources;
  final Map<int, int> hourlyViews;
  final Map<String, int> dailyViews;
  final DateTime createdAt;
  final DateTime? lastViewedAt;
  final double uniqueViewRate;

  VideoAnalytics({
    required this.videoId,
    required this.viewsCount,
    required this.uniqueViewsCount,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.engagementRate,
    required this.averageViewDuration,
    required this.totalViewDuration,
    required this.viewSources,
    required this.hourlyViews,
    required this.dailyViews,
    required this.createdAt,
    this.lastViewedAt,
    required this.uniqueViewRate,
  });

  factory VideoAnalytics.fromJson(Map<String, dynamic> json) {
    return VideoAnalytics(
      videoId: json['videoId'] as String,
      viewsCount: json['viewsCount'] as int? ?? 0,
      uniqueViewsCount: json['uniqueViewsCount'] as int? ?? 0,
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      sharesCount: json['sharesCount'] as int? ?? 0,
      engagementRate: (json['engagementRate'] as num?)?.toDouble() ?? 0.0,
      averageViewDuration: (json['averageViewDuration'] as num?)?.toDouble() ?? 0.0,
      totalViewDuration: json['totalViewDuration'] as int? ?? 0,
      viewSources: Map<String, int>.from(json['viewSources'] as Map? ?? {}),
      hourlyViews: Map<int, int>.from(
        (json['hourlyViews'] as Map? ?? {}).map(
          (k, v) => MapEntry(int.tryParse(k.toString()) ?? 0, v as int),
        ),
      ),
      dailyViews: Map<String, int>.from(json['dailyViews'] as Map? ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastViewedAt: json['lastViewedAt'] != null 
        ? DateTime.tryParse(json['lastViewedAt'] as String)
        : null,
      uniqueViewRate: (json['uniqueViewRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'viewsCount': viewsCount,
      'uniqueViewsCount': uniqueViewsCount,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'engagementRate': engagementRate,
      'averageViewDuration': averageViewDuration,
      'totalViewDuration': totalViewDuration,
      'viewSources': viewSources,
      'hourlyViews': hourlyViews,
      'dailyViews': dailyViews,
      'createdAt': createdAt.toIso8601String(),
      'lastViewedAt': lastViewedAt?.toIso8601String(),
      'uniqueViewRate': uniqueViewRate,
    };
  }

  // Helper getters
  String get formattedViewsCount => _formatCount(viewsCount);
  String get formattedLikesCount => _formatCount(likesCount);
  String get formattedCommentsCount => _formatCount(commentsCount);
  String get formattedSharesCount => _formatCount(sharesCount);
  
  String get formattedEngagementRate => '${engagementRate.toStringAsFixed(1)}%';
  String get formattedUniqueViewRate => '${uniqueViewRate.toStringAsFixed(1)}%';
  String get formattedAverageViewDuration => '${averageViewDuration.toStringAsFixed(1)}s';

  int get totalEngagements => likesCount + commentsCount + sharesCount;

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
  }
}

// User Analytics Model
class UserAnalytics {
  final String userId;
  final int totalVideos;
  final int totalViews;
  final int totalUniqueViews;
  final int totalLikes;
  final int totalComments;
  final int totalShares;
  final double averageEngagementRate;
  final List<VideoAnalyticsPreview> videos;

  UserAnalytics({
    required this.userId,
    required this.totalVideos,
    required this.totalViews,
    required this.totalUniqueViews,
    required this.totalLikes,
    required this.totalComments,
    required this.totalShares,
    required this.averageEngagementRate,
    required this.videos,
  });

  factory UserAnalytics.fromJson(Map<String, dynamic> json) {
    return UserAnalytics(
      userId: json['userId'] as String? ?? '',
      totalVideos: json['totalVideos'] as int? ?? 0,
      totalViews: json['totalViews'] as int? ?? 0,
      totalUniqueViews: json['totalUniqueViews'] as int? ?? 0,
      totalLikes: json['totalLikes'] as int? ?? 0,
      totalComments: json['totalComments'] as int? ?? 0,
      totalShares: json['totalShares'] as int? ?? 0,
      averageEngagementRate: (json['averageEngagementRate'] as num?)?.toDouble() ?? 0.0,
      videos: (json['videos'] as List? ?? [])
          .map((video) => VideoAnalyticsPreview.fromJson(video))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'totalVideos': totalVideos,
      'totalViews': totalViews,
      'totalUniqueViews': totalUniqueViews,
      'totalLikes': totalLikes,
      'totalComments': totalComments,
      'totalShares': totalShares,
      'averageEngagementRate': averageEngagementRate,
      'videos': videos.map((v) => v.toJson()).toList(),
    };
  }

  // Helper getters
  String get formattedTotalViews => _formatCount(totalViews);
  String get formattedTotalLikes => _formatCount(totalLikes);
  String get formattedAverageEngagementRate => '${averageEngagementRate.toStringAsFixed(1)}%';
  
  double get averageViewsPerVideo => totalVideos > 0 ? totalViews / totalVideos : 0.0;
  double get averageLikesPerVideo => totalVideos > 0 ? totalLikes / totalVideos : 0.0;

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
  }
}

// Video Analytics Preview (for user analytics)
class VideoAnalyticsPreview {
  final String videoId;
  final String description;
  final DateTime createdAt;
  final VideoAnalytics analytics;

  VideoAnalyticsPreview({
    required this.videoId,
    required this.description,
    required this.createdAt,
    required this.analytics,
  });

  factory VideoAnalyticsPreview.fromJson(Map<String, dynamic> json) {
    return VideoAnalyticsPreview(
      videoId: json['videoId'] as String,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      analytics: VideoAnalytics.fromJson(json['analytics'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'analytics': analytics.toJson(),
    };
  }
}

// Trending Video Model
class TrendingVideo {
  final String videoId;
  final String userId;
  final String username;
  final String description;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final double engagementRate;
  final DateTime createdAt;
  final DateTime? lastViewedAt;

  TrendingVideo({
    required this.videoId,
    required this.userId,
    required this.username,
    required this.description,
    required this.viewsCount,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.engagementRate,
    required this.createdAt,
    this.lastViewedAt,
  });

  factory TrendingVideo.fromJson(Map<String, dynamic> json) {
    return TrendingVideo(
      videoId: json['videoId'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String? ?? 'Unknown User',
      description: json['description'] as String? ?? '',
      viewsCount: json['viewsCount'] as int? ?? 0,
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      sharesCount: json['sharesCount'] as int? ?? 0,
      engagementRate: (json['engagementRate'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastViewedAt: json['lastViewedAt'] != null 
        ? DateTime.tryParse(json['lastViewedAt'] as String)
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'userId': userId,
      'username': username,
      'description': description,
      'viewsCount': viewsCount,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'engagementRate': engagementRate,
      'createdAt': createdAt.toIso8601String(),
      'lastViewedAt': lastViewedAt?.toIso8601String(),
    };
  }

  // Helper getters
  String get formattedViewsCount => _formatCount(viewsCount);
  String get formattedLikesCount => _formatCount(likesCount);
  String get formattedEngagementRate => '${engagementRate.toStringAsFixed(1)}%';
  
  int get totalEngagements => likesCount + commentsCount + sharesCount;

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
  }
}

// Analytics Summary Model
class AnalyticsSummary {
  final int totalViews;
  final int totalUniqueViews;
  final int totalVideos;
  final double averageEngagementRate;
  final List<TrendingVideo> topPerformingVideos;
  final Map<String, dynamic> viewTrends;

  AnalyticsSummary({
    required this.totalViews,
    required this.totalUniqueViews,
    required this.totalVideos,
    required this.averageEngagementRate,
    required this.topPerformingVideos,
    required this.viewTrends,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalViews: json['totalViews'] as int? ?? 0,
      totalUniqueViews: json['totalUniqueViews'] as int? ?? 0,
      totalVideos: json['totalVideos'] as int? ?? 0,
      averageEngagementRate: (json['averageEngagementRate'] as num?)?.toDouble() ?? 0.0,
      topPerformingVideos: (json['topPerformingVideos'] as List? ?? [])
          .map((video) => TrendingVideo.fromJson(video))
          .toList(),
      viewTrends: Map<String, dynamic>.from(json['viewTrends'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalViews': totalViews,
      'totalUniqueViews': totalUniqueViews,
      'totalVideos': totalVideos,
      'averageEngagementRate': averageEngagementRate,
      'topPerformingVideos': topPerformingVideos.map((v) => v.toJson()).toList(),
      'viewTrends': viewTrends,
    };
  }

  // Helper getters
  String get formattedTotalViews => _formatCount(totalViews);
  String get formattedAverageEngagementRate => '${averageEngagementRate.toStringAsFixed(1)}%';

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
  }
}

// View Track Data Model (for bulk tracking)
class ViewTrackData {
  final String videoId;
  final String? userId;
  final int viewDuration;
  final String viewSource;
  final DateTime timestamp;

  ViewTrackData({
    required this.videoId,
    this.userId,
    required this.viewDuration,
    required this.viewSource,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'userId': userId,
      'viewDuration': viewDuration,
      'viewSource': viewSource,
      'isUniqueView': true,
    };
  }

  factory ViewTrackData.fromJson(Map<String, dynamic> json) {
    return ViewTrackData(
      videoId: json['videoId'] as String,
      userId: json['userId'] as String?,
      viewDuration: json['viewDuration'] as int? ?? 0,
      viewSource: json['viewSource'] as String? ?? 'feed',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}