// File: tiktok_project/tiktok_app_mono/tiktok_backend/lib/src/features/videos/video_routes.dart
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

  // Get single video by ID
  router.get('/<videoId>', (Request request, String videoId) async {
    print('[VideoRoutes] Get video by ID route hit with videoId: $videoId');

    if (videoId.isEmpty || videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
      return Response(400,
          body: jsonEncode({
            'error': 'Invalid video ID',
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

  // Like video route
  router.post('/<videoId>/like', (Request request, String videoId) async {
    print('[VideoRoutes] Like route hit with videoId: $videoId');

    if (videoId.isEmpty || videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
      print('[VideoRoutes] Error: Invalid videoId');
      return Response(400,
          body: jsonEncode({
            'error': 'Invalid video ID',
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

  // Share video route
  router.post('/<videoId>/share', (Request request, String videoId) async {
    print('[VideoRoutes] Share route hit with videoId: $videoId');

    if (videoId.isEmpty || videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
      print('[VideoRoutes] Error: Invalid videoId');
      return Response(400,
          body: jsonEncode({
            'error': 'Invalid video ID',
            'receivedVideoId': videoId,
            'path': request.url.path,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      return await VideoController.shareVideoHandler(request, videoId);
    } catch (e, stackTrace) {
      print('[VideoRoutes] Error in share route: $e');
      print('[VideoRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // Get share analytics route
  router.get('/<videoId>/share-analytics', (Request request, String videoId) async {
    print('[VideoRoutes] Share analytics route hit with videoId: $videoId');

    if (videoId.isEmpty || videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
      return Response(400,
          body: jsonEncode({
            'error': 'Invalid video ID',
            'receivedVideoId': videoId,
            'path': request.url.path,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      return await VideoController.getVideoShareAnalyticsHandler(request, videoId);
    } catch (e, stackTrace) {
      print('[VideoRoutes] Error in share analytics route: $e');
      print('[VideoRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // Save video route
  router.post('/<videoId>/save', (Request request, String videoId) async {
    print('[VideoRoutes] Save route hit with videoId: $videoId');

    if (videoId.isEmpty || videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
      print('[VideoRoutes] Error: Invalid videoId');
      return Response(400,
          body: jsonEncode({
            'error': 'Invalid video ID',
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

  // CORS handlers for share routes
  router.options('/<videoId>/share', (Request request, String videoId) async {
    return Response.ok('', headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
      'Access-Control-Max-Age': '86400',
    });
  });

  router.options('/<videoId>/share-analytics', (Request request, String videoId) async {
    return Response.ok('', headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
      'Access-Control-Max-Age': '86400',
    });
  });

  // General CORS handler
  router.options('/<path|.*>', (Request request) async {
    return Response.ok('', headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
      'Access-Control-Max-Age': '86400',
    });
  });

  // Debug route
  router.get('/debug/info', (Request request) async {
    return Response.ok(jsonEncode({
      'message': 'Video routes debug info',
      'availableRoutes': [
        'POST /api/videos/upload',
        'GET /api/videos/feed',
        'GET /api/videos/<videoId>',
        'POST /api/videos/<videoId>/like',
        'POST /api/videos/<videoId>/save',
        'POST /api/videos/<videoId>/share',
        'GET /api/videos/<videoId>/share-analytics',
        'GET /api/videos/debug/info',
      ],
      'examples': [
        'GET /api/videos/683c24fffdf60af9cddfb22a',
        'POST /api/videos/683c24fffdf60af9cddfb22a/like',
        'POST /api/videos/683c24fffdf60af9cddfb22a/save',
        'POST /api/videos/683c24fffdf60af9cddfb22a/share',
        'GET /api/videos/683c24fffdf60af9cddfb22a/share-analytics',
      ],
      'shareRequestFormat': {
        'shareMethod': 'whatsapp|facebook|instagram|twitter|copy_link|sms|email|native|other|public_view',
        'userId': 'optional_user_id',
        'shareText': 'optional_custom_share_text',
      },
      'supportedShareMethods': [
        'whatsapp',
        'facebook',
        'instagram',
        'twitter',
        'copy_link',
        'sms',
        'email',
        'native',
        'other',
        'public_view',
      ],
    }), headers: {'Content-Type': 'application/json'});
  });

  return router;
}
