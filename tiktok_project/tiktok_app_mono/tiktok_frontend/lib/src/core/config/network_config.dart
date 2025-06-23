// tiktok_frontend/lib/src/core/config/network_config.dart
import 'dart:convert';
import 'dart:io' show Platform, NetworkInterface, InternetAddress, InternetAddressType;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class NetworkConfig {
  static const String _backendPort = '8080';
  static const List<String> _possibleIPs = [
    '10.21.12.255',  // IP hiện tại
    '192.168.1.100', // IP backup khả năng cao
    '192.168.0.100', // IP backup khả năng cao
    '10.0.0.100',    // IP backup
  ];
  
  static String? _cachedBackendIP;
  static DateTime? _lastChecked;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  // Tự động tìm IP backend khả dụng
  static Future<String> getBackendIP() async {
    // Sử dụng cache nếu còn hiệu lực
    if (_cachedBackendIP != null && 
        _lastChecked != null && 
        DateTime.now().difference(_lastChecked!) < _cacheTimeout) {
      print('[NetworkConfig] Using cached IP: $_cachedBackendIP');
      return _cachedBackendIP!;
    }

    if (kIsWeb) {
      _cachedBackendIP = 'localhost';
      _lastChecked = DateTime.now();
      return 'localhost';
    }

    // Thử từng IP trong danh sách
    for (String ip in _possibleIPs) {
      if (await _testBackendConnection(ip)) {
        _cachedBackendIP = ip;
        _lastChecked = DateTime.now();
        print('[NetworkConfig] ✅ Found working backend IP: $ip');
        return ip;
      }
    }

    // Thử lấy IP từ network interface của laptop
    try {
      final detectedIP = await _detectLaptopIP();
      if (detectedIP != null && await _testBackendConnection(detectedIP)) {
        _cachedBackendIP = detectedIP;
        _lastChecked = DateTime.now();
        print('[NetworkConfig] ✅ Detected working IP: $detectedIP');
        return detectedIP;
      }
    } catch (e) {
      print('[NetworkConfig] Error detecting IP: $e');
    }

    // Android emulator fallback
    if (!kIsWeb && Platform.isAndroid && _isAndroidEmulator()) {
      _cachedBackendIP = '10.0.2.2';
      _lastChecked = DateTime.now();
      return '10.0.2.2';
    }

    // Fallback cuối cùng
    print('[NetworkConfig] ⚠️ No working IP found, using first IP as fallback');
    _cachedBackendIP = _possibleIPs.first;
    _lastChecked = DateTime.now();
    return _possibleIPs.first;
  }

  // Test kết nối đến backend
  static Future<bool> _testBackendConnection(String ip) async {
    try {
      final healthUrl = Uri.parse('http://$ip:$_backendPort/health');
      print('[NetworkConfig] Testing: $healthUrl');
      
      final response = await http.get(healthUrl).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('[NetworkConfig] Failed to connect to $ip: $e');
      return false;
    }
  }

  // Detect IP của laptop từ network interfaces
  static Future<String?> _detectLaptopIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      
      for (NetworkInterface interface in interfaces) {
        // Tìm WiFi hoặc Ethernet interface
        if (interface.name.toLowerCase().contains('wi-fi') ||
            interface.name.toLowerCase().contains('wireless') ||
            interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('ethernet')) {
          
          for (InternetAddress address in interface.addresses) {
            if (address.type == InternetAddressType.IPv4 && 
                !address.isLoopback &&
                !address.isLinkLocal) {
              
              // Kiểm tra subnet phổ biến
              final ip = address.address;
              if (ip.startsWith('192.168.') || 
                  ip.startsWith('10.') || 
                  ip.startsWith('172.')) {
                print('[NetworkConfig] Detected potential laptop IP: $ip');
                return ip;
              }
            }
          }
        }
      }
    } catch (e) {
      print('[NetworkConfig] Error getting network interfaces: $e');
    }
    return null;
  }

  // Kiểm tra Android emulator
  static bool _isAndroidEmulator() {
    try {
      return Platform.environment.containsKey('ANDROID_EMULATOR') ||
             Platform.environment['ANDROID_EMULATOR'] == 'true';
    } catch (e) {
      return false;
    }
  }

  // Clear cache để force re-detect
  static void clearCache() {
    _cachedBackendIP = null;
    _lastChecked = null;
    print('[NetworkConfig] Cache cleared, will re-detect IP on next call');
  }

  // Get full base URL cho services
  static Future<String> getBaseUrl(String apiPath) async {
    final ip = await getBackendIP();
    return 'http://$ip:$_backendPort$apiPath';
  }

  // Get file base URL
  static Future<String> getFileBaseUrl() async {
    final ip = await getBackendIP();
    return 'http://$ip:$_backendPort';
  }
}

// Extension để dễ sử dụng trong services
extension NetworkConfigExtension on Object {
  Future<String> getApiUrl(String path) => NetworkConfig.getBaseUrl(path);
  Future<String> getFileUrl() => NetworkConfig.getFileBaseUrl();
}