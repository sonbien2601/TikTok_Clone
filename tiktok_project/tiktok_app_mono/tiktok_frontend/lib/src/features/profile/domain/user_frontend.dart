// tiktok_frontend/lib/src/features/auth/domain/models/user_frontend.dart
class UserFrontend {
  final String id;
  final String username;
  final String email;
  final String? dateOfBirth;
  final String? gender;
  final List<String> interests;
  final int followersCount;
  final int followingCount;
  final String? role;
  final String? avatarUrl;
  
  // Bank information
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankQrImageUrl;
  final String? bankImageUrl; // ✅ THÊM FIELD NÀY

  UserFrontend({
    required this.id,
    required this.username,
    required this.email,
    this.dateOfBirth,
    this.gender,
    required this.interests,
    required this.followersCount,
    required this.followingCount,
    this.role,
    this.avatarUrl,
    this.bankAccountNumber,
    this.bankName,
    this.bankQrImageUrl,
    this.bankImageUrl, // ✅ THÊM VÀO CONSTRUCTOR
  });

  factory UserFrontend.fromJson(Map<String, dynamic> json) {
    return UserFrontend(
      id: json['_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      dateOfBirth: json['dateOfBirth'],
      gender: json['gender'],
      interests: List<String>.from(json['interests'] ?? []),
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      role: json['role'],
      avatarUrl: json['avatarUrl'],
      bankAccountNumber: json['bankAccountNumber'],
      bankName: json['bankName'],
      bankQrImageUrl: json['bankQrImageUrl'],
      bankImageUrl: json['bankImageUrl'], // ✅ THÊM VÀO fromJson
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'interests': interests,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'role': role,
      'avatarUrl': avatarUrl,
      'bankAccountNumber': bankAccountNumber,
      'bankName': bankName,
      'bankQrImageUrl': bankQrImageUrl,
      'bankImageUrl': bankImageUrl, // ✅ THÊM VÀO toJson
    };
  }

  UserFrontend copyWith({
    String? id,
    String? username,
    String? email,
    String? dateOfBirth,
    String? gender,
    List<String>? interests,
    int? followersCount,
    int? followingCount,
    String? role,
    String? avatarUrl,
    String? bankAccountNumber,
    String? bankName,
    String? bankQrImageUrl,
    String? bankImageUrl, // ✅ THÊM VÀO copyWith
  }) {
    return UserFrontend(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankName: bankName ?? this.bankName,
      bankQrImageUrl: bankQrImageUrl ?? this.bankQrImageUrl,
      bankImageUrl: bankImageUrl ?? this.bankImageUrl, // ✅ THÊM VÀO copyWith
    );
  }

  @override
  String toString() {
    return 'UserFrontend{id: $id, username: $username, email: $email, '
           'dateOfBirth: $dateOfBirth, gender: $gender, interests: $interests, '
           'followersCount: $followersCount, followingCount: $followingCount, '
           'role: $role, avatarUrl: $avatarUrl, bankAccountNumber: $bankAccountNumber, '
           'bankName: $bankName, bankQrImageUrl: $bankQrImageUrl, '
           'bankImageUrl: $bankImageUrl}'; // ✅ THÊM VÀO toString
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserFrontend &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          email == other.email &&
          dateOfBirth == other.dateOfBirth &&
          gender == other.gender &&
          interests == other.interests &&
          followersCount == other.followersCount &&
          followingCount == other.followingCount &&
          role == other.role &&
          avatarUrl == other.avatarUrl &&
          bankAccountNumber == other.bankAccountNumber &&
          bankName == other.bankName &&
          bankQrImageUrl == other.bankQrImageUrl &&
          bankImageUrl == other.bankImageUrl; // ✅ THÊM VÀO equality

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      email.hashCode ^
      dateOfBirth.hashCode ^
      gender.hashCode ^
      interests.hashCode ^
      followersCount.hashCode ^
      followingCount.hashCode ^
      role.hashCode ^
      avatarUrl.hashCode ^
      bankAccountNumber.hashCode ^
      bankName.hashCode ^
      bankQrImageUrl.hashCode ^
      bankImageUrl.hashCode; // ✅ THÊM VÀO hashCode
}