// tiktok_backend/lib/src/features/videos/video_routes.dart - FIXED VERSION
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

  // GET SINGLE VIDEO BY ID - NEW ROUTE
  router.get('/<videoId>', (Request request, String videoId) async {
    print('[VideoRoutes] Get video by ID route hit with videoId: $videoId');

    if (videoId.isEmpty) {
      return Response(400,
          body: jsonEncode({
            'error': 'Video ID is required',
            'receivedVideoId': videoId,
            'path': request.url.path,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      return await VideoController.getVideoByIdHandler(request, videoId);
    } catch (e, stackTrace) {
      print('[VideoRoutes] Error in get video by ID route: $e');
      print('[VideoRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // Like route với parameter đúng cách
  router.post('/<videoId>/like', (Request request, String videoId) async {
    print('[VideoRoutes] Like route hit with videoId: $videoId');

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
      final requestBody = await request.readAsString();
      print('[VideoRoutes] Request body: $requestBody');

      if (requestBody.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Request body is empty'}),
            headers: {'Content-Type': 'application/json'});
      }

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
      final requestBody = await request.readAsString();
      print('[VideoRoutes] Request body: $requestBody');

      if (requestBody.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Request body is empty'}),
            headers: {'Content-Type': 'application/json'});
      }

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
        'GET /api/videos/{videoId}',
        'POST /api/videos/{videoId}/like',
        'POST /api/videos/{videoId}/save',
        'GET /api/videos/debug/info',
      ],
      'examples': [
        'GET /api/videos/683c24fffdf60af9cddfb22a',
        'POST /api/videos/683c24fffdf60af9cddfb22a/like',
        'POST /api/videos/683c24fffdf60af9cddfb22a/save'
      ]
    }), headers: {'Content-Type': 'application/json'});
  });

  return router;
}