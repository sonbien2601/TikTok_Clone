// Merged TikTok Backend Server Entry Point
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as p;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:tiktok_backend/src/core/config/env_config.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';
import 'package:tiktok_backend/src/features/users/user_routes.dart';
import 'package:tiktok_backend/src/features/videos/video_routes.dart';
import 'package:tiktok_backend/src/features/comments/comment_routes.dart';
import 'package:tiktok_backend/src/features/notifications/notification_routes.dart';

Future<void> main(List<String>? args) async {
  print('[Server] Starting TikTok Backend Server...');

  try {
    await EnvConfig.loadConfig();
    print('[Server] ✅ Configuration loaded successfully');

    await DatabaseService.connect();
    print('[Server] ✅ Database connected successfully');

    final router = Router();

    // Health check
    router.get('/health', (Request request) {
      return Response.ok(jsonEncode({
        'status': 'healthy',
        'service': 'tiktok_backend',
        'timestamp': DateTime.now().toIso8601String(),
      }), headers: {'Content-Type': 'application/json'});
    });

    // Mount routes
    router.mount('/api/users', createUserRoutes());
    router.mount('/api/videos', createVideoRoutes());
    router.mount('/api/comments', createCommentRoutes());
    router.mount('/api/notifications', createNotificationRoutes());

    // Static file handler
    final uploadsPath = p.join(Directory.current.path, 'uploads');
    final uploadsDir = Directory(uploadsPath);
    if (!await uploadsDir.exists()) {
      await uploadsDir.create(recursive: true);
      print('[Server] ✅ Created uploads directory');
    }
    router.mount('/uploads/', createStaticHandler(uploadsPath));

    // Debug endpoint
    router.get('/api/debug', (Request request) {
      return Response.ok(jsonEncode({
        'message': 'TikTok Backend API',
        'version': '1.0.0',
        'endpoints': {
          'users': [
            'POST /register',
            'POST /login',
            'GET /{userId}',
            'PUT /{userId}',
            'GET /{userId}/liked-videos',
            'GET /{userId}/saved-videos',
            'GET /{userId}/videos'
          ],
          'videos': [
            'POST /upload',
            'GET /feed',
            'POST /{videoId}/like',
            'POST /{videoId}/save'
          ],
          'comments': [
            'POST /video/{videoId}',
            'GET /video/{videoId}',
            'POST /like/{commentId}',
            'POST /reply/{commentId}'
          ],
          'notifications': [
            'GET /user/{userId}',
            'PUT /{notificationId}/read'
          ]
        }
      }), headers: {'Content-Type': 'application/json'});
    });

    // Catch-all
    router.all('/<ignored|.*>', (Request request) {
      return Response.notFound(jsonEncode({
        'error': 'Route not found',
        'method': request.method,
        'path': request.url.path
      }), headers: {'Content-Type': 'application/json'});
    });

    final pipeline = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router);

    final server = await shelf_io.serve(
      pipeline,
      InternetAddress.anyIPv4,
      EnvConfig.serverPort,
    );

    print('[Server] ✅ Server running on http://${server.address.host}:${server.port}');
    print('[Server] 🎯 API Base URL: http://${server.address.host}:${server.port}/api');
    print('[Server] 📁 Static files: http://${server.address.host}:${server.port}/uploads');
    print('[Server] 🏥 Health check: http://${server.address.host}:${server.port}/health');
    print('[Server] 🐛 Debug info: http://${server.address.host}:${server.port}/api/debug');

  } catch (e, stackTrace) {
    print('[Server] ❌ CRITICAL ERROR: $e');
    print('[Server] Stack trace: $stackTrace');
    exit(1);
  }
}
