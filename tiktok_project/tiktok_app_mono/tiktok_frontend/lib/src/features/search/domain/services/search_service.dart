// tiktok_frontend/lib/src/features/search/domain/services/search_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tiktok_frontend/src/core/config/api_config.dart';
import 'package:tiktok_frontend/src/features/search/domain/models/search_model.dart';

class SearchService {
  static final String _baseUrl = '${ApiConfig.baseUrl}/search';

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

      final uri = Uri.parse('$_baseUrl/users').replace(queryParameters: queryParams);
      final response = await http.get(uri);

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

      final uri = Uri.parse('$_baseUrl/trending').replace(queryParameters: queryParams);
      final response = await http.get(uri);

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

      final uri = Uri.parse('$_baseUrl/videos').replace(queryParameters: queryParams);
      final response = await http.get(uri);

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

      final uri = Uri.parse('$_baseUrl/suggestions').replace(queryParameters: queryParams);
      final response = await http.get(uri);

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
      final uri = Uri.parse('$_baseUrl/test');
      final response = await http.get(uri);
      return response.statusCode == 200;
    } catch (e) {
      print('[SearchService] Error testing search connection: $e');
      return false;
    }
  }

  // Get search debug info
  static Future<Map<String, dynamic>?> getSearchDebugInfo() async {
    try {
      final uri = Uri.parse('$_baseUrl/debug/info');
      final response = await http.get(uri);

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