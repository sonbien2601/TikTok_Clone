// tiktok_backend/lib/src/features/notifications/notification_routes.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'controllers/notification_controller.dart';

Router createNotificationRoutes() {
  final router = Router();

  print('[NotificationRoutes] Creating notification routes...');

  // Debug middleware for notification routes
  Middleware notificationDebugMiddleware = (Handler innerHandler) {
    return (Request request) async {
      final startTime = DateTime.now();
      print('[NotificationRoutes] ${request.method} ${request.url}');
      print('[NotificationRoutes] Path segments: ${request.url.pathSegments}');
      
      final response = await innerHandler(request);
      final duration = DateTime.now().difference(startTime);
      
      print('[NotificationRoutes] ${request.method} ${request.url.path} - ${response.statusCode} (${duration.inMilliseconds}ms)');
      return response;
    };
  };

  // DEBUG ROUTES
  router.get('/debug/info', (Request request) async {
    return Response.ok(jsonEncode({
      'message': 'Notification routes debug info',
      'availableRoutes': [
        'GET /api/notifications/user/{userId} - Get user notifications (with pagination)',
        'GET /api/notifications/user/{userId}/unread-count - Get unread notifications count',
        'PUT /api/notifications/{notificationId}/read - Mark notification as read',
        'PUT /api/notifications/user/{userId}/read-all - Mark all notifications as read',
        'DELETE /api/notifications/{notificationId} - Delete notification',
        'GET /api/notifications/debug/info - This debug endpoint'
      ],
      'examples': [
        'GET /api/notifications/user/683c24fffdf60af9cddfb22a?page=1&limit=20',
        'GET /api/notifications/user/683c24fffdf60af9cddfb22a/unread-count',
        'PUT /api/notifications/683fcdf50b369f110bd6ac45/read',
        'PUT /api/notifications/user/683c24fffdf60af9cddfb22a/read-all',
        'DELETE /api/notifications/683fcdf50b369f110bd6ac45'
      ],
      'currentRequest': {
        'method': request.method,
        'url': request.url.toString(),
        'pathSegments': request.url.pathSegments,
      }
    }), headers: {'Content-Type': 'application/json'});
  });

  // GET USER NOTIFICATIONS
  router.get('/user/<userId>', (Request request, String userId) async {
    print('[NotificationRoutes] Get user notifications route hit with userId: $userId');

    if (userId.isEmpty) {
      return Response(400,
          body: jsonEncode({
            'error': 'User ID is required',
            'receivedUserId': userId,
            'path': request.url.path,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;

      return await NotificationController.getUserNotificationsHandler(request, userId, page, limit);

    } catch (e, stackTrace) {
      print('[NotificationRoutes] Error in get user notifications route: $e');
      print('[NotificationRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // GET UNREAD COUNT
  router.get('/user/<userId>/unread-count', (Request request, String userId) async {
    print('[NotificationRoutes] Get unread count route hit with userId: $userId');

    if (userId.isEmpty) {
      return Response(400,
          body: jsonEncode({
            'error': 'User ID is required',
            'receivedUserId': userId,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      return await NotificationController.getUnreadCountHandler(request, userId);

    } catch (e, stackTrace) {
      print('[NotificationRoutes] Error in get unread count route: $e');
      print('[NotificationRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // MARK NOTIFICATION AS READ
  router.put('/<notificationId>/read', (Request request, String notificationId) async {
    print('[NotificationRoutes] 🎯 MARK AS READ ROUTE HIT with notificationId: $notificationId');

    if (notificationId.isEmpty) {
      return Response(400,
          body: jsonEncode({
            'error': 'Notification ID is required',
            'receivedNotificationId': notificationId,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      final requestBody = await request.readAsString();
      print('[NotificationRoutes] Mark as read request body: $requestBody');
      
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
            body: jsonEncode({'error': 'userId is required to mark notification as read'}),
            headers: {'Content-Type': 'application/json'});
      }

      return await NotificationController.markNotificationAsReadHandler(request, notificationId, userIdString);

    } catch (e, stackTrace) {
      print('[NotificationRoutes] Error in mark as read route: $e');
      print('[NotificationRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // MARK ALL NOTIFICATIONS AS READ
  router.put('/user/<userId>/read-all', (Request request, String userId) async {
    print('[NotificationRoutes] 🎯 MARK ALL AS READ ROUTE HIT with userId: $userId');

    if (userId.isEmpty) {
      return Response(400,
          body: jsonEncode({
            'error': 'User ID is required',
            'receivedUserId': userId,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      return await NotificationController.markAllNotificationsAsReadHandler(request, userId);

    } catch (e, stackTrace) {
      print('[NotificationRoutes] Error in mark all as read route: $e');
      print('[NotificationRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  });

  // DELETE NOTIFICATION
  router.delete('/<notificationId>', (Request request, String notificationId) async {
    print('[NotificationRoutes] 🎯 DELETE NOTIFICATION ROUTE HIT with notificationId: $notificationId');

    if (notificationId.isEmpty) {
      return Response(400,
          body: jsonEncode({
            'error': 'Notification ID is required',
            'receivedNotificationId': notificationId,
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
            body: jsonEncode({'error': 'userId is required to delete notification'}),
            headers: {'Content-Type': 'application/json'});
      }

      return await NotificationController.deleteNotificationHandler(request, notificationId, userIdString);

    } catch (e, stackTrace) {
      print('[NotificationRoutes] Error in delete notification route: $e');
      print('[NotificationRoutes] StackTrace: $stackTrace');
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
    print('[NotificationRoutes] ❌ UNMATCHED ROUTE: ${request.method} ${request.url.path}');
    return Response(404, 
      body: jsonEncode({
        'error': 'Notification route not found',
        'method': request.method,
        'path': request.url.path,
        'pathSegments': request.url.pathSegments,
        'availableRoutes': [
          'GET /api/notifications/user/{userId}',
          'GET /api/notifications/user/{userId}/unread-count',
          'PUT /api/notifications/{notificationId}/read',
          'PUT /api/notifications/user/{userId}/read-all',
          'DELETE /api/notifications/{notificationId}'
        ],
      }), 
      headers: {'Content-Type': 'application/json'}
    );
  });

  print('[NotificationRoutes] ✅ Notification routes created');
  return router;
}