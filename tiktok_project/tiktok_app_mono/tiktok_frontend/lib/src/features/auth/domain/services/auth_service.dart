import 'dart:convert';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:http/http.dart' as http;
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:tiktok_frontend/src/features/follow/domain/services/follow_state_manager.dart';
import 'package:tiktok_frontend/src/features/notifications/domain/services/notification_popup_service.dart';
import 'package:tiktok_frontend/src/features/feed/presentation/views/video_feed_view.dart';

class UserFrontend {
  final String id;
  final String username;
  final String email;
  final bool isAdmin;
  final String? dateOfBirth;
  final String? gender;
  final List<String> interests;
  final String? avatarUrl;

  // Follow count fields
  final int followersCount;
  final int followingCount;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankQrImageUrl;

  UserFrontend({
    required this.id,
    required this.username,
    required this.email,
    required this.isAdmin,
    this.dateOfBirth,
    this.gender,
    this.interests = const [],
    this.followersCount = 0,
    this.followingCount = 0,
    this.bankAccountNumber,
    this.bankName,
    this.bankQrImageUrl,
    this.avatarUrl,
  });

  factory UserFrontend.fromJson(Map<String, dynamic> json) {
    return UserFrontend(
      id: json['_id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      isAdmin: json['isAdmin'] as bool? ?? false,
      dateOfBirth: json['dateOfBirth'] as String?,
      gender: json['gender'] as String?,
      interests: List<String>.from(json['interests'] as List? ?? []),
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankName: json['bankName'] as String?,
      bankQrImageUrl: json['bankQrImageUrl'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  // Copy with method
  UserFrontend copyWith({
    String? id,
    String? username,
    String? email,
    bool? isAdmin,
    String? dateOfBirth,
    String? gender,
    List<String>? interests,
    int? followersCount,
    int? followingCount,
    String? bankAccountNumber,
    String? bankName,
    String? bankQrImageUrl,
    String? avatarUrl,
  }) {
    return UserFrontend(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankName: bankName ?? this.bankName,
      bankQrImageUrl: bankQrImageUrl ?? this.bankQrImageUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'email': email,
      'isAdmin': isAdmin,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'interests': interests,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'bankAccountNumber': bankAccountNumber,
      'bankName': bankName,
      'bankQrImageUrl': bankQrImageUrl,
      'avatarUrl': avatarUrl,
    };
  }

  @override
  String toString() {
    return 'UserFrontend(id: $id, username: $username, followers: $followersCount, following: $followingCount)';
  }
}

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  UserFrontend? _currentUser;

  // FollowStateManager instance
  final FollowStateManager _followStateManager = FollowStateManager();

  // NotificationPopupService instance
  final NotificationPopupService _notificationPopupService =
      NotificationPopupService();

  bool get isAuthenticated => _isAuthenticated;
  UserFrontend? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  // Getter for FollowStateManager
  FollowStateManager get followStateManager => _followStateManager;

  // Getter for NotificationPopupService
  NotificationPopupService get notificationPopupService =>
      _notificationPopupService;

  // Method to update current user's follow counts from FollowStateManager
  void updateCurrentUserFollowCounts() {
    if (_currentUser == null) return;

    final currentUserId = _currentUser!.id;
    final followInfo = _followStateManager.getFollowInfo(currentUserId);

    if (followInfo['hasData'] == true) {
      final newFollowerCount = followInfo['followerCount'] as int;

      if (newFollowerCount != _currentUser!.followersCount) {
        _currentUser = _currentUser!.copyWith(
          followersCount: newFollowerCount,
        );

        notifyListeners();
      }
    }
  }

  void notifyFollowCountsChanged() {
    refreshUserData().then((_) {
    }).catchError((e) {
    });
  }

  Future<String> get currentBaseUrl => NetworkConfig.getBaseUrl('/api/users');

  void _updateAuthState(
      bool isAuthenticated, Map<String, dynamic>? userDataFromApi) {
    this._isAuthenticated = isAuthenticated;
    if (isAuthenticated && userDataFromApi != null) {
      try {
        this._currentUser = UserFrontend.fromJson(userDataFromApi);

        // Sync with FollowStateManager
        if (_currentUser != null) {
          _followStateManager.updateFollowState(
            userId: _currentUser!.id,
            isFollowing: false, // Current user doesn't follow themselves
            followerCount: _currentUser!.followersCount,
          );
        }
      } catch (e) {
        this._currentUser = null;
        this._isAuthenticated = false;
      }
    } else {
      this._currentUser = null;
      if (isAuthenticated && userDataFromApi == null) {
        this._isAuthenticated = false;
      }
    }
    notifyListeners();
  }

  Future<void> login(String identifierValue, String password) async {
    final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
    final targetUrl = Uri.parse('$baseUrl/login');

    try {
      final response = await http
          .post(
            targetUrl,
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, String>{
              'identifier': identifierValue,
              'password': password
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('user') &&
            responseData['user'] is Map<String, dynamic>) {
          _updateAuthState(true, responseData['user'] as Map<String, dynamic>);

          // Check for notifications after successful login
          if (_currentUser != null) {
            await _checkNotificationsAfterLogin();
          }
        } else {
          _updateAuthState(false, null);
          throw Exception('Login response missing or invalid user data.');
        }
      } else {
        String errorMessage = 'Failed to login. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {}
        _updateAuthState(false, null);
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        NetworkConfig.clearCache();
      }
      _updateAuthState(false, null);
      rethrow;
    }
  }

  // NEW: Check for notifications after login
  Future<void> _checkNotificationsAfterLogin() async {
    if (_currentUser == null) return;

    try {
      // Delay to allow UI to settle after login
      await Future.delayed(const Duration(seconds: 1));

      // Check notifications and show popup if there are any
      await _notificationPopupService
          .checkNotificationsOnLogin(_currentUser!.id);

    } catch (e) {
      // Don't throw error - notifications are not critical for login flow
    }
  }

  // NEW: Initialize notification popup service with context
  void initializeNotificationPopup(context) {
    if (_currentUser != null) {
      _notificationPopupService.initialize(context);
    }
  }

  // NEW: Enable/disable notification popups
  void setNotificationPopupsEnabled(bool enabled) {
    _notificationPopupService.setEnabled(enabled);
  }

  Future<void> refreshUserData() async {
    if (!_isAuthenticated || _currentUser == null) {
      return;
    }

    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/${_currentUser!.id}');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);

        // Create new user object
        final newUser = UserFrontend.fromJson(userData);

        // Update current user
        _currentUser = newUser;
        _isAuthenticated = true;

        // Sync with FollowStateManager
        _followStateManager.updateFollowState(
          userId: _currentUser!.id,
          isFollowing: false, // Current user doesn't follow themselves
          followerCount: _currentUser!.followersCount,
        );

        // Notify listeners to rebuild UI
        notifyListeners();

      } else {
        throw Exception('Failed to refresh user data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Không thể tải lại thông tin người dùng: $e');
    }
  }

  Future<UserFrontend?> getFreshUserData() async {
    if (!_isAuthenticated || _currentUser == null) return null;

    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final targetUrl = Uri.parse('$baseUrl/${_currentUser!.id}');

      final response = await http.get(
        targetUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData is Map<String, dynamic>) {
          return UserFrontend.fromJson(responseData);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> register(
    String username,
    String email,
    String password,
    DateTime? dateOfBirth,
    String? gender,
    List<String> interests,
  ) async {
    final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
    final targetUrl = Uri.parse('$baseUrl/register');

    try {
      final response = await http
          .post(
            targetUrl,
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'username': username,
              'email': email,
              'password': password,
              'dateOfBirth': dateOfBirth?.toIso8601String(),
              'gender': gender,
              'interests': interests,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else {
        String errorMessage =
            'Failed to register. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        NetworkConfig.clearCache();
      }
      rethrow;
    }
  }

  Future<bool> registerWithBank(
    String username,
    String email,
    String password,
    DateTime? dateOfBirth,
    String? gender,
    List<String> interests,
    String? bankAccountNumber,
    String? bankName,
    String? bankQrImageUrl,
    String? bankImageUrl, // GIỮ parameter để không break existing code
  ) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/register');

      final Map<String, dynamic> requestBody = {
        'username': username,
        'email': email,
        'password': password,
        'interests': interests,
      };

      if (dateOfBirth != null) {
        requestBody['dateOfBirth'] = dateOfBirth.toIso8601String();
      }

      if (gender != null) {
        requestBody['gender'] = gender;
      }

      // Add bank information if provided
      if (bankAccountNumber != null && bankAccountNumber.isNotEmpty) {
        requestBody['bankAccountNumber'] = bankAccountNumber;
      }

      if (bankName != null && bankName.isNotEmpty) {
        requestBody['bankName'] = bankName;
      }

      if (bankQrImageUrl != null && bankQrImageUrl.isNotEmpty) {
        requestBody['bankQrImageUrl'] = bankQrImageUrl;
      }

      // BỎ phần bankImageUrl - không gửi lên server nữa
      /*
    if (bankImageUrl != null && bankImageUrl.isNotEmpty) {
      requestBody['bankImageUrl'] = bankImageUrl;
    }
    */

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return true;
      } else {
        String errorMessage = 'Registration failed';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {}

        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        throw Exception(
            'Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 100));
    // KHÔNG force dispose hoặc clear state ở đây!
    _followStateManager.clearAll();
    _notificationPopupService.reset();
    _updateAuthState(false, null);
  }

  // Force clear all state and dispose all controllers
  Future<void> _forceClearAllState() async {
    try {
      // Force dispose all video controllers
      VideoFeedView.forceDisposeAllVideos();

      // Clear any cached data
      await Future.delayed(const Duration(milliseconds: 200));

      // Force garbage collection if possible
      // Note: This is not available in all Flutter versions
      try {
        // ignore: deprecated_member_use
        // ignore: unused_result
        // ignore: avoid_print
      } catch (e) {
      }
    } catch (e) {
    }
  }

  // Method to restart app completely (nuclear option)
  void restartApp() {
    // This will force a complete app restart
    // Note: This is a nuclear option and should be used carefully
    try {
      // Force dispose everything
      _forceClearAllState();

      // Clear all state
      _followStateManager.clearAll();
      _notificationPopupService.reset();
      _updateAuthState(false, null);

    } catch (e) {
    }
  }

  // Method để test connection
  Future<bool> testConnection() async {
    try {
      final fileBaseUrl = await NetworkConfig.getFileBaseUrl();
      final healthUrl = Uri.parse('$fileBaseUrl/health');

      final response =
          await http.get(healthUrl).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Force refresh IP cache
  void refreshNetworkConfig() {
    NetworkConfig.clearCache();
  }

  // Dispose method to clean up notification service
  @override
  void dispose() {
    _notificationPopupService.dispose();
    super.dispose();
  }
}
