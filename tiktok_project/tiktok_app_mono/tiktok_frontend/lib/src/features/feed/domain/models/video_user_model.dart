// tiktok_frontend/lib/src/features/feed/domain/models/video_user_model.dart
class VideoUser {
  final String id;          // ADD THIS FIELD
  final String username;
  final String? avatarUrl;
  final String? bio;
  final bool isVerified;
  final int followersCount;  // ADD THIS FIELD  
  final int followingCount;  // ADD THIS FIELD
  final bool isFollowing;    // ADD THIS FIELD

  VideoUser({
    required this.id,        // REQUIRED FIELD
    required this.username,
    this.avatarUrl,
    this.bio,
    this.isVerified = false,
    this.followersCount = 0, // DEFAULT VALUE
    this.followingCount = 0, // DEFAULT VALUE
    this.isFollowing = false, // DEFAULT VALUE
  });

  factory VideoUser.fromJson(Map<String, dynamic> json) {
    return VideoUser(
      id: json['id'] as String? ?? json['_id'] as String? ?? '', // HANDLE BOTH _id AND id
      username: json['username'] as String? ?? 'Unknown User',
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'isVerified': isVerified,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'isFollowing': isFollowing,
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

  VideoUser copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    String? bio,
    bool? isVerified,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
  }) {
    return VideoUser(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  @override
  String toString() {
    return 'VideoUser(id: $id, username: $username, followersCount: $followersCount, isFollowing: $isFollowing)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}