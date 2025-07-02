// tiktok_frontend/lib/src/core/config/api_config.dart
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Base URL configuration
  static const String _devBaseUrl = 'http://localhost:8080';
  static const String _prodBaseUrl = 'https://your-production-domain.com';
  
  // Use development URL in debug mode, production URL in release mode
  static String get baseUrl {
    if (kDebugMode) {
      return _devBaseUrl;
    } else {
      return _prodBaseUrl;
    }
  }
  
  // API endpoints
  static const String authEndpoint = '/api/users';
  static const String videosEndpoint = '/api/videos';
  static const String commentsEndpoint = '/api/comments';
  static const String followEndpoint = '/api/follow';
  static const String notificationsEndpoint = '/api/notifications';
  static const String analyticsEndpoint = '/api/analytics';
  
  // Full endpoint URLs
  static String get authUrl => '$baseUrl$authEndpoint';
  static String get videosUrl => '$baseUrl$videosEndpoint';
  static String get commentsUrl => '$baseUrl$commentsEndpoint';
  static String get followUrl => '$baseUrl$followEndpoint';
  static String get notificationsUrl => '$baseUrl$notificationsEndpoint';
  static String get analyticsUrl => '$baseUrl$analyticsEndpoint';
  
  // File upload configuration
  static String get uploadUrl => '$videosUrl/upload';
  static String get feedUrl => '$videosUrl/feed';
  
  // Static files base URL
  static String get fileBaseUrl => baseUrl;
  
  // Request timeouts (in seconds)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 60;
  static const int sendTimeout = 60;
  
  // Pagination defaults
  static const int defaultPageSize = 10;
  static const int maxPageSize = 50;
  
  // File upload limits
  static const int maxVideoSizeMB = 100;
  static const int maxImageSizeMB = 10;
  
  // Supported file formats
  static const List<String> supportedVideoFormats = [
    'mp4', 'mov', 'm4v', 'avi', 'mpeg'
  ];
  
  static const List<String> supportedImageFormats = [
    'jpg', 'jpeg', 'png', 'gif', 'webp'
  ];
  
  // Analytics configuration
  static const int viewTrackingCooldownSeconds = 5;
  static const int minViewDurationSeconds = 1;
  
  // Debug configuration
  static const bool enableApiLogging = kDebugMode;
  static const bool enableAnalyticsLogging = kDebugMode;
  
  // Helper methods
  static bool get isProduction => !kDebugMode;
  static bool get isDevelopment => kDebugMode;
  
  static String buildUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
  
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  static Map<String, String> get uploadHeaders => {
    'Accept': 'application/json',
    // Don't set Content-Type for multipart uploads - let http package handle it
  };
  
  // Environment-specific configurations
  static Map<String, dynamic> get config => {
    'baseUrl': baseUrl,
    'environment': isDevelopment ? 'development' : 'production',
    'enableLogging': enableApiLogging,
    'timeouts': {
      'connect': connectTimeout,
      'receive': receiveTimeout,
      'send': sendTimeout,
    },
    'limits': {
      'maxVideoSizeMB': maxVideoSizeMB,
      'maxImageSizeMB': maxImageSizeMB,
      'defaultPageSize': defaultPageSize,
      'maxPageSize': maxPageSize,
    },
    'analytics': {
      'cooldownSeconds': viewTrackingCooldownSeconds,
      'minViewDurationSeconds': minViewDurationSeconds,
      'enableLogging': enableAnalyticsLogging,
    }
  };
  
  // Validation methods
  static bool isValidVideoFormat(String extension) {
    return supportedVideoFormats.contains(extension.toLowerCase());
  }
  
  static bool isValidImageFormat(String extension) {
    return supportedImageFormats.contains(extension.toLowerCase());
  }
  
  static bool isValidFileSize(int sizeInBytes, {bool isVideo = true}) {
    final maxSizeBytes = isVideo 
      ? maxVideoSizeMB * 1024 * 1024 
      : maxImageSizeMB * 1024 * 1024;
    return sizeInBytes <= maxSizeBytes;
  }
  
  // Debugging helpers
  static void printConfig() {
    if (enableApiLogging) {
      print('=== API CONFIG ===');
      print('Environment: ${isDevelopment ? 'Development' : 'Production'}');
      print('Base URL: $baseUrl');
      print('Auth URL: $authUrl');
      print('Videos URL: $videosUrl');
      print('Analytics URL: $analyticsUrl');
      print('File Base URL: $fileBaseUrl');
      print('==================');
    }
  }
}