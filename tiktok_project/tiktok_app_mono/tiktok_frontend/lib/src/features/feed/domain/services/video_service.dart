// tiktok_frontend/lib/src/features/feed/domain/services/video_service.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:tiktok_frontend/src/features/feed/domain/models/video_post_model.dart';

class VideoService {
  // Cố định backend host và port
  static const String _backendHost = 'localhost';
  static const String _backendPort = '8080';
  static const String _apiPath = '/api/videos';

  String get _effectiveBackendHost {
    if (kIsWeb) {
      // Web: luôn dùng localhost
      return _backendHost;
    } else {
      try {
        if (Platform.isAndroid) {
          // Android emulator: 10.0.2.2 maps to host localhost
          return '10.0.2.2';
        } else if (Platform.isIOS) {
          // iOS simulator: có thể dùng localhost
          return _backendHost;
        }
      } catch (e) { 
        print("[VideoService] Error checking platform for host: $e");
      }
      // Fallback cho desktop hoặc platform khác
      return _backendHost;
    }
  }

  String get _apiBaseUrl {
    final host = _effectiveBackendHost;
    return 'http://$host:$_backendPort$_apiPath';
  }

  String get _backendBaseFileUrl {
    final host = _effectiveBackendHost;
    return 'http://$host:$_backendPort';
  }

  // Getter để debug URL hiện tại
  String get currentApiBaseUrl => _apiBaseUrl;
  String get currentFileBaseUrl => _backendBaseFileUrl;

  Future<List<VideoPost>> getFeedVideos({int page = 1, int limit = 10, String? currentUserId}) async {
    final url = Uri.parse('$_apiBaseUrl/feed?page=$page&limit=$limit');
    print('[VideoService] Fetching feed videos from $url for user: $currentUserId');
    print('[VideoService] Using API base URL: $_apiBaseUrl');
    
    try {
      final response = await http.get(
        url, 
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[VideoService] Feed Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        if (jsonData.isEmpty) {
          print('[VideoService] Feed is empty from API.');
          return [];
        }
        
        return jsonData.map((item) {
          try {
            return VideoPost.fromJson(
              item as Map<String, dynamic>, 
              _backendBaseFileUrl, 
              currentUserId: currentUserId
            );
          } catch(e, s) { 
            print('[VideoService] Error parsing video item: $item. Error: $e\nStackTrace: $s');
            return null; 
          }
        }).whereType<VideoPost>().toList(); 
      } else {
        final errorMessage = 'Failed to load videos. Status: ${response.statusCode}';
        print('[VideoService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[VideoService] Error fetching videos: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        print('[VideoService] ❌ Cannot connect to backend server at $_apiBaseUrl');
        print('[VideoService] 💡 Please ensure backend server is running on port $_backendPort');
      }
      throw Exception('Could not connect to server: $e');
    }
  }

  Future<Map<String, dynamic>> toggleLikeVideo(String videoId, String userId) async {
    final url = Uri.parse('$_apiBaseUrl/$videoId/like');
    print('[VideoService] Toggling like for videoId: $videoId by userId: $userId at $url');
    print('[VideoService] Using API base URL: $_apiBaseUrl');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({'userId': userId}),
      ).timeout(const Duration(seconds: 10));

      print('[VideoService] ToggleLike Response Status: ${response.statusCode}');
      print('[VideoService] ToggleLike Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        print('[VideoService] Like toggle successful: $responseData');
        return responseData;
      } else if (response.statusCode == 404) {
        throw Exception('Like endpoint not found. Please check your backend API routes.');
      } else {
        String errorMessage = 'Failed to toggle like. Status: ${response.statusCode}';
        try { 
          final errorData = jsonDecode(response.body); 
          errorMessage = errorData['error'] ?? errorMessage; 
        } catch(_) {}
        
        print('[VideoService] Like toggle failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[VideoService] Error toggling like: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        print('[VideoService] ❌ Cannot connect to backend server at $_apiBaseUrl');
        print('[VideoService] 💡 Please ensure backend server is running on port $_backendPort');
      }
      if (e.toString().contains('404')) {
        throw Exception('Like feature not implemented on server');
      }
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> toggleSaveVideo(String videoId, String userId) async {
    final url = Uri.parse('$_apiBaseUrl/$videoId/save');
    print('[VideoService] Toggling save for videoId: $videoId by userId: $userId at $url');
    print('[VideoService] Using API base URL: $_apiBaseUrl');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({'userId': userId}),
      ).timeout(const Duration(seconds: 10));

      print('[VideoService] ToggleSave Response Status: ${response.statusCode}');
      print('[VideoService] ToggleSave Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        print('[VideoService] Save toggle successful: $responseData');
        return responseData;
      } else if (response.statusCode == 404) {
        throw Exception('Save endpoint not found. Please check your backend API routes.');
      } else {
        String errorMessage = 'Failed to toggle save. Status: ${response.statusCode}';
        try { 
          final errorData = jsonDecode(response.body); 
          errorMessage = errorData['error'] ?? errorMessage; 
        } catch(_) {}
        
        print('[VideoService] Save toggle failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[VideoService] Error toggling save: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        print('[VideoService] ❌ Cannot connect to backend server at $_apiBaseUrl');
        print('[VideoService] 💡 Please ensure backend server is running on port $_backendPort');
      }
      if (e.toString().contains('404')) {
        throw Exception('Save feature not implemented on server');
      }
      throw Exception('Network error: $e');
    }
  }

  // Method để test connection
  Future<bool> testConnection() async {
    try {
      final healthUrl = Uri.parse('${_backendBaseFileUrl}/health');
      print('[VideoService] Testing connection to $healthUrl');
      
      final response = await http.get(healthUrl).timeout(const Duration(seconds: 5));
      print('[VideoService] Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[VideoService] Connection test failed: $e');
      return false;
    }
  }

  // TODO: Add comment-related methods
  // Future<List<Comment>> getVideoComments(String videoId) async { ... }
  // Future<Comment> addComment(String videoId, String userId, String text) async { ... }
}