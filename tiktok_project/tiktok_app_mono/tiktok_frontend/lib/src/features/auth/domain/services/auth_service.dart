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
  // Bạn có thể thêm các trường khác nếu backend trả về
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
      dateOfBirth: json['dateOfBirth'] as String?, // Lấy từ JSON nếu có
      gender: json['gender'] as String?,         // Lấy từ JSON nếu có
      interests: List<String>.from(json['interests'] as List? ?? []), // Lấy từ JSON nếu có
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

  String get _baseUrl {
    const String backendPort = "8080";
    const String apiPath = "/api/users";
    if (kIsWeb) {
      return 'http://localhost:$backendPort$apiPath';
    } else {
      try {
        if (Platform.isAndroid) return 'http://10.0.2.2:$backendPort$apiPath';
        if (Platform.isIOS) return 'http://localhost:$backendPort$apiPath';
      } catch (e) { print("[AuthService] Error checking platform: $e");}
      return 'http://localhost:$backendPort$apiPath';
    }
  }

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
    print('[Frontend AuthService] Attempting login with Identifier: "$identifierValue" to $targetUrl');
    
    try {
      final response = await http.post(
        targetUrl,
        headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, String>{'identifier': identifierValue, 'password': password}),
      );

      print('[Frontend AuthService] Login Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData is Map<String, dynamic> && responseData.containsKey('user') && responseData['user'] is Map<String, dynamic>) {
          _updateAuthState(true, responseData['user'] as Map<String, dynamic>); // Bỏ ? ở cuối vì đã kiểm tra
        } else {
          _updateAuthState(false, null);
          throw Exception('Login response missing or invalid user data.');
        }
      } else {
        String errorMessage = 'Failed to login. Status: ${response.statusCode}';
        try { final errorData = jsonDecode(response.body); errorMessage = errorData['error'] ?? errorMessage; } catch (_) {}
        _updateAuthState(false, null); 
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[Frontend AuthService] Login error: $e');
      _updateAuthState(false, null); 
      rethrow; 
    }
  }

  Future<bool> register(
    String username, String email, String password,
    DateTime? dateOfBirth, String? gender, List<String> interests,
  ) async {
    final targetUrl = Uri.parse('$_baseUrl/register');
    print('[Frontend AuthService] Attempting register for Username: "$username" to $targetUrl with DOB: ${dateOfBirth?.toIso8601String()}');
    
    try {
      final response = await http.post(
        targetUrl,
        headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, dynamic>{
          'username': username, 'email': email, 'password': password,
          'dateOfBirth': dateOfBirth?.toIso8601String(),
          'gender': gender, 'interests': interests,
        }),
      );

      print('[Frontend AuthService] Register Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[Frontend AuthService] Registration successful (backend).');
        return true; 
      } else {
        String errorMessage = 'Failed to register. Status: ${response.statusCode}';
        try { final errorData = jsonDecode(response.body); errorMessage = errorData['error'] ?? errorMessage; } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[Frontend AuthService] Register error: $e');
      rethrow; 
    }
  }
  
  Future<void> logout() async {
    print('[Frontend AuthService] Logging out...');
    await Future.delayed(const Duration(milliseconds: 100)); 
    _updateAuthState(false, null);
    print('[Frontend AuthService] User logged out.');
  }
}