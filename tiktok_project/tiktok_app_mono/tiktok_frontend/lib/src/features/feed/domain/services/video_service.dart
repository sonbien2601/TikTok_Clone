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

  // Get single video by ID
  Future<VideoPost?> getVideoById(String videoId, {String? currentUserId}) async {
    print('[VideoService] === FETCHING SINGLE VIDEO ===');
    print('[VideoService] Video ID: $videoId');
    print('[VideoService] Current User ID: $currentUserId');
    
    try {
      // Since we don't have a specific endpoint for single video,
      // we'll get from feed and filter (this is not optimal, but works for now)
      final videos = await getFeedVideos(currentUserId: currentUserId, limit: 50);
      final video = videos.where((v) => v.id == videoId).firstOrNull;
      
      if (video != null) {
        print('[VideoService] ✅ Found video: "${video.user.username}" - "${video.description}"');
      } else {
        print('[VideoService] ❌ Video not found in feed');
      }
      
      return video;
    } catch (e) {
      print('[VideoService] Error fetching single video: $e');
      rethrow;
    }
  }

  Future<List<VideoPost>> getFeedVideos({int page = 1, int limit = 10, String? currentUserId}) async {
    final url = Uri.parse('$_apiBaseUrl/feed?page=$page&limit=$limit');
    print('[VideoService] === FETCHING FEED VIDEOS ===');
    print('[VideoService] URL: $url');
    print('[VideoService] Current User ID: $currentUserId');
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
        print('[VideoService] Raw Response Body: ${response.body}');
        
        final List<dynamic> jsonData = jsonDecode(response.body);
        if (jsonData.isEmpty) {
          print('[VideoService] Feed is empty from API.');
          return [];
        }
        
        print('[VideoService] Processing ${jsonData.length} videos from API');
        
        final List<VideoPost> videos = [];
        for (int i = 0; i < jsonData.length; i++) {
          try {
            final item = jsonData[i] as Map<String, dynamic>;
            print('[VideoService] === Processing video $i ===');
            print('[VideoService] Video keys: ${item.keys.toList()}');
            
            // Log user-related fields specifically
            if (item.containsKey('user')) {
              print('[VideoService] Video $i has user field: ${item['user']}');
            } else {
              print('[VideoService] Video $i missing user field');
              print('[VideoService] Available fields: username="${item['username']}", userAvatarUrl="${item['userAvatarUrl']}"');
            }
            
            final video = VideoPost.fromJson(
              item, 
              _backendBaseFileUrl, 
              currentUserId: currentUserId
            );
            
            print('[VideoService] ✅ Successfully parsed video $i: "${video.user.username}"');
            videos.add(video);
          } catch(e, s) { 
            print('[VideoService] ❌ Error parsing video item $i: $e');
            print('[VideoService] Stack trace: $s');
            print('[VideoService] Problematic item: ${jsonData[i]}');
            // Continue với video khác thay vì fail toàn bộ
          }
        }
        
        print('[VideoService] === FEED PARSING SUMMARY ===');
        print('[VideoService] Successfully parsed ${videos.length} out of ${jsonData.length} videos');
        for (int i = 0; i < videos.length; i++) {
          print('[VideoService] Video $i: "${videos[i].user.username}" - "${videos[i].description}"');
        }
        print('[VideoService] ============================');
        
        return videos;
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
}

// Extension for null-safe firstOrNull
extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}