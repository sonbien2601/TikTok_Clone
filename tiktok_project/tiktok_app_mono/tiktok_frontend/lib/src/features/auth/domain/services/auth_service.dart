// tiktok_frontend/lib/src/features/auth/domain/services/auth_service.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, ChangeNotifier;
import 'package:http/http.dart' as http;

class UserFrontend {
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
    return 'UserFrontend(id: $id, username: $username, email: $email, isAdmin: $isAdmin, dob: $dateOfBirth, gender: $gender, interests: $interests)';
  }
}

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  UserFrontend? _currentUser;

  // Cố định backend host và port
  static const String _backendHost = 'localhost';
  static const String _backendPort = '8080';
  static const String _apiPath = '/api/users';

  String get _baseUrl {
    if (kIsWeb) {
      // Web: luôn dùng localhost:8080
      return 'http://$_backendHost:$_backendPort$_apiPath';
    } else {
      try {
        if (Platform.isAndroid) {
          // Android emulator: 10.0.2.2 maps to host localhost
          return 'http://10.0.2.2:$_backendPort$_apiPath';
        } else if (Platform.isIOS) {
          // iOS simulator: có thể dùng localhost
          return 'http://$_backendHost:$_backendPort$_apiPath';
        }
      } catch (e) { 
        print("[AuthService] Error checking platform: $e");
      }
      // Fallback cho desktop hoặc platform khác
      return 'http://$_backendHost:$_backendPort$_apiPath';
    }
  }

  // Getter để debug URL hiện tại
  String get currentBaseUrl => _baseUrl;

  bool get isAuthenticated => _isAuthenticated;
  UserFrontend? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  void _updateAuthState(bool isAuthenticated, Map<String, dynamic>? userDataFromApi) {
    print('[AuthService] _updateAuthState called. Target isAuthenticated: $isAuthenticated, hasUserData: ${userDataFromApi != null}');
    this._isAuthenticated = isAuthenticated;
    if (isAuthenticated && userDataFromApi != null) {
      try {
        this._currentUser = UserFrontend.fromJson(userDataFromApi);
        print('[AuthService] User data parsed. User: ${this._currentUser}');
      } catch (e) {
        print('[AuthService] Error parsing user data in _updateAuthState: $e. User will be null.');
        this._currentUser = null;
        this._isAuthenticated = false; 
      }
    } else {
      this._currentUser = null;
      if (isAuthenticated && userDataFromApi == null) {
          print('[AuthService] Auth reported success but no user data. Setting isAuthenticated to false.');
          this._isAuthenticated = false;
      }
    }
    notifyListeners();
    print('[AuthService] notifyListeners called. New state: isAuthenticated: ${this._isAuthenticated}, currentUser: ${_currentUser?.username}');
  }
  
  Future<void> login(String identifierValue, String password) async {
    final targetUrl = Uri.parse('$_baseUrl/login');
    print('[AuthService] Attempting login with Identifier: "$identifierValue" to $targetUrl');
    print('[AuthService] Using base URL: $_baseUrl');
    
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
        print('[AuthService] ❌ Cannot connect to backend server at $_baseUrl');
        print('[AuthService] 💡 Please ensure backend server is running on port $_backendPort');
      }
      _updateAuthState(false, null); 
      rethrow; 
    }
  }

  Future<bool> register(
    String username, String email, String password,
    DateTime? dateOfBirth, String? gender, List<String> interests,
  ) async {
    final targetUrl = Uri.parse('$_baseUrl/register');
    print('[AuthService] Attempting register for Username: "$username" to $targetUrl');
    print('[AuthService] Using base URL: $_baseUrl');
    
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
        print('[AuthService] Registration successful (backend).');
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
        print('[AuthService] ❌ Cannot connect to backend server at $_baseUrl');
        print('[AuthService] 💡 Please ensure backend server is running on port $_backendPort');
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
      final healthUrl = Uri.parse('http://$_backendHost:$_backendPort/health');
      print('[AuthService] Testing connection to $healthUrl');
      
      final response = await http.get(healthUrl).timeout(const Duration(seconds: 5));
      print('[AuthService] Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[AuthService] Connection test failed: $e');
      return false;
    }
  }
}