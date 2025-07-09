// tiktok_frontend/lib/src/core/config/api_config.dart
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiConfig {
  // ==========================================
  // ENHANCED MULTI-DEVICE CONFIGURATION
  // ==========================================
  
  // Base URLs for different environments
  static const String _localhostUrl = 'http://localhost:8080';
  static const String _localhostAltUrl = 'http://127.0.0.1:8080';
  static const String _androidEmulatorUrl = 'http://10.0.2.2:8080'; // CRITICAL FOR AVD
  static const String _prodBaseUrl = 'https://your-production-domain.com';
  
  // UPDATED: Network IP - Replace with your actual machine IP
  // Run 'ipconfig' (Windows) or 'ifconfig' (Mac/Linux) to find your IP
  static const String _networkIpUrl = 'http://192.2.26.102:8080'; // CHANGE THIS!
  
  // Environment detection
  static bool get _isProduction => !kDebugMode;
  static bool get _isAndroidEmulator => !kIsWeb && Platform.isAndroid;
  static bool get _isRealDevice => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get _isWeb => kIsWeb;
  
  // Cached base URL after discovery
  static String? _discoveredUrl;
  static bool _discoveryCompleted = false;
  static DateTime? _lastDiscovery;
  
  // Cache duration for URL discovery
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  
  // Smart base URL selection with caching
  static String get baseUrl {
    if (_isProduction) {
      return _prodBaseUrl;
    }
    
    // Return cached URL if discovery completed and still valid
    if (_discoveredUrl != null && _isDiscoveryCacheValid()) {
      return _discoveredUrl!;
    }
    
    // Default URLs based on platform while discovery is running
    if (_isAndroidEmulator) {
      return _androidEmulatorUrl; // This is CRITICAL for AVD
    } else if (_isRealDevice) {
      return _networkIpUrl;
    } else if (_isWeb) {
      return _localhostUrl;
    }
    
    return _localhostUrl;
  }
  
  // Check if discovery cache is still valid
  static bool _isDiscoveryCacheValid() {
    if (_lastDiscovery == null) return false;
    return DateTime.now().difference(_lastDiscovery!) < _cacheValidDuration;
  }
  
  // Manual override for testing
  static void setBaseUrl(String url) {
    _discoveredUrl = url;
    _discoveryCompleted = true;
    _lastDiscovery = DateTime.now();
    print('[ApiConfig] 📌 Manual override: Using $url');
  }
  
  // ==========================================
  // ENHANCED URL DISCOVERY
  // ==========================================
  
  // Discover the best working URL with improved logic
  static Future<String> discoverBestUrl() async {
    if (_discoveryCompleted && _discoveredUrl != null && _isDiscoveryCacheValid()) {
      print('[ApiConfig] 📋 Using cached URL: $_discoveredUrl');
      return _discoveredUrl!;
    }
    
    print('[ApiConfig] 🔍 Starting URL discovery for ${_getPlatformName()}...');
    
    // URLs to test in order of preference based on platform
    List<String> urlsToTest = [];
    
    if (_isAndroidEmulator) {
      urlsToTest = [
        _androidEmulatorUrl,    // PRIMARY for AVD
        _localhostUrl,          // Fallback 1
        _localhostAltUrl,       // Fallback 2
        _networkIpUrl,          // Fallback 3
      ];
      print('[ApiConfig] 🤖 Android Emulator detected - prioritizing 10.0.2.2');
    } else if (_isRealDevice) {
      urlsToTest = [
        _networkIpUrl,          // PRIMARY for real device
        _androidEmulatorUrl,    // Fallback 1
        _localhostUrl,          // Fallback 2
      ];
      print('[ApiConfig] 📱 Real Device detected - prioritizing network IP');
    } else {
      urlsToTest = [
        _localhostUrl,          // PRIMARY for web
        _localhostAltUrl,       // Fallback 1
        _networkIpUrl,          // Fallback 2
      ];
      print('[ApiConfig] 🌐 Web Browser detected - prioritizing localhost');
    }
    
    // Test each URL with shorter timeout for faster discovery
    for (int i = 0; i < urlsToTest.length; i++) {
      final url = urlsToTest[i];
      print('[ApiConfig] 🧪 Testing URL ${i + 1}/${urlsToTest.length}: $url');
      
      if (await _testConnection(url)) {
        print('[ApiConfig] ✅ Working URL found: $url');
        _discoveredUrl = url;
        _discoveryCompleted = true;
        _lastDiscovery = DateTime.now();
        return url;
      } else {
        print('[ApiConfig] ❌ Failed: $url');
      }
    }
    
    // If no URL works, use platform default
    final fallbackUrl = _isAndroidEmulator ? _androidEmulatorUrl : 
                       _isRealDevice ? _networkIpUrl : _localhostUrl;
    
    print('[ApiConfig] ⚠️ No working URL found, using fallback: $fallbackUrl');
    _discoveredUrl = fallbackUrl;
    _discoveryCompleted = true;
    _lastDiscovery = DateTime.now();
    return fallbackUrl;
  }
  
  // Enhanced connection test with shorter timeout
  static Future<bool> _testConnection(String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'TikTokClone/${_getPlatformName()}',
        },
      ).timeout(const Duration(seconds: 3)); // Shorter timeout for faster discovery
      
      final success = response.statusCode == 200;
      if (success) {
        try {
          final body = json.decode(response.body);
          print('[ApiConfig] 📊 Server response: ${body['service']} v${body['version']}');
        } catch (e) {
          // Server responded but not with expected JSON
        }
      }
      
      return success;
    } catch (e) {
      return false;
    }
  }
  
  // Force refresh URL discovery
  static Future<String> refreshUrlDiscovery() async {
    print('[ApiConfig] 🔄 Forcing URL discovery refresh...');
    _discoveryCompleted = false;
    _discoveredUrl = null;
    _lastDiscovery = null;
    return await discoverBestUrl();
  }
  
  // ==========================================
  // COMPREHENSIVE CONNECTION TESTING
  // ==========================================
  
  // Run comprehensive connection test with detailed results
  static Future<Map<String, dynamic>> testConnection() async {
    print('[ApiConfig] 🔬 Running comprehensive connection test...');
    
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'platform': _getPlatformInfo(),
      'tests': <String, dynamic>{},
      'recommendations': <String, dynamic>{},
    };
    
    final urlsToTest = [
      {'name': 'Android Emulator (10.0.2.2)', 'url': _androidEmulatorUrl, 'priority': _isAndroidEmulator ? 1 : 3},
      {'name': 'Network IP', 'url': _networkIpUrl, 'priority': _isRealDevice ? 1 : 2},
      {'name': 'Localhost', 'url': _localhostUrl, 'priority': _isWeb ? 1 : 4},
      {'name': 'Localhost Alt', 'url': _localhostAltUrl, 'priority': 5},
    ];
    
    // Sort by priority for current platform
    urlsToTest.sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));
    
    String? bestUrl;
    int bestTime = 999999;
    
    for (final urlInfo in urlsToTest) {
      final name = urlInfo['name'] as String;
      final url = urlInfo['url'] as String;
      final priority = urlInfo['priority'] as int;
      
      final testResult = await _detailedConnectionTest(url);
      testResult['priority'] = priority;
      results['tests'][name] = testResult;
      
      // Track best performing URL
      if (testResult['success'] == true) {
        final time = testResult['response_time_ms'] as int? ?? 999999;
        if (time < bestTime) {
          bestTime = time;
          bestUrl = url;
        }
      }
    }
    
    // Generate recommendations
    results['recommendations'] = {
      'best_url': bestUrl,
      'best_time_ms': bestUrl != null ? bestTime : null,
      'platform_default': _isAndroidEmulator ? _androidEmulatorUrl : 
                          _isRealDevice ? _networkIpUrl : _localhostUrl,
      'current_url': baseUrl,
      'should_update': bestUrl != null && bestUrl != baseUrl,
    };
    
    return results;
  }
  
  static Future<Map<String, dynamic>> _detailedConnectionTest(String url) async {
    final result = <String, dynamic>{
      'url': url,
      'success': false,
      'response_time_ms': null,
      'status_code': null,
      'error': null,
      'server_info': null,
    };
    
    try {
      final stopwatch = Stopwatch()..start();
      
      final response = await http.get(
        Uri.parse('$url/health'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'TikTokClone/${_getPlatformName()}',
        },
      ).timeout(const Duration(seconds: 5));
      
      stopwatch.stop();
      
      result['success'] = response.statusCode == 200;
      result['status_code'] = response.statusCode;
      result['response_time_ms'] = stopwatch.elapsedMilliseconds;
      
      if (response.statusCode == 200) {
        try {
          final body = json.decode(response.body);
          result['server_info'] = {
            'service': body['service'],
            'version': body['version'],
            'status': body['status'],
            'features': body['features'],
          };
        } catch (e) {
          result['server_info'] = 'Response OK but not expected JSON format';
        }
      }
      
    } catch (e) {
      result['error'] = e.toString();
    }
    
    return result;
  }
  
  static String _getPlatformName() {
    if (_isAndroidEmulator) return 'android_emulator';
    if (_isRealDevice) return 'real_device';
    if (_isWeb) return 'web';
    return 'unknown';
  }
  
  static Map<String, dynamic> _getPlatformInfo() {
    return {
      'is_web': kIsWeb,
      'is_android': !kIsWeb && Platform.isAndroid,
      'is_ios': !kIsWeb && Platform.isIOS,
      'is_debug': kDebugMode,
      'detected_environment': _getPlatformName(),
      'recommended_url': _isAndroidEmulator ? _androidEmulatorUrl : 
                        _isRealDevice ? _networkIpUrl : _localhostUrl,
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
  
  // Static files base URL
  static String get fileBaseUrl => baseUrl;
  
  // ==========================================
  // TIMEOUTS AND LIMITS (OPTIMIZED FOR MOBILE)
  // ==========================================
  
  // Request timeouts (in seconds) - Optimized for mobile networks
  static const int connectTimeout = 10;  // Reduced for faster feedback
  static const int receiveTimeout = 20;  // Reasonable for API calls
  static const int sendTimeout = 60;     // Keep high for file uploads
  
  // Discovery timeouts
  static const int discoveryTimeout = 3;  // Fast discovery
  static const int healthCheckTimeout = 5;
  
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
  
  // Debug configuration
  static const bool enableApiLogging = kDebugMode;
  static const bool enableAnalyticsLogging = kDebugMode;
  static const bool enableNetworkDiagnostics = kDebugMode;
  
  // ==========================================
  // HELPER METHODS
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
    'User-Agent': 'TikTokClone/${_getPlatformName()}',
    'Cache-Control': 'no-cache',
  };
  
  static Map<String, String> get uploadHeaders => {
    'Accept': 'application/json',
    'User-Agent': 'TikTokClone/${_getPlatformName()}',
    // Don't set Content-Type for multipart uploads
  };
  
  // ==========================================
  // CONFIGURATION GETTERS
  // ==========================================
  
  static Map<String, dynamic> get config => {
    'baseUrl': baseUrl,
    'discoveredUrl': _discoveredUrl,
    'discoveryCompleted': _discoveryCompleted,
    'cacheValid': _isDiscoveryCacheValid(),
    'lastDiscovery': _lastDiscovery?.toIso8601String(),
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
    'urls': {
      'localhost': _localhostUrl,
      'android_emulator': _androidEmulatorUrl,
      'network_ip': _networkIpUrl,
      'production': _prodBaseUrl,
    }
  };
  
  // ==========================================
  // VALIDATION METHODS
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
  // DEBUGGING AND DIAGNOSTICS
  // ==========================================
  
  static void printConfig() {
    if (enableApiLogging) {
      print('');
      print('=== 🔧 API CONFIG DEBUG ===');
      print('Environment: ${isDevelopment ? 'Development' : 'Production'}');
      print('Platform: ${_getPlatformName()}');
      print('Current Base URL: $baseUrl');
      print('Discovery Completed: $_discoveryCompleted');
      print('Cache Valid: ${_isDiscoveryCacheValid()}');
      if (_discoveredUrl != null) {
        print('Discovered URL: $_discoveredUrl');
      }
      if (_lastDiscovery != null) {
        print('Last Discovery: ${_lastDiscovery!.toIso8601String()}');
      }
      print('');
      print('📡 Available URLs:');
      print('  🤖 Android Emulator: $_androidEmulatorUrl');
      print('  📱 Network IP: $_networkIpUrl');
      print('  🌐 Localhost: $_localhostUrl');
      print('  🔄 Localhost Alt: $_localhostAltUrl');
      print('  🚀 Production: $_prodBaseUrl');
      print('');
      print('🎯 Endpoint URLs:');
      print('  Auth: $authUrl');
      print('  Videos: $videosUrl');
      print('  Search: $searchUrl');
      print('  Health: $healthUrl');
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
    final platform = testResult['platform'] as Map<String, dynamic>;
    final recommendations = testResult['recommendations'] as Map<String, dynamic>;
    
    print('Platform: ${platform['detected_environment']}');
    print('Current URL: ${recommendations['current_url']}');
    print('Best URL: ${recommendations['best_url'] ?? 'None working'}');
    print('Should Update: ${recommendations['should_update']}');
    print('');
    
    final tests = testResult['tests'] as Map<String, dynamic>;
    print('📊 Connection Tests:');
    for (final entry in tests.entries) {
      final name = entry.key;
      final test = entry.value as Map<String, dynamic>;
      final status = test['success'] ? '✅' : '❌';
      final time = test['response_time_ms']?.toString() ?? 'N/A';
      final priority = test['priority'] ?? 0;
      
      print('$status [$priority] $name (${time}ms)');
      if (test['error'] != null) {
        print('   Error: ${test['error']}');
      }
      if (test['server_info'] != null && test['success']) {
        final info = test['server_info'];
        if (info is Map) {
          print('   Server: ${info['service']} v${info['version']}');
        }
      }
    }
    
    print('============================');
    print('');
  }
  
  // Initialize and discover best URL
  static Future<void> initialize() async {
    if (enableApiLogging) {
      print('[ApiConfig] 🚀 Initializing API configuration...');
    }
    
    // Always run discovery on initialization to ensure fresh URLs
    await discoverBestUrl();
    
    if (enableApiLogging) {
      printConfig();
    }
    
    if (enableNetworkDiagnostics) {
      await printNetworkDiagnostic();
    }
    
    if (enableApiLogging) {
      print('[ApiConfig] ✅ API configuration initialized successfully');
    }
  }
  
  // Quick health check
  static Future<bool> quickHealthCheck() async {
    try {
      final response = await http.get(
        Uri.parse(healthUrl),
        headers: defaultHeaders,
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}