// tiktok_frontend/lib/src/features/feed/domain/services/comment_service.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/comment_model.dart';

class CommentService {
  // CẤU HÌNH IP CHO ANDROID THẬT
  static const String _backendHost = 'localhost';
  static const String _backendPort = '8080';
  static const String _realDeviceIP = '10.21.12.255'; // IP thực của máy tính
  static const String _apiPath = '/api/comments';

  String get _effectiveBackendHost {
    if (kIsWeb) {
      return _backendHost;
    } else {
      try {
        if (Platform.isAndroid) {
          // KIỂM TRA XEM CÓ PHẢI ANDROID EMULATOR KHÔNG
          return _isAndroidEmulator() ? '10.0.2.2' : _realDeviceIP;
        } else if (Platform.isIOS) {
          return _realDeviceIP;
        }
      } catch (e) { 
        print("[CommentService] Error checking platform for host: $e");
      }
      return _backendHost;
    }
  }

  // Hàm kiểm tra xem có phải Android emulator không
  bool _isAndroidEmulator() {
    try {
      return Platform.environment.containsKey('ANDROID_EMULATOR') ||
             Platform.environment['ANDROID_EMULATOR'] == 'true';
    } catch (e) {
      print("[CommentService] Cannot determine if emulator, assuming real device: $e");
      return false;
    }
  }

  String get _apiBaseUrl {
    final host = _effectiveBackendHost;
    return 'http://$host:$_backendPort$_apiPath';
  }

  // Get comments for a video with pagination
  Future<CommentPaginationResponse> getVideoComments(String videoId, {int page = 1, int limit = 20}) async {
    final url = Uri.parse('$_apiBaseUrl/video/$videoId?page=$page&limit=$limit');
    print('[CommentService] Fetching comments from $url');
    print('[CommentService] Platform info: ${kIsWeb ? "Web" : Platform.operatingSystem}, isEmulator: ${!kIsWeb ? _isAndroidEmulator() : "N/A"}');
    
    try {
      final response = await http.get(
        url, 
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[CommentService] Get Comments Response Status: ${response.statusCode}');
      print('[CommentService] Raw Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        print('[CommentService] Response body type: ${responseBody.runtimeType}');
        print('[CommentService] Response body length: ${responseBody.length}');
        
        if (responseBody.isEmpty) {
          throw Exception('Empty response from server');
        }

        dynamic jsonData;
        try {
          jsonData = jsonDecode(responseBody);
          print('[CommentService] Parsed JSON type: ${jsonData.runtimeType}');
        } catch (e) {
          print('[CommentService] JSON decode error: $e');
          throw Exception('Invalid JSON response: $e');
        }

        // Handle both old and new formats
        if (jsonData is List) {
          // OLD FORMAT: Backend returns array directly
          print('[CommentService] Detected old format (array), converting to new format');
          
          List<CommentModel> commentsList = [];
          for (var item in jsonData) {
            if (item is Map<String, dynamic>) {
              try {
                // Add missing fields for old format
                if (!item.containsKey('likesCount')) item['likesCount'] = 0;
                if (!item.containsKey('likes')) item['likes'] = <String>[];
                if (!item.containsKey('repliesCount')) item['repliesCount'] = 0;
                if (!item.containsKey('updatedAt')) item['updatedAt'] = item['createdAt'];
                
                final comment = CommentModel.fromJson(item);
                commentsList.add(comment);
              } catch (e) {
                print('[CommentService] Error parsing comment item: $e');
              }
            }
          }
          
          final pagination = CommentPagination(
            currentPage: page,
            totalPages: 1,
            totalComments: commentsList.length,
            limit: limit,
            hasNextPage: false,
            hasPrevPage: false,
          );
          
          return CommentPaginationResponse(
            comments: commentsList,
            pagination: pagination,
          );
          
        } else if (jsonData is Map<String, dynamic>) {
          // NEW FORMAT: Backend returns object with comments and pagination
          print('[CommentService] Detected new format (object)');
          return CommentPaginationResponse.fromJson(jsonData as Map<String, dynamic>);
        } else {
          print('[CommentService] Unknown response format: ${jsonData.runtimeType}');
          throw Exception('Unknown response format');
        }
      } else {
        final errorMessage = 'Failed to load comments. Status: ${response.statusCode}';
        print('[CommentService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[CommentService] Error fetching comments: $e');
      
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        print('[CommentService] ❌ Cannot connect to backend server at $_apiBaseUrl');
        print('[CommentService] 💡 Current target IP: $_effectiveBackendHost');
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      
      rethrow;
    }
  }

  // Add a comment to a video
  Future<CommentModel> addComment(String videoId, String userId, String text) async {
    final url = Uri.parse('$_apiBaseUrl/video/$videoId');
    print('[CommentService] Adding comment to video $videoId by user $userId');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'text': text,
        }),
      ).timeout(const Duration(seconds: 10));

      print('[CommentService] Add Comment Response Status: ${response.statusCode}');
      print('[CommentService] Add Comment Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        return _parseCommentResponse(response.body, 'add comment');
      } else {
        throw _parseErrorResponse(response, 'Failed to add comment');
      }
    } catch (e) {
      print('[CommentService] Error adding comment: $e');
      _handleConnectionError(e);
      rethrow;
    }
  }

  // Reply to a comment - FIXED URL
  Future<CommentModel> replyToComment(String commentId, String userId, String text) async {
    final url = Uri.parse('$_apiBaseUrl/reply/$commentId'); // CHANGED FROM /$commentId/reply
    print('[CommentService] Replying to comment $commentId by user $userId');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'text': text,
        }),
      ).timeout(const Duration(seconds: 10));

      print('[CommentService] Reply Response Status: ${response.statusCode}');
      print('[CommentService] Reply Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        return _parseCommentResponse(response.body, 'reply to comment');
      } else {
        throw _parseErrorResponse(response, 'Failed to reply to comment');
      }
    } catch (e) {
      print('[CommentService] Error replying to comment: $e');
      _handleConnectionError(e);
      rethrow;
    }
  }

  // Toggle like on comment - FIXED URL
  Future<CommentModel> toggleLikeComment(String commentId, String userId) async {
    final url = Uri.parse('$_apiBaseUrl/like/$commentId'); // CHANGED FROM /$commentId/like
    print('[CommentService] Toggling like on comment $commentId by user $userId');
    
    try {
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

      print('[CommentService] Toggle Like Response Status: ${response.statusCode}');
      print('[CommentService] Toggle Like Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        return _parseCommentResponse(response.body, 'toggle like comment');
      } else {
        throw _parseErrorResponse(response, 'Failed to toggle like on comment');
      }
    } catch (e) {
      print('[CommentService] Error toggling like on comment: $e');
      _handleConnectionError(e);
      rethrow;
    }
  }

  // Get replies for a comment - FIXED URL
  Future<CommentRepliesResponse> getCommentReplies(String commentId, {int page = 1, int limit = 10}) async {
    final url = Uri.parse('$_apiBaseUrl/replies/$commentId?page=$page&limit=$limit'); // CHANGED FROM /$commentId/replies
    print('[CommentService] Fetching replies for comment $commentId from $url');
    
    try {
      final response = await http.get(
        url, 
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[CommentService] Get Replies Response Status: ${response.statusCode}');
      print('[CommentService] Get Replies Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        
        if (responseBody.isEmpty) {
          throw Exception('Empty response from server');
        }

        dynamic jsonData;
        try {
          jsonData = jsonDecode(responseBody);
        } catch (e) {
          throw Exception('Invalid JSON response: $e');
        }

        if (jsonData is! Map<String, dynamic>) {
          throw Exception('Response is not a JSON object');
        }

        return CommentRepliesResponse.fromJson(jsonData);
      } else {
        throw _parseErrorResponse(response, 'Failed to load replies');
      }
    } catch (e) {
      print('[CommentService] Error fetching replies: $e');
      _handleConnectionError(e);
      rethrow;
    }
  }

  // Edit a comment
  Future<CommentModel> editComment(String commentId, String userId, String newText) async {
    final url = Uri.parse('$_apiBaseUrl/edit/$commentId');
    print('[CommentService] Editing comment $commentId by user $userId at $url');
    
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'text': newText,
        }),
      ).timeout(const Duration(seconds: 10));

      print('[CommentService] Edit Comment Response Status: ${response.statusCode}');
      print('[CommentService] Edit Comment Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        return _parseCommentResponse(response.body, 'edit comment');
      } else {
        throw _parseErrorResponse(response, 'Failed to edit comment');
      }
    } catch (e) {
      print('[CommentService] Error editing comment: $e');
      _handleConnectionError(e);
      rethrow;
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId, String userId) async {
    final url = Uri.parse('$_apiBaseUrl/delete/$commentId');
    print('[CommentService] Deleting comment $commentId by user $userId at $url');
    
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
        }),
      ).timeout(const Duration(seconds: 10));

      print('[CommentService] Delete Response Status: ${response.statusCode}');
      print('[CommentService] Delete Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('[CommentService] Comment deleted successfully');
        return;
      } else {
        throw _parseErrorResponse(response, 'Failed to delete comment');
      }
    } catch (e) {
      print('[CommentService] Error deleting comment: $e');
      _handleConnectionError(e);
      rethrow;
    }
  }

  // Helper method to parse comment response
  CommentModel _parseCommentResponse(String responseBody, String operation) {
    dynamic responseData;
    try {
      responseData = jsonDecode(responseBody);
    } catch (e) {
      throw Exception('Invalid JSON response for $operation: $e');
    }

    if (responseData is! Map<String, dynamic>) {
      throw Exception('Response is not a JSON object for $operation');
    }

    final Map<String, dynamic> responseMap = responseData as Map<String, dynamic>;
    
    Map<String, dynamic> commentData;
    
    // Handle both formats
    if (responseMap.containsKey('comment')) {
      // NEW FORMAT: {comment: {...}}
      final rawCommentData = responseMap['comment'];
      if (rawCommentData is! Map<String, dynamic>) {
        throw Exception('Comment data is not a JSON object for $operation');
      }
      commentData = rawCommentData;
    } else if (responseMap.containsKey('_id')) {
      // OLD FORMAT: Comment object directly
      commentData = responseMap;
    } else {
      throw Exception('Invalid response format for $operation - missing comment data');
    }

    // Ensure required fields exist
    final Map<String, dynamic> safeCommentData = Map<String, dynamic>.from(commentData);
    if (!safeCommentData.containsKey('likesCount')) safeCommentData['likesCount'] = 0;
    if (!safeCommentData.containsKey('likes')) safeCommentData['likes'] = <String>[];
    if (!safeCommentData.containsKey('repliesCount')) safeCommentData['repliesCount'] = 0;
    if (!safeCommentData.containsKey('updatedAt')) safeCommentData['updatedAt'] = safeCommentData['createdAt'];

    return CommentModel.fromJson(safeCommentData);
  }

  // Helper method to parse error response
  Exception _parseErrorResponse(http.Response response, String defaultMessage) {
    String errorMessage = '$defaultMessage. Status: ${response.statusCode}';
    try { 
      final errorData = jsonDecode(response.body); 
      errorMessage = errorData['error'] ?? errorMessage; 
    } catch(_) {}
    
    print('[CommentService] Operation failed: $errorMessage');
    return Exception(errorMessage);
  }

  // Helper method to handle connection errors
  void _handleConnectionError(dynamic error) {
    if (error.toString().contains('Connection refused') || 
        error.toString().contains('Failed host lookup')) {
      print('[CommentService] ❌ Cannot connect to backend server at $_apiBaseUrl');
      print('[CommentService] 💡 Current target IP: $_effectiveBackendHost');
      throw Exception('Không thể kết nối đến server');
    }
  }

  // Test connection
  Future<bool> testConnection() async {
    try {
      final healthUrl = Uri.parse('http://$_effectiveBackendHost:$_backendPort/health');
      print('[CommentService] Testing connection to $healthUrl');
      
      final response = await http.get(healthUrl).timeout(const Duration(seconds: 5));
      print('[CommentService] Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[CommentService] Connection test failed: $e');
      return false;
    }
  }
}