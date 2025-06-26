// tiktok_frontend/lib/src/features/follow/domain/services/follow_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:tiktok_frontend/src/features/follow/domain/models/follow_model.dart';

class FollowService {
  
  // Follow a user
  Future<FollowResult> followUser(String currentUserId, String targetUserId) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/follow');
      final url = Uri.parse('$baseUrl/follow/$currentUserId/$targetUserId');
      
      print('[FollowService] Following user: $currentUserId -> $targetUserId');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[FollowService] Follow Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return FollowResult.fromJson(responseData);
      } else if (response.statusCode == 409) {
        throw Exception('Đã theo dõi người dùng này rồi');
      } else if (response.statusCode == 404) {
        throw Exception('Không tìm thấy người dùng');
      } else {
        final errorMessage = 'Failed to follow user. Status: ${response.statusCode}';
        print('[FollowService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[FollowService] Error following user: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Unfollow a user
  Future<FollowResult> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/follow');
      final url = Uri.parse('$baseUrl/unfollow/$currentUserId/$targetUserId');
      
      print('[FollowService] Unfollowing user: $currentUserId -> $targetUserId');
      
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[FollowService] Unfollow Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return FollowResult.fromJson(responseData);
      } else if (response.statusCode == 409) {
        throw Exception('Chưa theo dõi người dùng này');
      } else if (response.statusCode == 404) {
        throw Exception('Không tìm thấy người dùng');
      } else {
        final errorMessage = 'Failed to unfollow user. Status: ${response.statusCode}';
        print('[FollowService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[FollowService] Error unfollowing user: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Get followers list
  Future<FollowListResponse> getFollowers(String userId, {int page = 1, int limit = 20}) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/follow');
      final url = Uri.parse('$baseUrl/followers/$userId?page=$page&limit=$limit');
      
      print('[FollowService] Getting followers for user: $userId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[FollowService] Get Followers Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return FollowListResponse.fromJson(responseData, isFollowersList: true);
      } else if (response.statusCode == 404) {
        throw Exception('Không tìm thấy người dùng');
      } else {
        final errorMessage = 'Failed to get followers. Status: ${response.statusCode}';
        print('[FollowService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[FollowService] Error getting followers: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Get following list
  Future<FollowListResponse> getFollowing(String userId, {int page = 1, int limit = 20}) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/follow');
      final url = Uri.parse('$baseUrl/following/$userId?page=$page&limit=$limit');
      
      print('[FollowService] Getting following for user: $userId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[FollowService] Get Following Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return FollowListResponse.fromJson(responseData, isFollowersList: false);
      } else if (response.statusCode == 404) {
        throw Exception('Không tìm thấy người dùng');
      } else {
        final errorMessage = 'Failed to get following. Status: ${response.statusCode}';
        print('[FollowService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[FollowService] Error getting following: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Check follow status between two users
  Future<FollowStatus> checkFollowStatus(String currentUserId, String targetUserId) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/follow');
      final url = Uri.parse('$baseUrl/status/$currentUserId/$targetUserId');
      
      print('[FollowService] Checking follow status: $currentUserId -> $targetUserId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[FollowService] Check Status Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return FollowStatus.fromJson(responseData);
      } else if (response.statusCode == 404) {
        throw Exception('Không tìm thấy người dùng');
      } else {
        final errorMessage = 'Failed to check follow status. Status: ${response.statusCode}';
        print('[FollowService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[FollowService] Error checking follow status: $e');
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
      final baseUrl = await NetworkConfig.getBaseUrl('/api/follow');
      final testUrl = Uri.parse('$baseUrl/test-follow-api');
      
      print('[FollowService] Testing connection to $testUrl');
      
      final response = await http.get(testUrl).timeout(const Duration(seconds: 5));
      print('[FollowService] Test response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[FollowService] Connection test failed: $e');
      return false;
    }
  }
}