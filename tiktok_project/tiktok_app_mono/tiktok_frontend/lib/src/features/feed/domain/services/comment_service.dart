// tiktok_frontend/lib/src/features/feed/domain/services/comment_service.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/comment_model.dart';

class CommentService {
  // Cố định backend host và port
  static const String _backendHost = 'localhost';
  static const String _backendPort = '8080';
  static const String _apiPath = '/api/comments';

  String get _effectiveBackendHost {
    if (kIsWeb) {
      return _backendHost;
    } else {
      try {
        if (Platform.isAndroid) {
          return '10.0.2.2';
        } else if (Platform.isIOS) {
          return _backendHost;
        }
      } catch (e) { 
        print("[CommentService] Error checking platform for host: $e");
      }
      return _backendHost;
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
        // Kiểm tra response body trước khi parse
        final String responseBody = response.body;
        print('[CommentService] Response body type: ${responseBody.runtimeType}');
        print('[CommentService] Response body length: ${responseBody.length}');
        
        if (responseBody.isEmpty) {
          throw Exception('Empty response from server');
        }

        // Parse JSON với error handling chi tiết
        dynamic jsonData;
        try {
          jsonData = jsonDecode(responseBody);
          print('[CommentService] Parsed JSON type: ${jsonData.runtimeType}');
        } catch (e) {
          print('[CommentService] JSON decode error: $e');
          throw Exception('Invalid JSON response: $e');
        }

        // XỬ LÝ CẢ 2 FORMAT: Array trực tiếp hoặc Object
        if (jsonData is List) {
          // OLD FORMAT: Backend trả về array trực tiếp
          print('[CommentService] Detected old format (array), converting to new format');
          
          List<CommentModel> commentsList = [];
          for (var item in jsonData) {
            if (item is Map<String, dynamic>) {
              try {
                // Thêm các field bị thiếu cho old format
                if (!item.containsKey('likesCount')) item['likesCount'] = 0;
                if (!item.containsKey('likes')) item['likes'] = <String>[];
                if (!item.containsKey('repliesCount')) item['repliesCount'] = 0;
                if (!item.containsKey('updatedAt')) item['updatedAt'] = item['createdAt'];
                
                final comment = CommentModel.fromJson(item);
                commentsList.add(comment);
              } catch (e) {
                print('[CommentService] Error parsing comment item: $e');
                // Continue với các comment khác
              }
            }
          }
          
          // Tạo pagination mặc định cho old format
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
          // NEW FORMAT: Backend trả về object với comments và pagination
          print('[CommentService] Detected new format (object)');
          
          final Map<String, dynamic> jsonMap = jsonData as Map<String, dynamic>;
          
          // Kiểm tra các field bắt buộc
          if (!jsonMap.containsKey('comments')) {
            print('[CommentService] Missing "comments" field in response');
            throw Exception('Missing comments field in response');
          }

          // Parse response
          return CommentPaginationResponse.fromJson(jsonMap);
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
      print('[CommentService] Error type: ${e.runtimeType}');
      
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        print('[CommentService] ❌ Cannot connect to backend server at $_apiBaseUrl');
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
        // Parse response với error handling
        dynamic responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          print('[CommentService] JSON decode error for add comment: $e');
          throw Exception('Invalid JSON response: $e');
        }

        if (responseData is! Map<String, dynamic>) {
          throw Exception('Response is not a JSON object');
        }

        final Map<String, dynamic> responseMap = responseData as Map<String, dynamic>;
        
        Map<String, dynamic> commentData;
        
        // XỬ LÝ CẢ 2 FORMAT cho add comment
        if (responseMap.containsKey('comment')) {
          // NEW FORMAT: {comment: {...}}
          print('[CommentService] Add comment: Detected new format (wrapped in comment field)');
          final rawCommentData = responseMap['comment'];
          if (rawCommentData is! Map<String, dynamic>) {
            throw Exception('Comment data is not a JSON object');
          }
          commentData = rawCommentData;
        } else if (responseMap.containsKey('_id')) {
          // OLD FORMAT: Comment object trực tiếp
          print('[CommentService] Add comment: Detected old format (comment object directly)');
          commentData = responseMap;
        } else {
          throw Exception('Invalid response format - missing comment data');
        }

        // Đảm bảo các field bắt buộc tồn tại
        final Map<String, dynamic> safeCommentData = Map<String, dynamic>.from(commentData);
        if (!safeCommentData.containsKey('likesCount')) safeCommentData['likesCount'] = 0;
        if (!safeCommentData.containsKey('likes')) safeCommentData['likes'] = <String>[];
        if (!safeCommentData.containsKey('repliesCount')) safeCommentData['repliesCount'] = 0;
        if (!safeCommentData.containsKey('updatedAt')) safeCommentData['updatedAt'] = safeCommentData['createdAt'];

        print('[CommentService] Creating CommentModel from: $safeCommentData');
        return CommentModel.fromJson(safeCommentData);
      } else {
        String errorMessage = 'Failed to add comment. Status: ${response.statusCode}';
        try { 
          final errorData = jsonDecode(response.body); 
          errorMessage = errorData['error'] ?? errorMessage; 
        } catch(_) {}
        
        print('[CommentService] Add comment failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[CommentService] Error adding comment: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        print('[CommentService] ❌ Cannot connect to backend server at $_apiBaseUrl');
        throw Exception('Không thể kết nối đến server');
      }
      rethrow;
    }
  }

  // Edit a comment - UPDATED URL PATTERN
  Future<CommentModel> editComment(String commentId, String userId, String newText) async {
    final url = Uri.parse('$_apiBaseUrl/edit/$commentId');  // EXPLICIT PATTERN
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
        // Parse response với error handling
        dynamic responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          print('[CommentService] JSON decode error for edit comment: $e');
          throw Exception('Invalid JSON response: $e');
        }

        if (responseData is! Map<String, dynamic>) {
          throw Exception('Response is not a JSON object');
        }

        final Map<String, dynamic> responseMap = responseData as Map<String, dynamic>;
        
        Map<String, dynamic> commentData;
        
        // XỬ LÝ CẢ 2 FORMAT cho edit comment
        if (responseMap.containsKey('comment')) {
          // NEW FORMAT: {comment: {...}}
          print('[CommentService] Edit comment: Detected new format (wrapped in comment field)');
          final rawCommentData = responseMap['comment'];
          if (rawCommentData is! Map<String, dynamic>) {
            throw Exception('Comment data is not a JSON object');
          }
          commentData = rawCommentData;
        } else if (responseMap.containsKey('_id')) {
          // OLD FORMAT: Comment object trực tiếp
          print('[CommentService] Edit comment: Detected old format (comment object directly)');
          commentData = responseMap;
        } else {
          throw Exception('Invalid response format - missing comment data');
        }

        // Đảm bảo các field bắt buộc tồn tại
        final Map<String, dynamic> safeCommentData = Map<String, dynamic>.from(commentData);
        if (!safeCommentData.containsKey('likesCount')) safeCommentData['likesCount'] = 0;
        if (!safeCommentData.containsKey('likes')) safeCommentData['likes'] = <String>[];
        if (!safeCommentData.containsKey('repliesCount')) safeCommentData['repliesCount'] = 0;
        if (!safeCommentData.containsKey('updatedAt')) safeCommentData['updatedAt'] = safeCommentData['createdAt'];

        print('[CommentService] Creating CommentModel from edited data: $safeCommentData');
        return CommentModel.fromJson(safeCommentData);
      } else {
        String errorMessage = 'Failed to edit comment. Status: ${response.statusCode}';
        try { 
          final errorData = jsonDecode(response.body); 
          errorMessage = errorData['error'] ?? errorMessage; 
        } catch(_) {}
        
        print('[CommentService] Edit comment failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[CommentService] Error editing comment: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        print('[CommentService] ❌ Cannot connect to backend server at $_apiBaseUrl');
        throw Exception('Không thể kết nối đến server');
      }
      rethrow;
    }
  }

  // Delete a comment - UPDATED URL PATTERN
  Future<void> deleteComment(String commentId, String userId) async {
    final url = Uri.parse('$_apiBaseUrl/delete/$commentId');  // EXPLICIT PATTERN
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
        String errorMessage = 'Failed to delete comment. Status: ${response.statusCode}';
        try { 
          final errorData = jsonDecode(response.body); 
          errorMessage = errorData['error'] ?? errorMessage; 
        } catch(_) {}
        
        print('[CommentService] Delete comment failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[CommentService] Error deleting comment: $e');
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        print('[CommentService] ❌ Cannot connect to backend server at $_apiBaseUrl');
        throw Exception('Không thể kết nối đến server');
      }
      rethrow;
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