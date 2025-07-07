// tiktok_frontend/lib/src/features/search/domain/models/search_model.dart

class SearchUser {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final int videosCount;
  final bool isVerified;
  final bool? isFollowing;
  final double? trendingScore;
  final RecentActivity? recentActivity;
  final String? createdAt;

  SearchUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    required this.followersCount,
    required this.followingCount,
    required this.videosCount,
    required this.isVerified,
    this.isFollowing,
    this.trendingScore,
    this.recentActivity,
    this.createdAt,
  });

  factory SearchUser.fromJson(Map<String, dynamic> json) {
    return SearchUser(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      videosCount: json['videosCount'] as int? ?? 0,
      isVerified: json['isVerified'] as bool? ?? false,
      isFollowing: json['isFollowing'] as bool?,
      trendingScore: (json['trendingScore'] as num?)?.toDouble(),
      recentActivity: json['recentActivity'] != null 
          ? RecentActivity.fromJson(json['recentActivity'])
          : null,
      createdAt: json['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'videosCount': videosCount,
      'isVerified': isVerified,
      'isFollowing': isFollowing,
      'trendingScore': trendingScore,
      'recentActivity': recentActivity?.toJson(),
      'createdAt': createdAt,
    };
  }
}

class RecentActivity {
  final int recentVideos;
  final int recentLikes;
  final int recentViews;
  final String timeframe;

  RecentActivity({
    required this.recentVideos,
    required this.recentLikes,
    required this.recentViews,
    required this.timeframe,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      recentVideos: json['recentVideos'] as int? ?? 0,
      recentLikes: json['recentLikes'] as int? ?? 0,
      recentViews: json['recentViews'] as int? ?? 0,
      timeframe: json['timeframe'] as String? ?? '7d',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recentVideos': recentVideos,
      'recentLikes': recentLikes,
      'recentViews': recentViews,
      'timeframe': timeframe,
    };
  }
}

class SearchVideo {
  final String id;
  final String description;
  final String videoUrl;
  final String? thumbnailUrl;
  final int? duration;
  final List<String> hashtags;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final String? createdAt;
  final SearchVideoUser user;

  SearchVideo({
    required this.id,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    this.duration,
    required this.hashtags,
    required this.viewsCount,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    this.createdAt,
    required this.user,
  });

  factory SearchVideo.fromJson(Map<String, dynamic> json) {
    return SearchVideo(
      id: json['id'] as String,
      description: json['description'] as String? ?? '',
      videoUrl: json['videoUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      duration: json['duration'] as int?,
      hashtags: List<String>.from(json['hashtags'] ?? []),
      viewsCount: json['viewsCount'] as int? ?? 0,
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      sharesCount: json['sharesCount'] as int? ?? 0,
      createdAt: json['createdAt'] as String?,
      user: SearchVideoUser.fromJson(json['user']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'hashtags': hashtags,
      'viewsCount': viewsCount,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'createdAt': createdAt,
      'user': user.toJson(),
    };
  }
}

class SearchVideoUser {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;

  SearchVideoUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.isVerified,
  });

  factory SearchVideoUser.fromJson(Map<String, dynamic> json) {
    return SearchVideoUser(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'isVerified': isVerified,
    };
  }
}

class SearchSuggestion {
  final String type;
  final String value;
  final String displayName;
  final String? avatarUrl;
  final int? followersCount;

  SearchSuggestion({
    required this.type,
    required this.value,
    required this.displayName,
    this.avatarUrl,
    this.followersCount,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      type: json['type'] as String,
      value: json['value'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      followersCount: json['followersCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'followersCount': followersCount,
    };
  }
}

class SearchPagination {
  final int currentPage;
  final int totalPages;
  final int totalResults;
  final bool hasNextPage;
  final bool hasPreviousPage;

  SearchPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalResults,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory SearchPagination.fromJson(Map<String, dynamic> json) {
    return SearchPagination(
      currentPage: json['currentPage'] as int,
      totalPages: json['totalPages'] as int,
      totalResults: json['totalUsers'] as int? ?? json['totalVideos'] as int? ?? 0,
      hasNextPage: json['hasNextPage'] as bool,
      hasPreviousPage: json['hasPreviousPage'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentPage': currentPage,
      'totalPages': totalPages,
      'totalResults': totalResults,
      'hasNextPage': hasNextPage,
      'hasPreviousPage': hasPreviousPage,
    };
  }
}

// Response Models
class UserSearchResponse {
  final List<SearchUser> users;
  final SearchPagination pagination;
  final String searchQuery;
  final String timestamp;

  UserSearchResponse({
    required this.users,
    required this.pagination,
    required this.searchQuery,
    required this.timestamp,
  });

  factory UserSearchResponse.fromJson(Map<String, dynamic> json) {
    return UserSearchResponse(
      users: (json['users'] as List<dynamic>)
          .map((user) => SearchUser.fromJson(user))
          .toList(),
      pagination: SearchPagination.fromJson(json['pagination']),
      searchQuery: json['searchQuery'] as String,
      timestamp: json['timestamp'] as String,
    );
  }
}

class TrendingUsersResponse {
  final List<SearchUser> trendingUsers;
  final String timeframe;
  final int limit;
  final String timestamp;
  final String algorithm;

  TrendingUsersResponse({
    required this.trendingUsers,
    required this.timeframe,
    required this.limit,
    required this.timestamp,
    required this.algorithm,
  });

  factory TrendingUsersResponse.fromJson(Map<String, dynamic> json) {
    return TrendingUsersResponse(
      trendingUsers: (json['trendingUsers'] as List<dynamic>)
          .map((user) => SearchUser.fromJson(user))
          .toList(),
      timeframe: json['timeframe'] as String,
      limit: json['limit'] as int,
      timestamp: json['timestamp'] as String,
      algorithm: json['algorithm'] as String? ?? 'Default algorithm',
    );
  }
}

class VideoSearchResponse {
  final List<SearchVideo> videos;
  final SearchPagination pagination;
  final String searchQuery;
  final String timestamp;

  VideoSearchResponse({
    required this.videos,
    required this.pagination,
    required this.searchQuery,
    required this.timestamp,
  });

  factory VideoSearchResponse.fromJson(Map<String, dynamic> json) {
    return VideoSearchResponse(
      videos: (json['videos'] as List<dynamic>)
          .map((video) => SearchVideo.fromJson(video))
          .toList(),
      pagination: SearchPagination.fromJson(json['pagination']),
      searchQuery: json['searchQuery'] as String,
      timestamp: json['timestamp'] as String,
    );
  }
}

class SearchSuggestionsResponse {
  final List<SearchSuggestion> suggestions;
  final String query;
  final int limit;
  final String timestamp;

  SearchSuggestionsResponse({
    required this.suggestions,
    required this.query,
    required this.limit,
    required this.timestamp,
  });

  factory SearchSuggestionsResponse.fromJson(Map<String, dynamic> json) {
    return SearchSuggestionsResponse(
      suggestions: (json['suggestions'] as List<dynamic>)
          .map((suggestion) => SearchSuggestion.fromJson(suggestion))
          .toList(),
      query: json['query'] as String,
      limit: json['limit'] as int,
      timestamp: json['timestamp'] as String,
    );
  }
}