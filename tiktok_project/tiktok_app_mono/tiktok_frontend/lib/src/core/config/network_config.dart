// tiktok_frontend/lib/src/core/config/network_config.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NetworkConfig {
  // ==========================================
  // CẤU HÌNH VỚI IP THỰC TẾ CỦA BẠN
  // ==========================================
  
  static const String _serverPort = '8080'; // ĐÚNG PORT CỦA BACKEND
  static const String _localhostUrl = 'http://localhost:$_serverPort';
  static const String _localhostAltUrl = 'http://127.0.0.1:$_serverPort';
  static const String _androidEmulatorUrl = 'http://10.0.2.2:$_serverPort';
  
  // ⭐ IP THỰC TẾ CỦA MÁY TÍNH BẠN - CẬP NHẬT IP NÀY!
  static const String _networkIpUrl = 'http://192.2.26.102:$_serverPort';
  
  // Cache cho discovered URL
  static String? _cachedBaseUrl;
  static DateTime? _cacheExpiry;
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  
  // Platform detection
  static bool get _isAndroidEmulator => !kIsWeb && Platform.isAndroid;
  static bool get _isRealDevice => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get _isWeb => kIsWeb;
  
  // ==========================================
  // MAIN ENTRY POINT
  // ==========================================
  
  static Future<String> getBaseUrl(String endpoint) async {
    // Kiểm tra cache trước
    if (_isCacheValid()) {
      print('[NetworkConfig] 📋 Using cached URL: $_cachedBaseUrl');
      return '$_cachedBaseUrl$endpoint';
    }
    
    print('[NetworkConfig] 🔍 Discovering best URL for ${_getPlatformName()}...');
    
    // Discover URL mới
    final baseUrl = await _discoverBestUrl();
    
    // Cache kết quả
    _cachedBaseUrl = baseUrl;
    _cacheExpiry = DateTime.now().add(_cacheValidDuration);
    
    print('[NetworkConfig] ✅ Using URL: $baseUrl$endpoint');
    return '$baseUrl$endpoint';
  }
  
  static Future<String> getFileBaseUrl() async {
    return await _getBaseUrlOnly();
  }
  
  static Future<String> _getBaseUrlOnly() async {
    if (_isCacheValid()) {
      return _cachedBaseUrl!;
    }
    
    final baseUrl = await _discoverBestUrl();
    _cachedBaseUrl = baseUrl;
    _cacheExpiry = DateTime.now().add(_cacheValidDuration);
    
    return baseUrl;
  }
  
  // ==========================================
  // URL DISCOVERY LOGIC
  // ==========================================
  
  static Future<String> _discoverBestUrl() async {
    // URLs to test theo thứ tự ưu tiên
    List<String> urlsToTest = [];
    
    if (_isAndroidEmulator) {
      urlsToTest = [
        _androidEmulatorUrl,    // 10.0.2.2:8080 - CHÍNH CHO EMULATOR
        _localhostAltUrl,       // 127.0.0.1:8080 - DỰ PHÒNG
        _networkIpUrl,          // 172.31.98.67:8080 - THỬ THÊM
      ];
      print('[NetworkConfig] 🤖 Android Emulator detected');
    } else if (_isRealDevice) {
      urlsToTest = [
        _networkIpUrl,          // 172.31.98.67:8080 - CHÍNH CHO REAL DEVICE
        _androidEmulatorUrl,    // 10.0.2.2:8080 - DỰ PHÒNG
        _localhostUrl,          // localhost:8080 - THỬ THÊM
      ];
      print('[NetworkConfig] 📱 Real Device detected');
    } else {
      urlsToTest = [
        _localhostUrl,          // localhost:8080
        _localhostAltUrl,       // 127.0.0.1:8080
        _networkIpUrl,          // 172.31.98.67:8080
      ];
      print('[NetworkConfig] 🌐 Web Browser detected');
    }
    
    // Test từng URL
    for (final url in urlsToTest) {
      print('[NetworkConfig] 🧪 Testing: $url');
      
      if (await _testConnection(url)) {
        print('[NetworkConfig] ✅ Success: $url');
        return url;
      } else {
        print('[NetworkConfig] ❌ Failed: $url');
      }
    }
    
    // Fallback
    final fallbackUrl = _isAndroidEmulator ? _androidEmulatorUrl : 
                       _isRealDevice ? _networkIpUrl : _localhostUrl;
    print('[NetworkConfig] ⚠️ No working URL found, using fallback: $fallbackUrl');
    return fallbackUrl;
  }
  
  static Future<bool> _testConnection(String baseUrl) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'TikTokClone/${_getPlatformName()}',
        },
      ).timeout(const Duration(seconds: 5)); // Tăng timeout lên 5s
      
      stopwatch.stop();
      
      final success = response.statusCode == 200;
      print('[NetworkConfig] 📊 $baseUrl -> ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms) ${success ? '✅' : '❌'}');
      
      return success;
    } catch (e) {
      print('[NetworkConfig] 💥 $baseUrl -> Error: ${e.toString()}');
      return false;
    }
  }
  
  // ==========================================
  // CACHE MANAGEMENT
  // ==========================================
  
  static bool _isCacheValid() {
    if (_cachedBaseUrl == null || _cacheExpiry == null) {
      return false;
    }
    return DateTime.now().isBefore(_cacheExpiry!);
  }
  
  static void clearCache() {
    print('[NetworkConfig] 🗑️ Clearing cache');
    _cachedBaseUrl = null;
    _cacheExpiry = null;
  }
  
  static void setCachedUrl(String url) {
    print('[NetworkConfig] 📌 Manually setting URL: $url');
    _cachedBaseUrl = url;
    _cacheExpiry = DateTime.now().add(_cacheValidDuration);
  }
  
  // ==========================================
  // DIAGNOSTIC METHODS
  // ==========================================
  
  static Future<Map<String, dynamic>> runDiagnostic() async {
    print('[NetworkConfig] 🔍 Running comprehensive diagnostic...');
    
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'platform': _getPlatformName(),
      'cached_url': _cachedBaseUrl,
      'cache_valid': _isCacheValid(),
      'server_port': _serverPort,
      'tests': <String, dynamic>{},
    };
    
    final urlsToTest = [
      {'name': 'Android Emulator', 'url': _androidEmulatorUrl},
      {'name': 'Network IP', 'url': _networkIpUrl},
      {'name': 'Localhost Alt', 'url': _localhostAltUrl},
      {'name': 'Localhost', 'url': _localhostUrl},
    ];
    
    for (final urlInfo in urlsToTest) {
      final name = urlInfo['name']!;
      final url = urlInfo['url']!;
      
      final testResult = await _detailedTest(url);
      results['tests'][name] = testResult;
    }
    
    // Tìm URL tốt nhất
    String? bestUrl;
    int bestTime = 999999;
    
    for (final entry in results['tests'].entries) {
      final test = entry.value as Map<String, dynamic>;
      if (test['success'] == true) {
        final time = test['response_time_ms'] as int? ?? 999999;
        if (time < bestTime) {
          bestTime = time;
          bestUrl = test['url'];
        }
      }
    }
    
    results['recommended'] = {
      'url': bestUrl,
      'time_ms': bestUrl != null ? bestTime : null,
      'platform_default': _isAndroidEmulator ? _androidEmulatorUrl : 
                          _isRealDevice ? _networkIpUrl : _localhostUrl,
    };
    
    return results;
  }
  
  static Future<Map<String, dynamic>> _detailedTest(String url) async {
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
        },
      ).timeout(const Duration(seconds: 8)); // Tăng timeout cho diagnostic
      
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
          };
        } catch (e) {
          result['server_info'] = 'Response OK but not JSON';
        }
      }
      
    } catch (e) {
      result['error'] = e.toString();
    }
    
    return result;
  }
  
  // ==========================================
  // HELPER METHODS
  // ==========================================
  
  static String _getPlatformName() {
    if (_isAndroidEmulator) return 'android_emulator';
    if (_isRealDevice) return 'real_device';
    if (_isWeb) return 'web';
    return 'unknown';
  }
  
  static void printDiagnostic() async {
    if (!kDebugMode) return;
    
    print('');
    print('=== 🌐 NETWORK CONFIG DIAGNOSTIC ===');
    print('Platform: ${_getPlatformName()}');
    print('Server Port: $_serverPort');
    print('Cached URL: $_cachedBaseUrl');
    print('Cache Valid: ${_isCacheValid()}');
    print('');
    
    final diagnostic = await runDiagnostic();
    final tests = diagnostic['tests'] as Map<String, dynamic>;
    
    print('📊 Connection Tests:');
    for (final entry in tests.entries) {
      final name = entry.key;
      final test = entry.value as Map<String, dynamic>;
      final status = test['success'] ? '✅' : '❌';
      final time = test['response_time_ms']?.toString() ?? 'N/A';
      final url = test['url'];
      
      print('$status $name: $url (${time}ms)');
      if (test['error'] != null) {
        print('   Error: ${test['error']}');
      }
    }
    
    final recommended = diagnostic['recommended'] as Map<String, dynamic>;
    if (recommended['url'] != null) {
      print('');
      print('💡 Recommended: ${recommended['url']} (${recommended['time_ms']}ms)');
    } else {
      print('');
      print('⚠️ No working URLs found!');
    }
    
    print('🎯 Platform Default: ${recommended['platform_default']}');
    print('===================================');
    print('');
  }
  
  // Force discovery với logging
  static Future<String> forceDiscovery() async {
    clearCache();
    print('[NetworkConfig] 🔄 Forcing URL discovery...');
    
    final url = await _discoverBestUrl();
    _cachedBaseUrl = url;
    _cacheExpiry = DateTime.now().add(_cacheValidDuration);
    
    print('[NetworkConfig] ✅ Forced discovery result: $url');
    return url;
  }
  
  // Get current status
  static Map<String, dynamic> getStatus() {
    return {
      'platform': _getPlatformName(),
      'cached_url': _cachedBaseUrl,
      'cache_valid': _isCacheValid(),
      'cache_expiry': _cacheExpiry?.toIso8601String(),
      'server_port': _serverPort,
      'available_urls': {
        'android_emulator': _androidEmulatorUrl,
        'network_ip': _networkIpUrl,
        'localhost': _localhostUrl,
        'localhost_alt': _localhostAltUrl,
      },
    };
  }
  
  // ==========================================
  // UTILITY METHODS
  // ==========================================
  
  // Test specific URL manually
  static Future<bool> testSpecificUrl(String url) async {
    return await _testConnection(url);
  }
  
  // Set manual override (for testing)
  static void setManualOverride(String baseUrl) {
    print('[NetworkConfig] 🔧 Manual override set: $baseUrl');
    _cachedBaseUrl = baseUrl;
    _cacheExpiry = DateTime.now().add(const Duration(hours: 1)); // Longer cache for manual override
  }
  
  // Check if backend is reachable
  static Future<bool> isBackendReachable() async {
    if (_cachedBaseUrl == null) {
      await _discoverBestUrl();
    }
    
    return _cachedBaseUrl != null && await _testConnection(_cachedBaseUrl!);
  }
  
  // Manual IP override for troubleshooting
  static void setManualIP(String ip) {
    final manualUrl = 'http://$ip:$_serverPort';
    print('[NetworkConfig] 🔧 Setting manual IP override: $manualUrl');
    _cachedBaseUrl = manualUrl;
    _cacheExpiry = DateTime.now().add(const Duration(hours: 1));
  }
  
  // Quick connectivity test
  static Future<bool> quickConnectivityTest() async {
    try {
      final testUrls = [
        _androidEmulatorUrl,
        _networkIpUrl,
        _localhostUrl,
      ];
      
      for (final url in testUrls) {
        if (await _testConnection(url)) {
          print('[NetworkConfig] ✅ Quick test passed for: $url');
          _cachedBaseUrl = url;
          _cacheExpiry = DateTime.now().add(_cacheValidDuration);
          return true;
        }
      }
      
      print('[NetworkConfig] ❌ Quick connectivity test failed for all URLs');
      return false;
    } catch (e) {
      print('[NetworkConfig] ❌ Quick connectivity test error: $e');
      return false;
    }
  }
}