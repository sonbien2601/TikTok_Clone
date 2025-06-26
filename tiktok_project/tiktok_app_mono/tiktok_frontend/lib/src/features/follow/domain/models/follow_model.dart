// tiktok_frontend/lib/src/features/follow/domain/models/follow_model.dart

// Result when following/unfollowing a user
class FollowResult {
  final String message;
  final bool isFollowing;
  final int followerCount;
  final int followingCount;

  FollowResult({
    required this.message,
    required this.isFollowing,
    required this.followerCount,
    required this.followingCount,
  });

  factory FollowResult.fromJson(Map<String, dynamic> json) {
    return FollowResult(
      message: json['message'] as String? ?? '',
      isFollowing: json['isFollowing'] as bool? ?? false,
      followerCount: json['followerCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'isFollowing': isFollowing,
      'followerCount': followerCount,
      'followingCount': followingCount,
    };
  }
}

// User model for follow lists
class FollowUser {
  final String id;
  final String username;
  final String? dateOfBirth;
  final String? gender;
  final List<String> interests;
  final int followersCount;
  final int followingCount;
  final DateTime createdAt;
  final String? avatarUrl; // For future use

  FollowUser({
    required this.id,
    required this.username,
    this.dateOfBirth,
    this.gender,
    this.interests = const [],
    required this.followersCount,
    required this.followingCount,
    required this.createdAt,
    this.avatarUrl,
  });

  factory FollowUser.fromJson(Map<String, dynamic> json) {
    return FollowUser(
      id: json['id'] as String,
      username: json['username'] as String,
      dateOfBirth: json['dateOfBirth'] as String?,
      gender: json['gender'] as String?,
      interests: List<String>.from(json['interests'] as List? ?? []),
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'interests': interests,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'createdAt': createdAt.toIso8601String(),
      'avatarUrl': avatarUrl,
    };
  }

  // Helper methods
  String get displayName => '@$username';
  
  String get formattedFollowersCount => _formatCount(followersCount);
  String get formattedFollowingCount => _formatCount(followingCount);

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
  }

  String get genderDisplay {
    if (gender == null) return '';
    switch (gender!.toLowerCase()) {
      case 'male':
        return 'Nam';
      case 'female':
        return 'Nữ';
      default:
        return 'Khác';
    }
  }

  bool get hasInterests => interests.isNotEmpty;
}

// Pagination info for follow lists
class FollowPagination {
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final int limit;
  final bool hasNextPage;
  final bool hasPrevPage;

  FollowPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.limit,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory FollowPagination.fromJson(Map<String, dynamic> json, {required bool isFollowersList}) {
    final countKey = isFollowersList ? 'totalFollowers' : 'totalFollowing';
    
    return FollowPagination(
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 1,
      totalCount: json[countKey] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
      hasPrevPage: json['hasPrevPage'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentPage': currentPage,
      'totalPages': totalPages,
      'totalCount': totalCount,
      'limit': limit,
      'hasNextPage': hasNextPage,
      'hasPrevPage': hasPrevPage,
    };
  }
}

// Response for followers/following lists
class FollowListResponse {
  final List<FollowUser> users;
  final FollowPagination pagination;
  final bool isFollowersList; // true for followers, false for following

  FollowListResponse({
    required this.users,
    required this.pagination,
    required this.isFollowersList,
  });

  factory FollowListResponse.fromJson(Map<String, dynamic> json, {required bool isFollowersList}) {
    final usersKey = isFollowersList ? 'followers' : 'following';
    final usersData = json[usersKey] as List? ?? [];
    
    return FollowListResponse(
      users: usersData.map((userData) => FollowUser.fromJson(userData as Map<String, dynamic>)).toList(),
      pagination: FollowPagination.fromJson(json['pagination'] as Map<String, dynamic>, isFollowersList: isFollowersList),
      isFollowersList: isFollowersList,
    );
  }

  Map<String, dynamic> toJson() {
    final usersKey = isFollowersList ? 'followers' : 'following';
    
    return {
      usersKey: users.map((user) => user.toJson()).toList(),
      'pagination': pagination.toJson(),
    };
  }

  // Helper methods
  bool get isEmpty => users.isEmpty;
  bool get isNotEmpty => users.isNotEmpty;
  int get length => users.length;
  
  String get listType => isFollowersList ? 'Người theo dõi' : 'Đang theo dõi';
  String get emptyMessage => isFollowersList 
      ? 'Chưa có người nào theo dõi' 
      : 'Chưa theo dõi ai';
}

// Follow status between two users
class FollowStatus {
  final bool isFollowing;
  final TargetUserInfo targetUser;

  FollowStatus({
    required this.isFollowing,
    required this.targetUser,
  });

  factory FollowStatus.fromJson(Map<String, dynamic> json) {
    return FollowStatus(
      isFollowing: json['isFollowing'] as bool? ?? false,
      targetUser: TargetUserInfo.fromJson(json['targetUser'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isFollowing': isFollowing,
      'targetUser': targetUser.toJson(),
    };
  }
}

// Target user info in follow status
class TargetUserInfo {
  final String id;
  final String username;
  final int followersCount;
  final int followingCount;

  TargetUserInfo({
    required this.id,
    required this.username,
    required this.followersCount,
    required this.followingCount,
  });

  factory TargetUserInfo.fromJson(Map<String, dynamic> json) {
    return TargetUserInfo(
      id: json['id'] as String,
      username: json['username'] as String,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'followersCount': followersCount,
      'followingCount': followingCount,
    };
  }

  String get displayName => '@$username';
  String get formattedFollowersCount => _formatCount(followersCount);
  String get formattedFollowingCount => _formatCount(followingCount);

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