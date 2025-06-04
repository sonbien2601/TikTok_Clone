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
  final List<ObjectId> savedVideos; // << TRƯỜNG ĐÃ THÊM

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
    );
  }
}
