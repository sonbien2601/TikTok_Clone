// tiktok_backend/lib/src/features/comments/comment_routes.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'controllers/comment_controller.dart';

Router createCommentRoutes() {
  final router = Router();

  // Debug middleware for comment routes
  Middleware commentDebugMiddleware = (Handler innerHandler) {
    return (Request request) async {
      final startTime = DateTime.now();
      print('[CommentRoutes] ${request.method} ${request.url}');
      print('[CommentRoutes] Path segments: ${request.url.pathSegments}');
      
      final response = await innerHandler(request);
      final duration = DateTime.now().difference(startTime);
      
      print('[CommentRoutes] ${request.method} ${request.url.path} - ${response.statusCode} (${duration.inMilliseconds}ms)');
      return response;
    };
  };

  // Add comment to video
  router.post('/video/<videoId>', (Request request, String videoId) async {
    print('[CommentRoutes] Add comment route hit with videoId: $videoId');

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
      // Read and validate request body
      final requestBody = await request.readAsString();
      print('[CommentRoutes] Request body: $requestBody');

      if (requestBody.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Request body is empty'}),
            headers: {'Content-Type': 'application/json'});
      }

      // Parse JSON
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(requestBody);
      } catch (e) {
        return Response(400,
            body: jsonEncode({'error': 'Invalid JSON in request body: $e'}),
            headers: {'Content-Type': 'application/json'});
      }

      final userIdString = payload['userId'] as String?;
      final text = payload['text'] as String?;

      if (userIdString == null || userIdString.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'userId is required in request body'}),
            headers: {'Content-Type': 'application/json'});
      }

      if (text == null || text.trim().isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'comment text is required and cannot be empty'}),
            headers: {'Content-Type': 'application/json'});
      }

      print('[CommentRoutes] Calling CommentController.addCommentHandler with videoId: $videoId, userId: $userIdString');

      return await CommentController.addCommentHandler(request, videoId, userIdString, text.trim());

    } catch (e, stackTrace) {
      print('[CommentRoutes] Error in add comment route: $e');
      print('[CommentRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // Get comments for video
  router.get('/video/<videoId>', (Request request, String videoId) async {
    print('[CommentRoutes] Get comments route hit with videoId: $videoId');

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
      // Get optional query parameters
      final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;

      print('[CommentRoutes] Fetching comments: page $page, limit $limit');

      return await CommentController.getVideoCommentsHandler(request, videoId, page, limit);

    } catch (e, stackTrace) {
      print('[CommentRoutes] Error in get comments route: $e');
      print('[CommentRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // Delete comment (optional feature)
  router.delete('/comment/<commentId>', (Request request, String commentId) async {
    print('[CommentRoutes] Delete comment route hit with commentId: $commentId');

    if (commentId.isEmpty) {
      return Response(400,
          body: jsonEncode({
            'error': 'Comment ID is required',
            'receivedCommentId': commentId,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      final requestBody = await request.readAsString();
      Map<String, dynamic> payload = {};
      
      if (requestBody.isNotEmpty) {
        try {
          payload = jsonDecode(requestBody);
        } catch (e) {
          return Response(400,
              body: jsonEncode({'error': 'Invalid JSON in request body: $e'}),
              headers: {'Content-Type': 'application/json'});
        }
      }

      final userIdString = payload['userId'] as String?;
      if (userIdString == null || userIdString.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'userId is required to delete comment'}),
            headers: {'Content-Type': 'application/json'});
      }

      return await CommentController.deleteCommentHandler(request, commentId, userIdString);

    } catch (e, stackTrace) {
      print('[CommentRoutes] Error in delete comment route: $e');
      print('[CommentRoutes] StackTrace: $stackTrace');
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
      'message': 'Comment routes debug info',
      'availableRoutes': [
        'POST /api/comments/video/{videoId} - Add comment',
        'GET /api/comments/video/{videoId} - Get comments (with pagination)',
        'DELETE /api/comments/comment/{commentId} - Delete comment',
        'GET /api/comments/debug/info - This debug endpoint'
      ],
      'examples': [
        'POST /api/comments/video/683c24fffdf60af9cddfb22a',
        'GET /api/comments/video/683c24fffdf60af9cddfb22a?page=1&limit=20',
        'DELETE /api/comments/comment/comment_id_here'
      ],
      'currentRequest': {
        'method': request.method,
        'url': request.url.toString(),
        'pathSegments': request.url.pathSegments,
      }
    }), headers: {'Content-Type': 'application/json'});
  });

  // Catch-all route for unmatched requests
  router.all('/<path|.*>', (Request request) async {
    print('[CommentRoutes] Unmatched route: ${request.method} ${request.url.path}');
    return Response(404, 
      body: jsonEncode({
        'error': 'Comment route not found',
        'method': request.method,
        'path': request.url.path,
        'pathSegments': request.url.pathSegments,
        'availableRoutes': [
          'POST /api/comments/video/{videoId}',
          'GET /api/comments/video/{videoId}',
          'DELETE /api/comments/comment/{commentId}'
        ]
      }), 
      headers: {'Content-Type': 'application/json'}
    );
  });

  // Apply debug middleware
  final handler = const Pipeline()
      .addMiddleware(commentDebugMiddleware)
      .addHandler(router);

  return router;
}