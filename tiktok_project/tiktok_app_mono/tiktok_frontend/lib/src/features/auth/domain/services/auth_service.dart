// Cập nhật AuthService để sử dụng auto-detection
// tiktok_frontend/lib/src/features/auth/domain/services/auth_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:http/http.dart' as http;
import 'package:tiktok_frontend/src/core/config/network_config.dart'; // Import NetworkConfig

class UserFrontend {
  // ... (giữ nguyên UserFrontend class)
  final String id;
  final String username;
  final String email;
  final bool isAdmin;
  final String? dateOfBirth; 
  final String? gender;
  final List<String> interests;

  UserFrontend({
    required this.id,
    required this.username,
    required this.email,
    this.isAdmin = false,
    this.dateOfBirth,
    this.gender,
    this.interests = const [],
  });

  factory UserFrontend.fromJson(Map<String, dynamic> json) {
    return UserFrontend(
      id: json['_id'] as String? ?? 'N/A_ID_ERROR',
      username: json['username'] as String? ?? 'N/A_Username',
      email: json['email'] as String? ?? 'N/A_Email',
      isAdmin: json['isAdmin'] as bool? ?? false,
      dateOfBirth: json['dateOfBirth'] as String?,
      gender: json['gender'] as String?,
      interests: List<String>.from(json['interests'] as List? ?? []),
    );
  }

  @override
  String toString() {
    return 'UserFrontend(id: $id, username: $username, email: $email, isAdmin: $isAdmin)';
  }
}

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  UserFrontend? _currentUser;

  bool get isAuthenticated => _isAuthenticated;
  UserFrontend? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  // Getter để debug URL hiện tại
  Future<String> get currentBaseUrl => NetworkConfig.getBaseUrl('/api/users');

  void _updateAuthState(bool isAuthenticated, Map<String, dynamic>? userDataFromApi) {
    print('[AuthService] _updateAuthState called. Target isAuthenticated: $isAuthenticated');
    this._isAuthenticated = isAuthenticated;
    if (isAuthenticated && userDataFromApi != null) {
      try {
        this._currentUser = UserFrontend.fromJson(userDataFromApi);
        print('[AuthService] User data parsed. User: ${this._currentUser}');
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
    // AUTO-DETECT IP và tạo URL
    final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
    final targetUrl = Uri.parse('$baseUrl/login');
    
    print('[AuthService] Auto-detected backend URL: $baseUrl');
    print('[AuthService] Attempting login to: $targetUrl');
    
    try {
      final response = await http.post(
        targetUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'identifier': identifierValue, 
          'password': password
        }),
      ).timeout(const Duration(seconds: 10));

      print('[AuthService] Login Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData is Map<String, dynamic> && 
            responseData.containsKey('user') && 
            responseData['user'] is Map<String, dynamic>) {
          _updateAuthState(true, responseData['user'] as Map<String, dynamic>);
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
        // Clear cache và thử lại với IP khác
        NetworkConfig.clearCache();
        print('[AuthService] ❌ Connection failed, cleared IP cache');
        print('[AuthService] 💡 Next login attempt will try to find new IP');
      }
      _updateAuthState(false, null); 
      rethrow; 
    }
  }

  Future<bool> register(
    String username, String email, String password,
    DateTime? dateOfBirth, String? gender, List<String> interests,
  ) async {
    // AUTO-DETECT IP và tạo URL
    final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
    final targetUrl = Uri.parse('$baseUrl/register');
    
    print('[AuthService] Auto-detected backend URL for register: $baseUrl');
    
    try {
      final response = await http.post(
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
      ).timeout(const Duration(seconds: 10));

      print('[AuthService] Register Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[AuthService] Registration successful.');
        return true; 
      } else {
        String errorMessage = 'Failed to register. Status: ${response.statusCode}';
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
        print('[AuthService] ❌ Connection failed during register, cleared IP cache');
      }
      rethrow; 
    }
  }
  
  Future<void> logout() async {
    print('[AuthService] Logging out...');
    await Future.delayed(const Duration(milliseconds: 100)); 
    _updateAuthState(false, null);
    print('[AuthService] User logged out.');
  }

  // Method để test connection
  Future<bool> testConnection() async {
    try {
      final fileBaseUrl = await NetworkConfig.getFileBaseUrl();
      final healthUrl = Uri.parse('$fileBaseUrl/health');
      print('[AuthService] Testing connection to $healthUrl');
      
      final response = await http.get(healthUrl).timeout(const Duration(seconds: 5));
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
}