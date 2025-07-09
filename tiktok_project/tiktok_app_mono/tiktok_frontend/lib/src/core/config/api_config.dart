// tiktok_frontend/lib/src/core/config/api_config.dart
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiConfig {
  // ==========================================
  // MULTI-DEVICE CONFIGURATION
  // ==========================================
  
  // Base URLs for different environments
  static const String _localhostUrl = 'http://localhost:8080';
  static const String _localhostAltUrl = 'http://127.0.0.1:8080';
  static const String _androidEmulatorUrl = 'http://172.31.98.67:8080';
  static const String _prodBaseUrl = 'https://your-production-domain.com';
  
  // Network IP - CẬP NHẬT IP NÀY VỚI IP THỰC CỦA MÁY TÍNH
  // Chạy lệnh sau để tìm IP:
  // Windows: ipconfig
  // Mac/Linux: ifconfig hoặc ip addr show
  static const String _networkIpUrl = 'http://172.31.98.67:8080'; // THAY ĐỔI IP NÀY!
  
  // Environment detection
  static bool get _isProduction => !kDebugMode;
  static bool get _isAndroidEmulator => !kIsWeb && Platform.isAndroid;
  static bool get _isRealDevice => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get _isWeb => kIsWeb;
  
  // Cached base URL after discovery
  static String? _discoveredUrl;
  static bool _discoveryCompleted = false;
  
  // Smart base URL selection
  static String get baseUrl {
    if (_isProduction) {
      return _prodBaseUrl;
    }
    
    // Return cached URL if discovery completed
    if (_discoveredUrl != null && _discoveryCompleted) {
      return _discoveredUrl!;
    }
    
    // Default URLs based on platform
    if (_isAndroidEmulator) {
      return _androidEmulatorUrl;
    } else if (_isRealDevice) {
      return _networkIpUrl;
    } else if (_isWeb) {
      return _localhostUrl;
    }
    
    return _localhostUrl;
  }
  
  // Manual override for testing
  static void setBaseUrl(String url) {
    _discoveredUrl = url;
    _discoveryCompleted = true;
    print('[ApiConfig] Manual override: Using $url');
  }
  
  // ==========================================
  // URL DISCOVERY AND TESTING
  // ==========================================
  
  // Discover the best working URL
  static Future<String> discoverBestUrl() async {
    if (_discoveryCompleted && _discoveredUrl != null) {
      return _discoveredUrl!;
    }
    
    print('[ApiConfig] Starting URL discovery...');
    
    // URLs to test in order of preference
    List<String> urlsToTest = [];
    
    if (_isAndroidEmulator) {
      urlsToTest = [
        _androidEmulatorUrl,
        _localhostAltUrl,
        _localhostUrl,
        _networkIpUrl,
      ];
    } else if (_isRealDevice) {
      urlsToTest = [
        _networkIpUrl,
        _androidEmulatorUrl,
        _localhostUrl,
      ];
    } else {
      urlsToTest = [
        _localhostUrl,
        _localhostAltUrl,
        _networkIpUrl,
      ];
    }
    
    for (final url in urlsToTest) {
      print('[ApiConfig] Testing URL: $url');
      
      if (await _testConnection(url)) {
        print('[ApiConfig] ✅ Working URL found: $url');
        _discoveredUrl = url;
        _discoveryCompleted = true;
        return url;
      } else {
        print('[ApiConfig] ❌ Failed: $url');
      }
    }
    
    print('[ApiConfig] ⚠️ No working URL found, using default');
    _discoveredUrl = baseUrl;
    _discoveryCompleted = true;
    return baseUrl;
  }
  
  // Test connection to a specific URL
  static Future<bool> _testConnection(String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: defaultHeaders,
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // Force refresh URL discovery
  static Future<String> refreshUrlDiscovery() async {
    _discoveryCompleted = false;
    _discoveredUrl = null;
    return await discoverBestUrl();
  }
  
  // ==========================================
  // ENHANCED CONNECTION TESTING
  // ==========================================
  
  // Comprehensive connection test
  static Future<Map<String, dynamic>> testConnection() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'platform': _getPlatformInfo(),
      'tests': <String, dynamic>{},
    };
    
    final urlsToTest = [
      _localhostUrl,
      _localhostAltUrl,
      _androidEmulatorUrl,
      _networkIpUrl,
    ];
    
    for (final url in urlsToTest) {
      final testResult = await _detailedConnectionTest(url);
      results['tests'][url] = testResult;
    }
    
    // Find best URL from results
    String? bestUrl;
    for (final entry in results['tests'].entries) {
      if (entry.value['success'] == true) {
        bestUrl = entry.key;
        break;
      }
    }
    
    results['recommended_url'] = bestUrl ?? baseUrl;
    results['current_url'] = baseUrl;
    
    return results;
  }
  
  static Future<Map<String, dynamic>> _detailedConnectionTest(String url) async {
    final result = <String, dynamic>{
      'url': url,
      'success': false,
      'response_time_ms': null,
      'status_code': null,
      'error': null,
    };
    
    try {
      final stopwatch = Stopwatch()..start();
      
      final response = await http.get(
        Uri.parse('$url/health'),
        headers: defaultHeaders,
      ).timeout(const Duration(seconds: 10));
      
      stopwatch.stop();
      
      result['success'] = response.statusCode == 200;
      result['status_code'] = response.statusCode;
      result['response_time_ms'] = stopwatch.elapsedMilliseconds;
      
      if (response.statusCode == 200) {
        try {
          final body = json.decode(response.body);
          result['server_info'] = body;
        } catch (e) {
          // Server responded but not with JSON
        }
      }
      
    } catch (e) {
      result['error'] = e.toString();
    }
    
    return result;
  }
  
  static Map<String, dynamic> _getPlatformInfo() {
    return {
      'is_web': kIsWeb,
      'is_android': !kIsWeb && Platform.isAndroid,
      'is_ios': !kIsWeb && Platform.isIOS,
      'is_debug': kDebugMode,
      'detected_environment': _isAndroidEmulator ? 'android_emulator' : 
                             _isRealDevice ? 'real_device' : 
                             _isWeb ? 'web' : 'unknown',
    };
  }
  
  // ==========================================
  // API ENDPOINTS (UNCHANGED)
  // ==========================================
  
  static const String authEndpoint = '/api/users';
  static const String videosEndpoint = '/api/videos';
  static const String commentsEndpoint = '/api/comments';
  static const String followEndpoint = '/api/follow';
  static const String notificationsEndpoint = '/api/notifications';
  static const String analyticsEndpoint = '/api/analytics';
  static const String searchEndpoint = '/api/search';
  
  // Full endpoint URLs
  static String get authUrl => '$baseUrl$authEndpoint';
  static String get videosUrl => '$baseUrl$videosEndpoint';
  static String get commentsUrl => '$baseUrl$commentsEndpoint';
  static String get followUrl => '$baseUrl$followEndpoint';
  static String get notificationsUrl => '$baseUrl$notificationsEndpoint';
  static String get analyticsUrl => '$baseUrl$analyticsEndpoint';
  static String get searchUrl => '$baseUrl$searchEndpoint';
  
  // Special endpoints
  static String get uploadUrl => '$videosUrl/upload';
  static String get feedUrl => '$videosUrl/feed';
  static String get healthUrl => '$baseUrl/health';
  static String get debugUrl => '$baseUrl/api/debug';
  static String get networkInfoUrl => '$baseUrl/api/network-info';
  
  // Static files base URL
  static String get fileBaseUrl => baseUrl;
  
  // ==========================================
  // TIMEOUTS AND LIMITS (ENHANCED)
  // ==========================================
  
  // Request timeouts (in seconds) - Increased for mobile networks
  static const int connectTimeout = 15;  // Increased from 30
  static const int receiveTimeout = 30;  // Increased from 60
  static const int sendTimeout = 60;     // Keep for file uploads
  
  // Discovery timeouts
  static const int discoveryTimeout = 5;
  static const int healthCheckTimeout = 10;
  
  // Pagination defaults
  static const int defaultPageSize = 10;
  static const int maxPageSize = 50;
  
  // File upload limits
  static const int maxVideoSizeMB = 100;
  static const int maxImageSizeMB = 10;
  
  // Supported file formats
  static const List<String> supportedVideoFormats = [
    'mp4', 'mov', 'm4v', 'avi', 'mpeg', 'webm'
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
  static const bool enableNetworkDiagnostics = kDebugMode;
  
  // ==========================================
  // HELPER METHODS (ENHANCED)
  // ==========================================
  
  static bool get isProduction => _isProduction;
  static bool get isDevelopment => kDebugMode;
  static bool get isAndroidEmulator => _isAndroidEmulator;
  static bool get isRealDevice => _isRealDevice;
  static bool get isWeb => _isWeb;
  
  static String buildUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
  
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'TikTokClone/${_getPlatformInfo()['detected_environment']}',
  };
  
  static Map<String, String> get uploadHeaders => {
    'Accept': 'application/json',
    'User-Agent': 'TikTokClone/${_getPlatformInfo()['detected_environment']}',
    // Don't set Content-Type for multipart uploads
  };
  
  // ==========================================
  // CONFIGURATION GETTERS (ENHANCED)
  // ==========================================
  
  static Map<String, dynamic> get config => {
    'baseUrl': baseUrl,
    'discoveredUrl': _discoveredUrl,
    'discoveryCompleted': _discoveryCompleted,
    'environment': isDevelopment ? 'development' : 'production',
    'platform': _getPlatformInfo(),
    'enableLogging': enableApiLogging,
    'timeouts': {
      'connect': connectTimeout,
      'receive': receiveTimeout,
      'send': sendTimeout,
      'discovery': discoveryTimeout,
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
    },
    'urls': {
      'localhost': _localhostUrl,
      'android_emulator': _androidEmulatorUrl,
      'network_ip': _networkIpUrl,
      'production': _prodBaseUrl,
    }
  };
  
  // ==========================================
  // VALIDATION METHODS (UNCHANGED)
  // ==========================================
  
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
  
  // ==========================================
  // DEBUGGING AND DIAGNOSTICS (ENHANCED)
  // ==========================================
  
  static void printConfig() {
    if (enableApiLogging) {
      print('');
      print('=== 🔧 API CONFIG DEBUG ===');
      print('Environment: ${isDevelopment ? 'Development' : 'Production'}');
      print('Platform: ${_getPlatformInfo()['detected_environment']}');
      print('Current Base URL: $baseUrl');
      print('Discovery Completed: $_discoveryCompleted');
      if (_discoveredUrl != null) {
        print('Discovered URL: $_discoveredUrl');
      }
      print('');
      print('📡 Available URLs:');
      print('  Localhost: $_localhostUrl');
      print('  Android Emulator: $_androidEmulatorUrl');
      print('  Network IP: $_networkIpUrl');
      print('  Production: $_prodBaseUrl');
      print('');
      print('🎯 Endpoint URLs:');
      print('  Auth: $authUrl');
      print('  Videos: $videosUrl');
      print('  Health: $healthUrl');
      print('  Debug: $debugUrl');
      print('========================');
      print('');
    }
  }
  
  // Print network diagnostic information
  static Future<void> printNetworkDiagnostic() async {
    if (!enableNetworkDiagnostics) return;
    
    print('');
    print('=== 🌐 NETWORK DIAGNOSTIC ===');
    
    final testResult = await testConnection();
    print('Platform: ${testResult['platform']['detected_environment']}');
    print('Current URL: ${testResult['current_url']}');
    print('Recommended URL: ${testResult['recommended_url']}');
    print('');
    
    for (final entry in testResult['tests'].entries) {
      final url = entry.key;
      final test = entry.value;
      final status = test['success'] ? '✅' : '❌';
      final time = test['response_time_ms']?.toString() ?? 'N/A';
      print('$status $url (${time}ms)');
      if (test['error'] != null) {
        print('   Error: ${test['error']}');
      }
    }
    
    print('============================');
    print('');
  }
  
  // Initialize and discover best URL
  static Future<void> initialize() async {
    if (enableApiLogging) {
      print('[ApiConfig] Initializing API configuration...');
    }
    
    if (!_discoveryCompleted) {
      await discoverBestUrl();
    }
    
    if (enableApiLogging) {
      printConfig();
    }
    
    if (enableNetworkDiagnostics) {
      await printNetworkDiagnostic();
    }
  }
}