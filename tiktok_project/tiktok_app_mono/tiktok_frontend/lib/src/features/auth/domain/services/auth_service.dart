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
  });

  factory UserFrontend.fromJson(Map<String, dynamic> json) {
    print('[UserFrontend] Parsing user data: ${json.keys}');
    print('[UserFrontend] followersCount: ${json['followersCount']}');
    print('[UserFrontend] followingCount: ${json['followingCount']}');

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
        print(
            '[AuthService] Updating current user follower count: ${_currentUser!.followersCount} -> $newFollowerCount');

        _currentUser = _currentUser!.copyWith(
          followersCount: newFollowerCount,
        );

        notifyListeners();
      }
    }
  }

  void notifyFollowCountsChanged() {
    print('[AuthService] Follow counts changed - triggering refresh');
    refreshUserData().then((_) {
      print('[AuthService] Follow counts refreshed successfully');
    }).catchError((e) {
      print('[AuthService] Error refreshing follow counts: $e');
    });
  }

  Future<String> get currentBaseUrl => NetworkConfig.getBaseUrl('/api/users');

  void _updateAuthState(
      bool isAuthenticated, Map<String, dynamic>? userDataFromApi) {
    print(
        '[AuthService] _updateAuthState called. Target isAuthenticated: $isAuthenticated');
    this._isAuthenticated = isAuthenticated;
    if (isAuthenticated && userDataFromApi != null) {
      try {
        this._currentUser = UserFrontend.fromJson(userDataFromApi);
        print('[AuthService] User data parsed. User: ${this._currentUser}');

        // Sync with FollowStateManager
        if (_currentUser != null) {
          _followStateManager.updateFollowState(
            userId: _currentUser!.id,
            isFollowing: false, // Current user doesn't follow themselves
            followerCount: _currentUser!.followersCount,
          );
        }
      } catch (e) {
        print('[AuthService] Error parsing user data: $e');
        this._currentUser = null;
        this._isAuthenticated = false;
      }
    } else {
      this._currentUser = null;
      if (isAuthenticated && userDataFromApi == null) {
        print('[AuthService] Auth reported success but no user data.');
        this._isAuthenticated = false;
      }
    }
    notifyListeners();
  }

  Future<void> login(String identifierValue, String password) async {
    final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
    final targetUrl = Uri.parse('$baseUrl/login');

    print('[AuthService] Auto-detected backend URL: $baseUrl');
    print('[AuthService] Attempting login to: $targetUrl');

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

      print('[AuthService] Login Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('user') &&
            responseData['user'] is Map<String, dynamic>) {
          _updateAuthState(true, responseData['user'] as Map<String, dynamic>);

          // Check for notifications after successful login
          if (_currentUser != null) {
            print(
                '[AuthService] ✅ Login successful, checking for notifications...');
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
      print('[AuthService] Login error: $e');
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        NetworkConfig.clearCache();
        print('[AuthService] ❌ Connection failed, cleared IP cache');
        print('[AuthService] 💡 Next login attempt will try to find new IP');
      }
      _updateAuthState(false, null);
      rethrow;
    }
  }

  // NEW: Check for notifications after login
  Future<void> _checkNotificationsAfterLogin() async {
    if (_currentUser == null) return;

    try {
      print(
          '[AuthService] 🔔 Checking for new notifications for user: ${_currentUser!.id}');

      // Delay to allow UI to settle after login
      await Future.delayed(const Duration(seconds: 1));

      // Check notifications and show popup if there are any
      await _notificationPopupService
          .checkNotificationsOnLogin(_currentUser!.id);

      print('[AuthService] ✅ Notification check completed');
    } catch (e) {
      print('[AuthService] ❌ Error checking notifications after login: $e');
      // Don't throw error - notifications are not critical for login flow
    }
  }

  // NEW: Initialize notification popup service with context
  void initializeNotificationPopup(context) {
    if (_currentUser != null) {
      _notificationPopupService.initialize(context);
      print('[AuthService] 🔔 Notification popup service initialized');
    }
  }

  // NEW: Enable/disable notification popups
  void setNotificationPopupsEnabled(bool enabled) {
    _notificationPopupService.setEnabled(enabled);
    print(
        '[AuthService] 🔔 Notification popups ${enabled ? 'enabled' : 'disabled'}');
  }

  Future<void> refreshUserData() async {
    if (!_isAuthenticated || _currentUser == null) {
      print(
          '[AuthService] Cannot refresh - not authenticated or no current user');
      return;
    }

    try {
      print('[AuthService] Refreshing user data for user: ${_currentUser!.id}');

      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/${_currentUser!.id}');

      print('[AuthService] Making request to: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[AuthService] Response status: ${response.statusCode}');
      print('[AuthService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);

        print('[AuthService] Parsed user data keys: ${userData.keys}');
        print(
            '[AuthService] followersCount in response: ${userData['followersCount']}');
        print(
            '[AuthService] followingCount in response: ${userData['followingCount']}');

        // Create new user object
        final newUser = UserFrontend.fromJson(userData);

        print('[AuthService] New user object: $newUser');

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

        print('[AuthService] ✅ User data refreshed successfully');
        print(
            '[AuthService] Current follow counts - Followers: ${_currentUser!.followersCount}, Following: ${_currentUser!.followingCount}');
      } else {
        print(
            '[AuthService] ❌ Failed to refresh user data: ${response.statusCode}');
        print('[AuthService] Error response: ${response.body}');
        throw Exception('Failed to refresh user data: ${response.statusCode}');
      }
    } catch (e) {
      print('[AuthService] ❌ Error refreshing user data: $e');
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
      print('[AuthService] Error getting fresh user data: $e');
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

    print('[AuthService] Auto-detected backend URL for register: $baseUrl');

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

      print('[AuthService] Register Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[AuthService] Registration successful.');
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
      print('[AuthService] Register error: $e');
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        NetworkConfig.clearCache();
        print(
            '[AuthService] ❌ Connection failed during register, cleared IP cache');
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
    String? bankImageUrl, // ✅ THÊM PARAMETER NÀY
  ) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/auth');
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

      // ✅ THÊM BANK IMAGE URL
      if (bankImageUrl != null && bankImageUrl.isNotEmpty) {
        requestBody['bankImageUrl'] = bankImageUrl;
      }

      print(
          '[AuthService] Registration request body keys: ${requestBody.keys}');
      print(
          '[AuthService] Bank info - Account: $bankAccountNumber, Bank: $bankName');
      print(
          '[AuthService] Bank images - QR: $bankQrImageUrl, Image: $bankImageUrl');

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

      print(
          '[AuthService] Registration response status: ${response.statusCode}');
      print('[AuthService] Registration response body: ${response.body}');

      if (response.statusCode == 201) {
        return true;
      } else {
        String errorMessage = 'Registration failed';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {}

        print('[AuthService] Registration failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[AuthService] Error during registration: $e');
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        throw Exception(
            'Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    print('[AuthService] Logging out...');
    await Future.delayed(const Duration(milliseconds: 100));
    // KHÔNG force dispose hoặc clear state ở đây!
    _followStateManager.clearAll();
    _notificationPopupService.reset();
    _updateAuthState(false, null);
    print('[AuthService] User logged out.');
  }

  // Force clear all state and dispose all controllers
  Future<void> _forceClearAllState() async {
    print('[AuthService] Force clearing all state...');

    try {
      // Force dispose all video controllers
      VideoFeedView.forceDisposeAllVideos();
      print('[AuthService] All video controllers force disposed');

      // Clear any cached data
      await Future.delayed(const Duration(milliseconds: 200));

      // Force garbage collection if possible
      // Note: This is not available in all Flutter versions
      try {
        // ignore: deprecated_member_use
        // ignore: unused_result
        // ignore: avoid_print
        print('[AuthService] Requesting garbage collection...');
      } catch (e) {
        print('[AuthService] Garbage collection not available: $e');
      }
    } catch (e) {
      print('[AuthService] Error during force clear: $e');
    }
  }

  // Method to restart app completely (nuclear option)
  void restartApp() {
    print('[AuthService] Restarting app completely...');
    // This will force a complete app restart
    // Note: This is a nuclear option and should be used carefully
    try {
      // Force dispose everything
      _forceClearAllState();

      // Clear all state
      _followStateManager.clearAll();
      _notificationPopupService.reset();
      _updateAuthState(false, null);

      print('[AuthService] App restart completed');
    } catch (e) {
      print('[AuthService] Error during app restart: $e');
    }
  }

  // Method để test connection
  Future<bool> testConnection() async {
    try {
      final fileBaseUrl = await NetworkConfig.getFileBaseUrl();
      final healthUrl = Uri.parse('$fileBaseUrl/health');
      print('[AuthService] Testing connection to $healthUrl');

      final response =
          await http.get(healthUrl).timeout(const Duration(seconds: 5));
      print('[AuthService] Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[AuthService] Connection test failed: $e');
      return false;
    }
  }

  // Force refresh IP cache
  void refreshNetworkConfig() {
    NetworkConfig.clearCache();
    print('[AuthService] Network configuration refreshed');
  }

  // Dispose method to clean up notification service
  @override
  void dispose() {
    _notificationPopupService.dispose();
    super.dispose();
  }
}
