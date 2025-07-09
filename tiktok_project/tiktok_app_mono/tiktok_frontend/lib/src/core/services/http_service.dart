// tiktok_frontend/lib/src/core/services/http_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../constants/app_constants.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

  // HTTP Client with timeout configuration
  late final http.Client _client;
  String? _authToken;
  bool _initialized = false;

  Future<void> initialize({String? authToken}) async {
    if (_initialized) {
      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpService] Already initialized, updating auth token only');
      }
      _authToken = authToken;
      return;
    }

    _client = http.Client();
    _authToken = authToken;
    _initialized = true;
    
    // Initialize API Config first
    await ApiConfig.initialize();
    
    if (ApiConfig.enableApiLogging) {
      debugPrint('[HttpService] ✅ Initialized with base URL: ${ApiConfig.baseUrl}');
      debugPrint('[HttpService] Auth token: ${_authToken != null ? 'Present' : 'Not set'}');
      debugPrint('[HttpService] Platform: ${ApiConfig.isAndroidEmulator ? 'Android Emulator' : ApiConfig.isRealDevice ? 'Real Device' : 'Web'}');
    }

    // Run quick health check
    final isHealthy = await ApiConfig.quickHealthCheck();
    if (ApiConfig.enableApiLogging) {
      debugPrint('[HttpService] Initial health check: ${isHealthy ? '✅ Healthy' : '❌ Failed'}');
    }

    if (!isHealthy && ApiConfig.enableNetworkDiagnostics) {
      debugPrint('[HttpService] ⚠️ Health check failed, running diagnostic...');
      await ApiConfig.printNetworkDiagnostic();
    }
  }

  void setAuthToken(String? token) {
    _authToken = token;
    if (ApiConfig.enableApiLogging) {
      debugPrint('[HttpService] 🔑 Auth token updated: ${token != null ? 'Set' : 'Cleared'}');
    }
  }

  Map<String, String> get _defaultHeaders {
    final headers = Map<String, String>.from(ApiConfig.defaultHeaders);
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Map<String, String> get _uploadHeaders {
    final headers = Map<String, String>.from(ApiConfig.uploadHeaders);
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // GET request with automatic URL discovery
  Future<HttpResponse> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    bool enableAutoDiscovery = true,
  }) async {
    await _ensureInitialized();
    
    try {
      final uri = await _buildUri(endpoint, queryParameters, enableAutoDiscovery);
      final requestHeaders = {..._defaultHeaders, ...?headers};

      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpService] 📡 GET: $uri');
        debugPrint('[HttpService] Headers: $requestHeaders');
      }

      final response = await _client
          .get(uri, headers: requestHeaders)
          .timeout(Duration(seconds: ApiConfig.receiveTimeout));

      return _handleResponse(response, 'GET', uri.toString());
    } catch (e) {
      if (enableAutoDiscovery && _shouldRetryWithDiscovery(e)) {
        debugPrint('[HttpService] 🔄 Retrying GET with URL discovery...');
        await ApiConfig.refreshUrlDiscovery();
        return await get(endpoint, queryParameters: queryParameters, headers: headers, enableAutoDiscovery: false);
      }
      return _handleError(e, 'GET', endpoint);
    }
  }

  // POST request with automatic URL discovery
  Future<HttpResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool enableAutoDiscovery = true,
  }) async {
    await _ensureInitialized();
    
    try {
      final uri = await _buildUri(endpoint, null, enableAutoDiscovery);
      final requestHeaders = {..._defaultHeaders, ...?headers};
      final requestBody = body != null ? jsonEncode(body) : null;

      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpService] 📤 POST: $uri');
        debugPrint('[HttpService] Headers: $requestHeaders');
        if (requestBody != null && requestBody.length < 500) {
          debugPrint('[HttpService] Body: $requestBody');
        } else if (requestBody != null) {
          debugPrint('[HttpService] Body: ${requestBody.substring(0, 500)}... (truncated)');
        }
      }

      final response = await _client
          .post(uri, headers: requestHeaders, body: requestBody)
          .timeout(Duration(seconds: ApiConfig.sendTimeout));

      return _handleResponse(response, 'POST', uri.toString());
    } catch (e) {
      if (enableAutoDiscovery && _shouldRetryWithDiscovery(e)) {
        debugPrint('[HttpService] 🔄 Retrying POST with URL discovery...');
        await ApiConfig.refreshUrlDiscovery();
        return await post(endpoint, body: body, headers: headers, enableAutoDiscovery: false);
      }
      return _handleError(e, 'POST', endpoint);
    }
  }

  // PUT request with automatic URL discovery
  Future<HttpResponse> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool enableAutoDiscovery = true,
  }) async {
    await _ensureInitialized();
    
    try {
      final uri = await _buildUri(endpoint, null, enableAutoDiscovery);
      final requestHeaders = {..._defaultHeaders, ...?headers};
      final requestBody = body != null ? jsonEncode(body) : null;

      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpService] 🔄 PUT: $uri');
        debugPrint('[HttpService] Headers: $requestHeaders');
        if (requestBody != null && requestBody.length < 500) {
          debugPrint('[HttpService] Body: $requestBody');
        }
      }

      final response = await _client
          .put(uri, headers: requestHeaders, body: requestBody)
          .timeout(Duration(seconds: ApiConfig.sendTimeout));

      return _handleResponse(response, 'PUT', uri.toString());
    } catch (e) {
      if (enableAutoDiscovery && _shouldRetryWithDiscovery(e)) {
        debugPrint('[HttpService] 🔄 Retrying PUT with URL discovery...');
        await ApiConfig.refreshUrlDiscovery();
        return await put(endpoint, body: body, headers: headers, enableAutoDiscovery: false);
      }
      return _handleError(e, 'PUT', endpoint);
    }
  }

  // DELETE request with automatic URL discovery
  Future<HttpResponse> delete(
    String endpoint, {
    Map<String, String>? headers,
    bool enableAutoDiscovery = true,
  }) async {
    await _ensureInitialized();
    
    try {
      final uri = await _buildUri(endpoint, null, enableAutoDiscovery);
      final requestHeaders = {..._defaultHeaders, ...?headers};

      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpService] 🗑️ DELETE: $uri');
        debugPrint('[HttpService] Headers: $requestHeaders');
      }

      final response = await _client
          .delete(uri, headers: requestHeaders)
          .timeout(Duration(seconds: ApiConfig.receiveTimeout));

      return _handleResponse(response, 'DELETE', uri.toString());
    } catch (e) {
      if (enableAutoDiscovery && _shouldRetryWithDiscovery(e)) {
        debugPrint('[HttpService] 🔄 Retrying DELETE with URL discovery...');
        await ApiConfig.refreshUrlDiscovery();
        return await delete(endpoint, headers: headers, enableAutoDiscovery: false);
      }
      return _handleError(e, 'DELETE', endpoint);
    }
  }

  // Multipart request for file uploads with enhanced error handling
  Future<HttpResponse> multipart(
    String endpoint, {
    required Map<String, String> fields,
    Map<String, File>? files,
    Map<String, String>? headers,
    bool enableAutoDiscovery = true,
  }) async {
    await _ensureInitialized();
    
    try {
      final uri = await _buildUri(endpoint, null, enableAutoDiscovery);
      final request = http.MultipartRequest('POST', uri);
      
      // Add headers
      request.headers.addAll({..._uploadHeaders, ...?headers});
      
      // Add fields
      request.fields.addAll(fields);
      
      // Add files with validation
      if (files != null) {
        for (final entry in files.entries) {
          final file = entry.value;
          
          // Validate file exists
          if (!await file.exists()) {
            throw Exception('File does not exist: ${file.path}');
          }
          
          // Validate file size
          final fileSize = await file.length();
          if (!ApiConfig.isValidFileSize(fileSize, isVideo: true)) {
            throw Exception('File size exceeds limit: ${fileSize / (1024 * 1024)}MB');
          }
          
          final multipartFile = await http.MultipartFile.fromPath(
            entry.key,
            file.path,
          );
          request.files.add(multipartFile);
        }
      }

      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpService] 📎 MULTIPART: $uri');
        debugPrint('[HttpService] Headers: ${request.headers}');
        debugPrint('[HttpService] Fields: ${request.fields}');
        debugPrint('[HttpService] Files: ${files?.keys.toList()}');
        if (files != null) {
          for (final entry in files.entries) {
            final fileSize = await entry.value.length();
            debugPrint('[HttpService] File ${entry.key}: ${fileSize / (1024 * 1024)} MB');
          }
        }
      }

      final streamedResponse = await request.send()
          .timeout(Duration(seconds: ApiConfig.sendTimeout));
      
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response, 'MULTIPART', uri.toString());
    } catch (e) {
      if (enableAutoDiscovery && _shouldRetryWithDiscovery(e)) {
        debugPrint('[HttpService] 🔄 Retrying MULTIPART with URL discovery...');
        await ApiConfig.refreshUrlDiscovery();
        return await multipart(endpoint, fields: fields, files: files, headers: headers, enableAutoDiscovery: false);
      }
      return _handleError(e, 'MULTIPART', endpoint);
    }
  }

  // Helper methods
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<Uri> _buildUri(String endpoint, [Map<String, String>? queryParameters, bool useDiscovery = true]) async {
    String fullUrl;
    
    if (endpoint.startsWith('http')) {
      fullUrl = endpoint;
    } else {
      // Use discovered URL if available and valid
      if (useDiscovery) {
        final baseUrl = await ApiConfig.discoverBestUrl();
        fullUrl = '$baseUrl$endpoint';
      } else {
        fullUrl = '${ApiConfig.baseUrl}$endpoint';
      }
    }
    
    return Uri.parse(fullUrl).replace(queryParameters: queryParameters);
  }

  bool _shouldRetryWithDiscovery(dynamic error) {
    if (error is SocketException) {
      // Connection refused, host not found, etc.
      return true;
    }
    if (error is TimeoutException) {
      // Timeout might indicate wrong URL
      return true;
    }
    if (error.toString().contains('Connection refused') ||
        error.toString().contains('Failed host lookup') ||
        error.toString().contains('Network is unreachable')) {
      return true;
    }
    return false;
  }

  HttpResponse _handleResponse(http.Response response, String method, String url) {
    if (ApiConfig.enableApiLogging) {
      debugPrint('[HttpService] $method Response: ${response.statusCode}');
      if (response.body.length < 1000) {
        debugPrint('[HttpService] Response body: ${response.body}');
      } else {
        debugPrint('[HttpService] Response body: ${response.body.substring(0, 1000)}... (truncated)');
      }
    }

    return HttpResponse(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
      isSuccess: response.statusCode >= 200 && response.statusCode < 300,
    );
  }

  HttpResponse _handleError(dynamic error, String method, String endpoint) {
    String errorMessage = AppConstants.networkError;
    
    if (error is SocketException) {
      if (error.message.contains('Connection refused')) {
        errorMessage = 'Server is not running or not accessible';
      } else if (error.message.contains('Failed host lookup')) {
        errorMessage = 'Unable to connect to server. Check your network connection.';
      } else {
        errorMessage = 'Network connection failed. Please check your internet connection.';
      }
    } else if (error is TimeoutException) {
      errorMessage = 'Request timeout. Server is taking too long to respond.';
    } else if (error is FormatException) {
      errorMessage = 'Invalid response format from server';
    } else if (error is HttpException) {
      errorMessage = 'HTTP error: ${error.message}';
    }

    if (ApiConfig.enableApiLogging) {
      debugPrint('[HttpService] ❌ $method Error for $endpoint: $error');
      debugPrint('[HttpService] Error type: ${error.runtimeType}');
      debugPrint('[HttpService] Error message: $errorMessage');
    }

    return HttpResponse(
      statusCode: 0,
      body: jsonEncode({'error': errorMessage}),
      headers: {},
      isSuccess: false,
      error: error.toString(),
    );
  }

  // Enhanced health check with retry logic
  Future<bool> healthCheck({int maxRetries = 3}) async {
    await _ensureInitialized();
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (ApiConfig.enableApiLogging) {
          debugPrint('[HttpService] 🏥 Health check attempt $attempt/$maxRetries');
        }
        
        final response = await get('/health', enableAutoDiscovery: attempt == 1);
        
        if (response.isSuccess) {
          if (ApiConfig.enableApiLogging) {
            debugPrint('[HttpService] ✅ Health check passed');
          }
          return true;
        } else {
          if (ApiConfig.enableApiLogging) {
            debugPrint('[HttpService] ❌ Health check failed: ${response.statusCode}');
          }
        }
      } catch (e) {
        if (ApiConfig.enableApiLogging) {
          debugPrint('[HttpService] ❌ Health check error: $e');
        }
      }
      
      // Wait before retry (except on last attempt)
      if (attempt < maxRetries) {
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    
    return false;
  }

  // Run comprehensive network diagnostic
  Future<Map<String, dynamic>> runNetworkDiagnostic() async {
    await _ensureInitialized();
    
    final diagnostic = await ApiConfig.testConnection();
    
    // Add HTTP service specific tests
    diagnostic['http_service'] = {
      'initialized': _initialized,
      'auth_token_present': _authToken != null,
      'client_available': true,
    };
    
    // Test health endpoint specifically
    final healthResult = await healthCheck(maxRetries: 1);
    diagnostic['health_check'] = {
      'success': healthResult,
      'endpoint': '${ApiConfig.baseUrl}/health',
    };
    
    return diagnostic;
  }

  void dispose() {
    _client.close();
    _initialized = false;
    if (ApiConfig.enableApiLogging) {
      debugPrint('[HttpService] 🗑️ Disposed');
    }
  }
}

// Enhanced Response wrapper class
class HttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final bool isSuccess;
  final String? error;

  HttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.isSuccess,
    this.error,
  });

  Map<String, dynamic>? get json {
    try {
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (e) {
      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpResponse] JSON decode error: $e');
        debugPrint('[HttpResponse] Body: $body');
      }
      return null;
    }
  }

  List<dynamic>? get jsonList {
    try {
      return jsonDecode(body) as List<dynamic>?;
    } catch (e) {
      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpResponse] JSON list decode error: $e');
      }
      return null;
    }
  }

  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isServerError => statusCode >= 500;
  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isNetworkError => statusCode == 0;

  String get errorMessage {
    if (error != null) return error!;
    if (json != null && json!['error'] != null) return json!['error'].toString();
    if (!isSuccess) return 'Request failed with status code $statusCode';
    return '';
  }

  @override
  String toString() {
    return 'HttpResponse(statusCode: $statusCode, isSuccess: $isSuccess, body: ${body.length > 200 ? body.substring(0, 200) + '...' : body})';
  }
}