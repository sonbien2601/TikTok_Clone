// tiktok_frontend/lib/src/features/feed/domain/services/video_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:tiktok_frontend/src/features/feed/domain/models/video_post_model.dart';

// Response models
class VideoFeedResponse {
  final List<VideoPost> videos;
  final VideoFeedPagination pagination;

  VideoFeedResponse({
    required this.videos,
    required this.pagination,
  });

  factory VideoFeedResponse.fromJson(dynamic json, String fileBaseUrl, {String? currentUserId}) {
    // Handle case where API returns a List directly instead of an object with videos array
    List<dynamic> videosData;
    Map<String, dynamic> paginationData = {};

    if (json is List) {
      // API returns array directly: [video1, video2, ...]
      videosData = json;
      // Create default pagination when API returns array directly
      paginationData = {
        'currentPage': 1,
        'totalPages': 1,
        'totalVideos': videosData.length,
        'limit': videosData.length,
        'hasNextPage': false,
        'hasPrevPage': false,
      };
    } else if (json is Map<String, dynamic>) {
      // API returns object: {videos: [...], pagination: {...}}
      videosData = json['videos'] as List? ?? [];
      paginationData = json['pagination'] as Map<String, dynamic>? ?? {};
    } else {
      // Fallback
      videosData = [];
    }

    final videos = videosData
        .map((videoData) => VideoPost.fromJson(
              videoData as Map<String, dynamic>,
              fileBaseUrl,
              currentUserId: currentUserId,
            ))
        .toList();

    return VideoFeedResponse(
      videos: videos,
      pagination: VideoFeedPagination.fromJson(paginationData),
    );
  }
}

class VideoFeedPagination {
  final int currentPage;
  final int totalPages;
  final int totalVideos;
  final int limit;
  final bool hasNextPage;
  final bool hasPrevPage;

  VideoFeedPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalVideos,
    required this.limit,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory VideoFeedPagination.fromJson(Map<String, dynamic> json) {
    return VideoFeedPagination(
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 1,
      totalVideos: json['totalVideos'] as int? ?? 0,
      limit: json['limit'] as int? ?? 10,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
      hasPrevPage: json['hasPrevPage'] as bool? ?? false,
    );
  }
}

class VideoLikeResponse {
  final bool isLiked;
  final int likesCount;
  final String message;

  VideoLikeResponse({
    required this.isLiked,
    required this.likesCount,
    required this.message,
  });

  factory VideoLikeResponse.fromJson(Map<String, dynamic> json) {
    return VideoLikeResponse(
      isLiked: json['isLikedByCurrentUser'] as bool? ?? false,
      likesCount: json['likesCount'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}

class VideoSaveResponse {
  final bool isSaved;
  final String message;

  VideoSaveResponse({
    required this.isSaved,
    required this.message,
  });

  factory VideoSaveResponse.fromJson(Map<String, dynamic> json) {
  return VideoSaveResponse(
    // Thử nhiều field có thể có
    isSaved: json['isSaved'] as bool? ?? 
             json['isSavedByCurrentUser'] as bool? ?? 
             json['saved'] as bool? ?? 
             false,
    message: json['message'] as String? ?? '',
  );
}
}

class VideoService {
  
  // Get video feed with pagination
  Future<VideoFeedResponse> getVideoFeed({
    int page = 1,
    int limit = 10,
    String? currentUserId,
  }) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/videos');
      final url = Uri.parse('$baseUrl/feed?page=$page&limit=$limit');
      
      debugPrint('[VideoService] Getting video feed: page=$page, limit=$limit');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('[VideoService] Get Feed Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final fileBaseUrl = await NetworkConfig.getFileBaseUrl();
        
        // Debug log the response structure
        debugPrint('[VideoService] Response type: ${responseData.runtimeType}');
        if (responseData is Map) {
          debugPrint('[VideoService] Response keys: ${responseData.keys}');
        } else if (responseData is List) {
          debugPrint('[VideoService] Response is List with ${responseData.length} items');
        }
        
        return VideoFeedResponse.fromJson(
          responseData,
          fileBaseUrl,
          currentUserId: currentUserId,
        );
      } else {
        final errorMessage = 'Failed to get video feed. Status: ${response.statusCode}';
        debugPrint('[VideoService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[VideoService] Error getting video feed: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Toggle like video
  // Toggle like video
Future<VideoLikeResponse> toggleLikeVideo(String videoId, String userId) async {
  try {
    final baseUrl = await NetworkConfig.getBaseUrl('/api/videos');
    final url = Uri.parse('$baseUrl/$videoId/like');
    
    debugPrint('[VideoService] Toggling like for video: $videoId by user: $userId');
    
    final requestBody = {
      'userId': userId,
    };
    
    // DEBUG: In ra request details
    print('=== SENDING TO BACKEND ===');
    print('URL: $url');
    print('Method: POST');
    print('Body: ${jsonEncode(requestBody)}');
    print('==========================');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 10));

    // DEBUG: In ra response details
    print('=== BACKEND RESPONSE ===');
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
    print('========================');

    debugPrint('[VideoService] Toggle Like Response Status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      
      // DEBUG: In ra parsed data
      print('=== PARSED DATA ===');
      print('isLiked: ${responseData['isLiked']}');
      print('likesCount: ${responseData['likesCount']}');
      print('message: ${responseData['message']}');
      print('===================');
      
      final result = VideoLikeResponse.fromJson(responseData);
      
      return result;
    } else {
      final errorMessage = 'Failed to toggle like. Status: ${response.statusCode}';
      debugPrint('[VideoService] $errorMessage, Body: ${response.body}');
      throw Exception(errorMessage);
    }
  } catch (e) {
    debugPrint('[VideoService] Error toggling like: $e');
    if (e.toString().contains('Connection refused') || 
        e.toString().contains('Failed host lookup')) {
      throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
    }
    rethrow;
  }
}

  // Toggle save video
  Future<VideoSaveResponse> toggleSaveVideo(String videoId, String userId) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/videos');
      final url = Uri.parse('$baseUrl/$videoId/save');
      
      debugPrint('[VideoService] Toggling save for video: $videoId by user: $userId');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[VideoService] Toggle Save Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return VideoSaveResponse.fromJson(responseData);
      } else {
        final errorMessage = 'Failed to toggle save. Status: ${response.statusCode}';
        debugPrint('[VideoService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[VideoService] Error toggling save: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Get video by ID
  Future<VideoPost?> getVideoById(String videoId, {String? currentUserId}) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/videos');
      final url = Uri.parse('$baseUrl/$videoId');
      
      debugPrint('[VideoService] Getting video by ID: $videoId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('[VideoService] Get Video Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final fileBaseUrl = await NetworkConfig.getFileBaseUrl();
        
        // Handle different response structures
        Map<String, dynamic> videoData;
        if (responseData is Map<String, dynamic> && responseData.containsKey('video')) {
          videoData = responseData['video'] as Map<String, dynamic>;
        } else if (responseData is Map<String, dynamic>) {
          videoData = responseData;
        } else {
          throw Exception('Invalid video data structure');
        }
        
        return VideoPost.fromJson(
          videoData,
          fileBaseUrl,
          currentUserId: currentUserId,
        );
      } else if (response.statusCode == 404) {
        debugPrint('[VideoService] Video not found: $videoId');
        return null;
      } else {
        final errorMessage = 'Failed to get video. Status: ${response.statusCode}';
        debugPrint('[VideoService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[VideoService] Error getting video: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Search videos
  Future<VideoFeedResponse> searchVideos({
    required String query,
    int page = 1,
    int limit = 10,
    String? currentUserId,
  }) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/videos');
      final url = Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}&page=$page&limit=$limit');
      
      debugPrint('[VideoService] Searching videos: query="$query", page=$page');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('[VideoService] Search Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final fileBaseUrl = await NetworkConfig.getFileBaseUrl();
        
        return VideoFeedResponse.fromJson(
          responseData,
          fileBaseUrl,
          currentUserId: currentUserId,
        );
      } else {
        final errorMessage = 'Failed to search videos. Status: ${response.statusCode}';
        debugPrint('[VideoService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[VideoService] Error searching videos: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      rethrow;
    }
  }

  // Get trending videos
  Future<VideoFeedResponse> getTrendingVideos({
    int page = 1,
    int limit = 10,
    String? currentUserId,
  }) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/videos');
      final url = Uri.parse('$baseUrl/trending?page=$page&limit=$limit');
      
      debugPrint('[VideoService] Getting trending videos: page=$page');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('[VideoService] Trending Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final fileBaseUrl = await NetworkConfig.getFileBaseUrl();
        
        return VideoFeedResponse.fromJson(
          responseData,
          fileBaseUrl,
          currentUserId: currentUserId,
        );
      } else {
        final errorMessage = 'Failed to get trending videos. Status: ${response.statusCode}';
        debugPrint('[VideoService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[VideoService] Error getting trending videos: $e');
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
      debugPrint('[VideoService] Testing connection to $healthUrl');
      
      final response = await http.get(healthUrl).timeout(const Duration(seconds: 5));
      debugPrint('[VideoService] Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[VideoService] Connection test failed: $e');
      return false;
    }
  }
}