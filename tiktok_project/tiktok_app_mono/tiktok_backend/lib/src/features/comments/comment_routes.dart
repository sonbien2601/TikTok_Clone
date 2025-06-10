// tiktok_backend/lib/src/features/comments/comment_routes.dart

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'controllers/comment_controller.dart';

Router createCommentRoutes() {
  final router = Router();

  print('[CommentRoutes] Creating comment routes with reply and like features...');

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

  // DEBUG ROUTES
  router.get('/debug/info', (Request request) async {
    return Response.ok(jsonEncode({
      'message': 'Comment routes debug info',
      'availableRoutes': [
        'POST /api/comments/video/{videoId} - Add comment',
        'GET /api/comments/video/{videoId} - Get comments (with pagination)',
        'POST /api/comments/like/{commentId} - Toggle like on comment',
        'POST /api/comments/reply/{commentId} - Reply to comment',
        'GET /api/comments/replies/{commentId} - Get replies for comment',
        'PUT /api/comments/edit/{commentId} - Edit comment',
        'DELETE /api/comments/delete/{commentId} - Delete comment',
        'GET /api/comments/debug/info - This debug endpoint'
      ],
      'examples': [
        'POST /api/comments/video/683c24fffdf60af9cddfb22a',
        'GET /api/comments/video/683c24fffdf60af9cddfb22a?page=1&limit=20',
        'POST /api/comments/like/683fcdf50b369f110bd6ac45',
        'POST /api/comments/reply/683fcdf50b369f110bd6ac45',
        'GET /api/comments/replies/683fcdf50b369f110bd6ac45?page=1&limit=10',
        'PUT /api/comments/edit/683fcdf50b369f110bd6ac45',
        'DELETE /api/comments/delete/683fcdf50b369f110bd6ac45'
      ],
      'currentRequest': {
        'method': request.method,
        'url': request.url.toString(),
        'pathSegments': request.url.pathSegments,
      }
    }), headers: {'Content-Type': 'application/json'});
  });

  // VIDEO ROUTES - MUST COME BEFORE GENERIC ROUTES
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
      final requestBody = await request.readAsString();
      print('[CommentRoutes] Request body: $requestBody');

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

      return await CommentController.addCommentHandler(request, videoId, userIdString, text.trim());

    } catch (e, stackTrace) {
      print('[CommentRoutes] Error in add comment route: $e');
      print('[CommentRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

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
      final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;

      return await CommentController.getVideoCommentsHandler(request, videoId, page, limit);

    } catch (e, stackTrace) {
      print('[CommentRoutes] Error in get comments route: $e');
      print('[CommentRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // LIKE COMMENT ROUTES - SPECIFIC PATH FIRST
  router.post('/like/<commentId>', (Request request, String commentId) async {
    print('[CommentRoutes] 🎯 LIKE COMMENT ROUTE HIT with commentId: $commentId');

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
      print('[CommentRoutes] Like request body: $requestBody');
      
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
            body: jsonEncode({'error': 'userId is required to like comment'}),
            headers: {'Content-Type': 'application/json'});
      }

      print('[CommentRoutes] Calling CommentController.toggleLikeCommentHandler');

      return await CommentController.toggleLikeCommentHandler(request, commentId, userIdString);

    } catch (e, stackTrace) {
      print('[CommentRoutes] Error in like comment route: $e');
      print('[CommentRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // REPLY ROUTES - SPECIFIC PATH FIRST
  router.post('/reply/<commentId>', (Request request, String commentId) async {
    print('[CommentRoutes] 🎯 REPLY ROUTE HIT with commentId: $commentId');

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
      print('[CommentRoutes] Reply request body: $requestBody');
      
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
      final text = payload['text'] as String?;

      if (userIdString == null || userIdString.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'userId is required to reply to comment'}),
            headers: {'Content-Type': 'application/json'});
      }

      if (text == null || text.trim().isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'reply text is required and cannot be empty'}),
            headers: {'Content-Type': 'application/json'});
      }

      print('[CommentRoutes] Calling CommentController.replyToCommentHandler');

      return await CommentController.replyToCommentHandler(request, commentId, userIdString, text.trim());

    } catch (e, stackTrace) {
      print('[CommentRoutes] Error in reply route: $e');
      print('[CommentRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // GET REPLIES ROUTES
  router.get('/replies/<commentId>', (Request request, String commentId) async {
    print('[CommentRoutes] Get replies route hit with commentId: $commentId');

    if (commentId.isEmpty) {
      return Response(400,
          body: jsonEncode({
            'error': 'Comment ID is required',
            'receivedCommentId': commentId,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '10') ?? 10;

      return await CommentController.getCommentRepliesHandler(request, commentId, page, limit);

    } catch (e, stackTrace) {
      print('[CommentRoutes] Error in get replies route: $e');
      print('[CommentRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // EXPLICIT EDIT ROUTE - NO CONFLICTS
  router.put('/edit/<commentId>', (Request request, String commentId) async {
    print('[CommentRoutes] 🎯 EXPLICIT EDIT ROUTE HIT with commentId: $commentId');

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
      print('[CommentRoutes] Edit request body: $requestBody');
      
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
      final newText = payload['text'] as String?;

      if (userIdString == null || userIdString.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'userId is required to edit comment'}),
            headers: {'Content-Type': 'application/json'});
      }

      if (newText == null || newText.trim().isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'comment text is required and cannot be empty'}),
            headers: {'Content-Type': 'application/json'});
      }

      print('[CommentRoutes] Calling CommentController.editCommentHandler');

      return await CommentController.editCommentHandler(request, commentId, userIdString, newText.trim());

    } catch (e, stackTrace) {
      print('[CommentRoutes] Error in edit comment route: $e');
      print('[CommentRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // EXPLICIT DELETE ROUTE - NO CONFLICTS
  router.delete('/delete/<commentId>', (Request request, String commentId) async {
    print('[CommentRoutes] 🎯 EXPLICIT DELETE ROUTE HIT with commentId: $commentId');

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

  // Catch-all route for unmatched requests
  router.all('/<path|.*>', (Request request) async {
    print('[CommentRoutes] ❌ UNMATCHED ROUTE: ${request.method} ${request.url.path}');
    return Response(404, 
      body: jsonEncode({
        'error': 'Comment route not found',
        'method': request.method,
        'path': request.url.path,
        'pathSegments': request.url.pathSegments,
        'availableRoutes': [
          'POST /api/comments/video/{videoId}',
          'GET /api/comments/video/{videoId}',
          'POST /api/comments/like/{commentId}',
          'POST /api/comments/reply/{commentId}',
          'GET /api/comments/replies/{commentId}',
          'PUT /api/comments/edit/{commentId}',
          'DELETE /api/comments/delete/{commentId}'
        ],
        'hint': 'Use explicit patterns for operations'
      }), 
      headers: {'Content-Type': 'application/json'}
    );
  });

  print('[CommentRoutes] ✅ Comment routes created with reply and like features');
  return router;
}