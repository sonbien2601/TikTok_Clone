// tiktok_backend/lib/src/features/users/user_model.dart
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class User {
  final ObjectId? id;
  final String username;
  final String email;
  final String passwordHash;
  final DateTime? dateOfBirth;
  final String? gender;
  final List<String> interests;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ObjectId> savedVideos;
  
  // NEW FOLLOW SYSTEM FIELDS
  final List<ObjectId> following;     // Users this user is following
  final List<ObjectId> followers;    // Users following this user
  final int followingCount;          // Cached count for performance
  final int followersCount;          // Cached count for performance

  User({
    this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    this.dateOfBirth,
    this.gender,
    this.interests = const [],
    this.isAdmin = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.savedVideos = const [],
    // NEW FOLLOW FIELDS WITH DEFAULTS
    this.following = const [],
    this.followers = const [],
    this.followingCount = 0,
    this.followersCount = 0,
  })  : this.createdAt = createdAt ?? DateTime.now(),
        this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email.toLowerCase(),
      'passwordHash': passwordHash,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'interests': interests,
      'isAdmin': isAdmin,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'savedVideos': savedVideos.map((id) => id).toList(),
      // NEW FOLLOW FIELDS IN MAP
      'following': following.map((id) => id).toList(),
      'followers': followers.map((id) => id).toList(),
      'followingCount': followingCount,
      'followersCount': followersCount,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    if (map['username'] == null || map['email'] == null || map['passwordHash'] == null || map['createdAt'] == null || map['updatedAt'] == null) {
        throw ArgumentError("User.fromMap: Missing required fields in map.");
    }
    return User(
      id: map['_id'] as ObjectId?,
      username: map['username'] as String,
      email: map['email'] as String,
      passwordHash: map['passwordHash'] as String,
      dateOfBirth: map['dateOfBirth'] != null ? DateTime.tryParse(map['dateOfBirth'] as String) : null,
      gender: map['gender'] as String?,
      interests: List<String>.from(map['interests'] as List? ?? []),
      isAdmin: map['isAdmin'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      savedVideos: (map['savedVideos'] as List?)?.map((id) => id is String ? ObjectId.fromHexString(id) : id as ObjectId).toList() ?? [],
      // NEW FOLLOW FIELDS PARSING
      following: (map['following'] as List?)?.map((id) => id is String ? ObjectId.fromHexString(id) : id as ObjectId).toList() ?? [],
      followers: (map['followers'] as List?)?.map((id) => id is String ? ObjectId.fromHexString(id) : id as ObjectId).toList() ?? [],
      followingCount: map['followingCount'] as int? ?? 0,
      followersCount: map['followersCount'] as int? ?? 0,
    );
  }

  // HELPER METHODS FOR FOLLOW SYSTEM
  bool isFollowing(String userId) {
    final userObjectId = ObjectId.fromHexString(userId);
    return following.contains(userObjectId);
  }

  bool isFollowedBy(String userId) {
    final userObjectId = ObjectId.fromHexString(userId);
    return followers.contains(userObjectId);
  }

  User copyWith({
    ObjectId? id,
    String? username,
    String? email,
    String? passwordHash,
    DateTime? dateOfBirth,
    String? gender,
    List<String>? interests,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ObjectId>? savedVideos,
    List<ObjectId>? following,
    List<ObjectId>? followers,
    int? followingCount,
    int? followersCount,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      savedVideos: savedVideos ?? this.savedVideos,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      followingCount: followingCount ?? this.followingCount,
      followersCount: followersCount ?? this.followersCount,
    );
  }
}