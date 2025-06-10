// tiktok_frontend/lib/src/features/notifications/domain/services/notification_service.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';

class NotificationService {
  // Cố định backend host và port
  static const String _backendHost = 'localhost';
  static const String _backendPort = '8080';
  static const String _apiPath = '/api/notifications';

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
        print("[NotificationService] Error checking platform for host: $e");
      }
      return _backendHost;
    }
  }

  String get _apiBaseUrl {
    final host = _effectiveBackendHost;
    return 'http://$host:$_backendPort$_apiPath';
  }

  // Get notifications for user with pagination
  Future<NotificationPaginationResponse> getUserNotifications(String userId, {int page = 1, int limit = 20}) async {
    final url = Uri.parse('$_apiBaseUrl/user/$userId?page=$page&limit=$limit');
    print('[NotificationService] Fetching notifications from $url');
    
    try {
      final response = await http.get(
        url, 
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[NotificationService] Get Notifications Response Status: ${response.statusCode}');
      print('[NotificationService] Raw Response Body: ${response.body}');

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

        return NotificationPaginationResponse.fromJson(jsonData);
      } else {
        final errorMessage = 'Failed to load notifications. Status: ${response.statusCode}';
        print('[NotificationService] $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[NotificationService] Error fetching notifications: $e');
      
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('Failed host lookup')) {
        print('[NotificationService] ❌ Cannot connect to backend server at $_apiBaseUrl');
        throw Exception('Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.');
      }
      
      rethrow;
    }
  }

  // Get unread notifications count
  Future<int> getUnreadCount(String userId) async {
    final url = Uri.parse('$_apiBaseUrl/user/$userId/unread-count');
    print('[NotificationService] Getting unread count from $url');
    
    try {
      final response = await http.get(
        url, 
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[NotificationService] Unread Count Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['unreadCount'] as int? ?? 0;
      } else {
        throw _parseErrorResponse(response, 'Failed to get unread count');
      }
    } catch (e) {
      print('[NotificationService] Error getting unread count: $e');
      _handleConnectionError(e);
      rethrow;
    }
  }

  // Mark notification as read
  Future<int> markNotificationAsRead(String notificationId, String userId) async {
    final url = Uri.parse('$_apiBaseUrl/$notificationId/read');
    print('[NotificationService] Marking notification as read: $notificationId');
    
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
        }),
      ).timeout(const Duration(seconds: 10));

      print('[NotificationService] Mark as Read Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['unreadCount'] as int? ?? 0;
      } else {
        throw _parseErrorResponse(response, 'Failed to mark notification as read');
      }
    } catch (e) {
      print('[NotificationService] Error marking notification as read: $e');
      _handleConnectionError(e);
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead(String userId) async {
    final url = Uri.parse('$_apiBaseUrl/user/$userId/read-all');
    print('[NotificationService] Marking all notifications as read for user: $userId');
    
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[NotificationService] Mark All as Read Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('[NotificationService] All notifications marked as read successfully');
        return;
      } else {
        throw _parseErrorResponse(response, 'Failed to mark all notifications as read');
      }
    } catch (e) {
      print('[NotificationService] Error marking all notifications as read: $e');
      _handleConnectionError(e);
      rethrow;
    }
  }

  // Delete notification
  Future<int> deleteNotification(String notificationId, String userId) async {
    final url = Uri.parse('$_apiBaseUrl/$notificationId');
    print('[NotificationService] Deleting notification: $notificationId');
    
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

      print('[NotificationService] Delete Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['unreadCount'] as int? ?? 0;
      } else {
        throw _parseErrorResponse(response, 'Failed to delete notification');
      }
    } catch (e) {
      print('[NotificationService] Error deleting notification: $e');
      _handleConnectionError(e);
      rethrow;
    }
  }

  // Helper method to parse error response
  Exception _parseErrorResponse(http.Response response, String defaultMessage) {
    String errorMessage = '$defaultMessage. Status: ${response.statusCode}';
    try { 
      final errorData = jsonDecode(response.body); 
      errorMessage = errorData['error'] ?? errorMessage; 
    } catch(_) {}
    
    print('[NotificationService] Operation failed: $errorMessage');
    return Exception(errorMessage);
  }

  // Helper method to handle connection errors
  void _handleConnectionError(dynamic error) {
    if (error.toString().contains('Connection refused') || 
        error.toString().contains('Failed host lookup')) {
      print('[NotificationService] ❌ Cannot connect to backend server at $_apiBaseUrl');
      throw Exception('Không thể kết nối đến server');
    }
  }

  // Test connection
  Future<bool> testConnection() async {
    try {
      final healthUrl = Uri.parse('http://$_effectiveBackendHost:$_backendPort/health');
      print('[NotificationService] Testing connection to $healthUrl');
      
      final response = await http.get(healthUrl).timeout(const Duration(seconds: 5));
      print('[NotificationService] Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[NotificationService] Connection test failed: $e');
      return false;
    }
  }
}