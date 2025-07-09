// tiktok_frontend/lib/src/features/search/domain/services/search_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:tiktok_frontend/src/features/search/domain/models/search_model.dart';

class SearchService {
  // Search users by query
  static Future<UserSearchResponse> searchUsers({
    required String query,
    int page = 1,
    int limit = 20,
    String? currentUserId,
  }) async {
    try {
      final queryParams = {
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
        if (currentUserId != null) 'currentUserId': currentUserId,
      };

      final baseEndpoint = await NetworkConfig.getBaseUrl('/api/search/users');
      final uri = Uri.parse(baseEndpoint).replace(queryParameters: queryParams);
      
      print('[SearchService] Searching users at: $uri');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserSearchResponse.fromJson(data);
      } else {
        throw Exception('Failed to search users: ${response.statusCode}');
      }
    } catch (e) {
      print('[SearchService] Error searching users: $e');
      throw Exception('Failed to search users: $e');
    }
  }

  // Get trending users
  static Future<TrendingUsersResponse> getTrendingUsers({
    int limit = 10,
    String timeframe = '7d',
    String? currentUserId,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'timeframe': timeframe,
        if (currentUserId != null) 'currentUserId': currentUserId,
      };

      final baseEndpoint = await NetworkConfig.getBaseUrl('/api/search/trending');
      final uri = Uri.parse(baseEndpoint).replace(queryParameters: queryParams);
      
      print('[SearchService] Getting trending users at: $uri');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TrendingUsersResponse.fromJson(data);
      } else {
        throw Exception('Failed to get trending users: ${response.statusCode}');
      }
    } catch (e) {
      print('[SearchService] Error getting trending users: $e');
      throw Exception('Failed to get trending users: $e');
    }
  }

  // Search videos by query
  static Future<VideoSearchResponse> searchVideos({
    required String query,
    int page = 1,
    int limit = 20,
    String? currentUserId,
  }) async {
    try {
      final queryParams = {
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
        if (currentUserId != null) 'currentUserId': currentUserId,
      };

      final baseEndpoint = await NetworkConfig.getBaseUrl('/api/search/videos');
      final uri = Uri.parse(baseEndpoint).replace(queryParameters: queryParams);
      
      print('[SearchService] Searching videos at: $uri');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return VideoSearchResponse.fromJson(data);
      } else {
        throw Exception('Failed to search videos: ${response.statusCode}');
      }
    } catch (e) {
      print('[SearchService] Error searching videos: $e');
      throw Exception('Failed to search videos: $e');
    }
  }

  // Get search suggestions for autocomplete
  static Future<SearchSuggestionsResponse> getSearchSuggestions({
    required String query,
    int limit = 5,
  }) async {
    try {
      final queryParams = {
        'q': query,
        'limit': limit.toString(),
      };

      final baseEndpoint = await NetworkConfig.getBaseUrl('/api/search/suggestions');
      final uri = Uri.parse(baseEndpoint).replace(queryParameters: queryParams);
      
      print('[SearchService] Getting suggestions at: $uri');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SearchSuggestionsResponse.fromJson(data);
      } else {
        throw Exception('Failed to get search suggestions: ${response.statusCode}');
      }
    } catch (e) {
      print('[SearchService] Error getting search suggestions: $e');
      throw Exception('Failed to get search suggestions: $e');
    }
  }

  // Test search functionality
  static Future<bool> testSearchConnection() async {
    try {
      final testEndpoint = await NetworkConfig.getBaseUrl('/api/search/test');
      final uri = Uri.parse(testEndpoint);
      
      print('[SearchService] Testing connection at: $uri');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('[SearchService] Error testing search connection: $e');
      return false;
    }
  }

  // Get search debug info
  static Future<Map<String, dynamic>?> getSearchDebugInfo() async {
    try {
      final debugEndpoint = await NetworkConfig.getBaseUrl('/api/search/debug/info');
      final uri = Uri.parse(debugEndpoint);
      
      print('[SearchService] Getting debug info at: $uri');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print('[SearchService] Error getting search debug info: $e');
      return null;
    }
  }
}