// tiktok_backend/lib/src/features/videos/video_routes.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'controllers/video_controller.dart';

Router createVideoRoutes() {
  final router = Router();

  // Upload route
  router.post('/upload', VideoController.uploadVideoHandler);
  
  // Feed route
  router.get('/feed', VideoController.getFeedVideosHandler);

  // Like route với parameter đúng cách
  router.post('/<videoId>/like', (Request request, String videoId) async {
    print('[VideoRoutes] Like route hit with videoId: $videoId');
    print('[VideoRoutes] Request method: ${request.method}');
    print('[VideoRoutes] Request URL: ${request.url}');

    if (videoId.isEmpty) {
      print('[VideoRoutes] Error: videoId is empty');
      return Response(400,
          body: jsonEncode({
            'error': 'Video ID is required - empty videoId',
            'receivedVideoId': videoId,
            'path': request.url.path,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      // Đọc body từ request
      final requestBody = await request.readAsString();
      print('[VideoRoutes] Request body: $requestBody');

      if (requestBody.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Request body is empty'}),
            headers: {'Content-Type': 'application/json'});
      }

      // Parse JSON để validate
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(requestBody);
      } catch (e) {
        return Response(400,
            body: jsonEncode({'error': 'Invalid JSON in request body: $e'}),
            headers: {'Content-Type': 'application/json'});
      }

      final userIdString = payload['userId'] as String?;
      if (userIdString == null || userIdString.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'userId is required in request body'}),
            headers: {'Content-Type': 'application/json'});
      }

      print('[VideoRoutes] Calling VideoController.toggleLikeVideoHandler with videoId: $videoId, userId: $userIdString');

      // Gọi trực tiếp VideoController với parameters
      return await VideoController.toggleLikeVideoHandler(request, videoId, userIdString);

    } catch (e, stackTrace) {
      print('[VideoRoutes] Error in like route: $e');
      print('[VideoRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // Save route với parameter đúng cách
  router.post('/<videoId>/save', (Request request, String videoId) async {
    print('[VideoRoutes] Save route hit with videoId: $videoId');
    print('[VideoRoutes] Request method: ${request.method}');
    print('[VideoRoutes] Request URL: ${request.url}');

    if (videoId.isEmpty) {
      print('[VideoRoutes] Error: videoId is empty');
      return Response(400,
          body: jsonEncode({
            'error': 'Video ID is required - empty videoId',
            'receivedVideoId': videoId,
            'path': request.url.path,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      // Đọc body từ request
      final requestBody = await request.readAsString();
      print('[VideoRoutes] Request body: $requestBody');

      if (requestBody.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Request body is empty'}),
            headers: {'Content-Type': 'application/json'});
      }

      // Parse JSON để validate
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(requestBody);
      } catch (e) {
        return Response(400,
            body: jsonEncode({'error': 'Invalid JSON in request body: $e'}),
            headers: {'Content-Type': 'application/json'});
      }

      final userIdString = payload['userId'] as String?;
      if (userIdString == null || userIdString.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'userId is required in request body'}),
            headers: {'Content-Type': 'application/json'});
      }

      print('[VideoRoutes] Calling VideoController.toggleSaveVideoHandler with videoId: $videoId, userId: $userIdString');

      // Gọi trực tiếp VideoController với parameters
      return await VideoController.toggleSaveVideoHandler(request, videoId, userIdString);

    } catch (e, stackTrace) {
      print('[VideoRoutes] Error in save route: $e');
      print('[VideoRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // CORS handlers
  router.options('/<path|.*>', (Request request) async {
    return Response.ok('', headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
      'Access-Control-Max-Age': '86400',
    });
  });

  // Debug routes
  router.get('/debug/info', (Request request) async {
    return Response.ok(jsonEncode({
      'message': 'Video routes debug info',
      'availableRoutes': [
        'POST /api/videos/upload',
        'GET /api/videos/feed',
        'POST /api/videos/{videoId}/like',
        'POST /api/videos/{videoId}/save',
        'GET /api/videos/debug/info',
        'GET /api/videos/debug/{videoId}/like',
        'GET /api/videos/debug/{videoId}/save'
      ],
      'examples': [
        'POST /api/videos/683c24fffdf60af9cddfb22a/like',
        'POST /api/videos/683c24fffdf60af9cddfb22a/save'
      ]
    }), headers: {'Content-Type': 'application/json'});
  });

  router.get('/debug/<videoId>/like', (Request request, String videoId) async {
    return Response.ok(jsonEncode({
      'message': 'Debug: Like route is working',
      'videoId': videoId,
      'method': 'GET',
      'fullUrl': request.url.toString(),
      'pathSegments': request.url.pathSegments,
    }), headers: {'Content-Type': 'application/json'});
  });

  router.get('/debug/<videoId>/save', (Request request, String videoId) async {
    return Response.ok(jsonEncode({
      'message': 'Debug: Save route is working',
      'videoId': videoId,
      'method': 'GET',
      'fullUrl': request.url.toString(),
      'pathSegments': request.url.pathSegments,
    }), headers: {'Content-Type': 'application/json'});
  });

  // Catch-all route cho debug
  router.all('/<path|.*>', (Request request) async {
    print('[VideoRoutes] Unmatched route: ${request.method} ${request.url.path}');
    return Response(404, 
      body: jsonEncode({
        'error': 'Route not found',
        'method': request.method,
        'path': request.url.path,
        'pathSegments': request.url.pathSegments,
        'availableRoutes': [
          'POST /api/videos/upload',
          'GET /api/videos/feed',
          'POST /api/videos/{videoId}/like',
          'POST /api/videos/{videoId}/save'
        ]
      }), 
      headers: {'Content-Type': 'application/json'}
    );
  });

  return router;
}