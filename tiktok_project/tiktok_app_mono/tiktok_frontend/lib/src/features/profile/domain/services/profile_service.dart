// tiktok_frontend/lib/src/features/profile/domain/services/profile_service.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:tiktok_frontend/src/features/feed/domain/models/video_post_model.dart';
import 'package:tiktok_frontend/src/core/config/network_config.dart';

class ProfileService {
  // Update user profile
  Future<bool> updateProfile({
    required String userId,
    required String username,
    required String email,
    DateTime? dateOfBirth,
    String? gender,
    List<String>? interests,
  }) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/$userId');
      
      print('[ProfileService] Updating profile for user: $userId');
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'email': email,
          if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
          if (gender != null) 'gender': gender,
          if (interests != null) 'interests': interests,
        }),
      ).timeout(const Duration(seconds: 10));

      print('[ProfileService] Update Profile Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('[ProfileService] Profile updated successfully');
        return true;
      } else {
        final errorMessage = 'Failed to update profile. Status: ${response.statusCode}';
        print('[ProfileService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ProfileService] Error updating profile: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Get liked videos for user
  Future<Map<String, dynamic>> getLikedVideos(String userId, {int page = 1, int limit = 20}) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/$userId/liked-videos?page=$page&limit=$limit');
      
      print('[ProfileService] Getting liked videos for user: $userId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[ProfileService] Get Liked Videos Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Parse videos
        final videosData = responseData['videos'] as List? ?? [];
        final fileBaseUrl = await NetworkConfig.getFileBaseUrl();
        
        List<VideoPost> videos = [];
        for (var videoData in videosData) {
          try {
            final video = VideoPost.fromJson(
              videoData as Map<String, dynamic>,
              fileBaseUrl,
              currentUserId: userId,
            );
            videos.add(video);
          } catch (e) {
            print('[ProfileService] Error parsing liked video: $e');
          }
        }
        
        return {
          'videos': videos,
          'currentPage': responseData['currentPage'] ?? page,
          'totalPages': responseData['totalPages'] ?? 1,
          'hasNextPage': responseData['hasNextPage'] ?? false,
          'totalVideos': responseData['totalVideos'] ?? videos.length,
        };
      } else {
        final errorMessage = 'Failed to get liked videos. Status: ${response.statusCode}';
        print('[ProfileService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ProfileService] Error getting liked videos: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Get saved videos for user
  Future<Map<String, dynamic>> getSavedVideos(String userId, {int page = 1, int limit = 20}) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/$userId/saved-videos?page=$page&limit=$limit');
      
      print('[ProfileService] Getting saved videos for user: $userId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[ProfileService] Get Saved Videos Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Parse videos
        final videosData = responseData['videos'] as List? ?? [];
        final fileBaseUrl = await NetworkConfig.getFileBaseUrl();
        
        List<VideoPost> videos = [];
        for (var videoData in videosData) {
          try {
            final video = VideoPost.fromJson(
              videoData as Map<String, dynamic>,
              fileBaseUrl,
              currentUserId: userId,
            );
            videos.add(video);
          } catch (e) {
            print('[ProfileService] Error parsing saved video: $e');
          }
        }
        
        return {
          'videos': videos,
          'currentPage': responseData['currentPage'] ?? page,
          'totalPages': responseData['totalPages'] ?? 1,
          'hasNextPage': responseData['hasNextPage'] ?? false,
          'totalVideos': responseData['totalVideos'] ?? videos.length,
        };
      } else {
        final errorMessage = 'Failed to get saved videos. Status: ${response.statusCode}';
        print('[ProfileService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ProfileService] Error getting saved videos: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Get user's own videos
  Future<Map<String, dynamic>> getUserVideos(String userId, {int page = 1, int limit = 20}) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/$userId/videos?page=$page&limit=$limit');
      
      print('[ProfileService] Getting user videos for user: $userId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[ProfileService] Get User Videos Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Parse videos
        final videosData = responseData['videos'] as List? ?? [];
        final fileBaseUrl = await NetworkConfig.getFileBaseUrl();
        
        List<VideoPost> videos = [];
        for (var videoData in videosData) {
          try {
            final video = VideoPost.fromJson(
              videoData as Map<String, dynamic>,
              fileBaseUrl,
              currentUserId: userId,
            );
            videos.add(video);
          } catch (e) {
            print('[ProfileService] Error parsing user video: $e');
          }
        }
        
        return {
          'videos': videos,
          'currentPage': responseData['currentPage'] ?? page,
          'totalPages': responseData['totalPages'] ?? 1,
          'hasNextPage': responseData['hasNextPage'] ?? false,
          'totalVideos': responseData['totalVideos'] ?? videos.length,
        };
      } else {
        final errorMessage = 'Failed to get user videos. Status: ${response.statusCode}';
        print('[ProfileService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ProfileService] Error getting user videos: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Test connection
  Future<bool> testConnection() async {
    try {
      final healthUrl = Uri.parse('${await NetworkConfig.getFileBaseUrl()}/health');
      print('[ProfileService] Testing connection to $healthUrl');
      
      final response = await http.get(healthUrl).timeout(const Duration(seconds: 5));
      print('[ProfileService] Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[ProfileService] Connection test failed: $e');
      return false;
    }
  }
}