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

  void initialize({String? authToken}) {
    _client = http.Client();
    _authToken = authToken;
    
    if (ApiConfig.enableApiLogging) {
      debugPrint('[HttpService] Initialized with base URL: ${ApiConfig.baseUrl}');
      debugPrint('[HttpService] Auth token: ${_authToken != null ? 'Present' : 'Not set'}');
    }
  }

  void setAuthToken(String? token) {
    _authToken = token;
    if (ApiConfig.enableApiLogging) {
      debugPrint('[HttpService] Auth token updated: ${token != null ? 'Set' : 'Cleared'}');
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

  // GET request
  Future<HttpResponse> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParameters);
      final requestHeaders = {..._defaultHeaders, ...?headers};

      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpService] GET: $uri');
        debugPrint('[HttpService] Headers: $requestHeaders');
      }

      final response = await _client
          .get(uri, headers: requestHeaders)
          .timeout(Duration(seconds: ApiConfig.receiveTimeout));

      return _handleResponse(response, 'GET', uri.toString());
    } catch (e) {
      return _handleError(e, 'GET', endpoint);
    }
  }

  // POST request
  Future<HttpResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final requestHeaders = {..._defaultHeaders, ...?headers};
      final requestBody = body != null ? jsonEncode(body) : null;

      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpService] POST: $uri');
        debugPrint('[HttpService] Headers: $requestHeaders');
        debugPrint('[HttpService] Body: $requestBody');
      }

      final response = await _client
          .post(uri, headers: requestHeaders, body: requestBody)
          .timeout(Duration(seconds: ApiConfig.sendTimeout));

      return _handleResponse(response, 'POST', uri.toString());
    } catch (e) {
      return _handleError(e, 'POST', endpoint);
    }
  }

  // PUT request
  Future<HttpResponse> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final requestHeaders = {..._defaultHeaders, ...?headers};
      final requestBody = body != null ? jsonEncode(body) : null;

      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpService] PUT: $uri');
        debugPrint('[HttpService] Headers: $requestHeaders');
        debugPrint('[HttpService] Body: $requestBody');
      }

      final response = await _client
          .put(uri, headers: requestHeaders, body: requestBody)
          .timeout(Duration(seconds: ApiConfig.sendTimeout));

      return _handleResponse(response, 'PUT', uri.toString());
    } catch (e) {
      return _handleError(e, 'PUT', endpoint);
    }
  }

  // DELETE request
  Future<HttpResponse> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final requestHeaders = {..._defaultHeaders, ...?headers};

      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpService] DELETE: $uri');
        debugPrint('[HttpService] Headers: $requestHeaders');
      }

      final response = await _client
          .delete(uri, headers: requestHeaders)
          .timeout(Duration(seconds: ApiConfig.receiveTimeout));

      return _handleResponse(response, 'DELETE', uri.toString());
    } catch (e) {
      return _handleError(e, 'DELETE', endpoint);
    }
  }

  // Multipart request for file uploads
  Future<HttpResponse> multipart(
    String endpoint, {
    required Map<String, String> fields,
    Map<String, File>? files,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final request = http.MultipartRequest('POST', uri);
      
      // Add headers
      request.headers.addAll({..._uploadHeaders, ...?headers});
      
      // Add fields
      request.fields.addAll(fields);
      
      // Add files
      if (files != null) {
        for (final entry in files.entries) {
          final file = entry.value;
          final multipartFile = await http.MultipartFile.fromPath(
            entry.key,
            file.path,
          );
          request.files.add(multipartFile);
        }
      }

      if (ApiConfig.enableApiLogging) {
        debugPrint('[HttpService] MULTIPART: $uri');
        debugPrint('[HttpService] Headers: ${request.headers}');
        debugPrint('[HttpService] Fields: ${request.fields}');
        debugPrint('[HttpService] Files: ${files?.keys.toList()}');
      }

      final streamedResponse = await request.send()
          .timeout(Duration(seconds: ApiConfig.sendTimeout));
      
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response, 'MULTIPART', uri.toString());
    } catch (e) {
      return _handleError(e, 'MULTIPART', endpoint);
    }
  }

  // Helper methods
  Uri _buildUri(String endpoint, [Map<String, String>? queryParameters]) {
    final fullUrl = endpoint.startsWith('http') ? endpoint : '${ApiConfig.baseUrl}$endpoint';
    return Uri.parse(fullUrl).replace(queryParameters: queryParameters);
  }

  HttpResponse _handleResponse(http.Response response, String method, String url) {
    if (ApiConfig.enableApiLogging) {
      debugPrint('[HttpService] $method Response: ${response.statusCode}');
      debugPrint('[HttpService] Response body: ${response.body}');
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
      errorMessage = 'No internet connection';
    } else if (error is TimeoutException) {
      errorMessage = 'Request timeout';
    } else if (error is FormatException) {
      errorMessage = 'Invalid response format';
    }

    if (ApiConfig.enableApiLogging) {
      debugPrint('[HttpService] $method Error for $endpoint: $error');
    }

    return HttpResponse(
      statusCode: 0,
      body: jsonEncode({'error': errorMessage}),
      headers: {},
      isSuccess: false,
      error: error.toString(),
    );
  }

  void dispose() {
    _client.close();
  }
}

// Response wrapper class
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
      return null;
    }
  }

  List<dynamic>? get jsonList {
    try {
      return jsonDecode(body) as List<dynamic>?;
    } catch (e) {
      return null;
    }
  }

  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isServerError => statusCode >= 500;
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  @override
  String toString() {
    return 'HttpResponse(statusCode: $statusCode, isSuccess: $isSuccess, body: $body)';
  }
}