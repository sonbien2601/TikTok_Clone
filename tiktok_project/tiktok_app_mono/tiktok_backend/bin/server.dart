// tiktok_backend/bin/server.dart - SIMPLE VERSION WITH PHASE 1 FOLLOW SYSTEM
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as p;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

// Core imports
import 'package:tiktok_backend/src/core/config/env_config.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';

// Feature imports
import 'package:tiktok_backend/src/features/users/user_routes.dart';
import 'package:tiktok_backend/src/features/users/follow_routes.dart'; // NEW: Follow routes
import 'package:tiktok_backend/src/features/videos/video_routes.dart';
import 'package:tiktok_backend/src/features/comments/comment_routes.dart';
import 'package:tiktok_backend/src/features/notifications/notification_routes.dart';

Future<void> main(List<String>? args) async {
  print('[Server] 🚀 Starting TikTok Backend Server with Follow System...');

  try {
    // Load configuration
    await EnvConfig.loadConfig();
    print('[Server] ✅ Configuration loaded successfully');

    // Connect to database
    await DatabaseService.connect();
    print('[Server] ✅ Database connected successfully');

    final router = Router();

    // Health check
    router.get('/health', (Request request) {
      return Response.ok(jsonEncode({
        'status': 'healthy',
        'service': 'tiktok_backend_with_follow_system',
        'version': '1.1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'features': [
          'user_management',
          'follow_system', // NEW FEATURE
          'video_management',
          'comment_system',
          'notification_system'
        ],
      }), headers: {'Content-Type': 'application/json'});
    });

    // Mount routes
    router.mount('/api/users', createUserRoutes());
    router.mount('/api/follow', createFollowRoutes()); // NEW: Follow routes
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

    // Enhanced debug endpoint with follow system info
    router.get('/api/debug', (Request request) {
      return Response.ok(jsonEncode({
        'message': 'TikTok Backend API with Follow System',
        'version': '1.1.0',
        'server_time': DateTime.now().toIso8601String(),
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
          'follow': [ // NEW ENDPOINTS
            'POST /follow/{currentUserId}/{targetUserId}',
            'DELETE /unfollow/{currentUserId}/{targetUserId}',
            'GET /followers/{userId}?page=1&limit=20',
            'GET /following/{userId}?page=1&limit=20',
            'GET /status/{currentUserId}/{targetUserId}',
            'GET /test-follow-api',
            'GET /debug/routes'
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
        },
        'new_features_phase1': {
          'follow_system': {
            'description': 'Complete follow/unfollow functionality',
            'features': [
              'Follow/Unfollow users',
              'View followers list',
              'View following list',
              'Follow status checking',
              'Follower/Following counts',
              'Pagination support'
            ]
          }
        }
      }), headers: {'Content-Type': 'application/json'});
    });

    // Catch-all
    router.all('/<ignored|.*>', (Request request) {
      return Response.notFound(jsonEncode({
        'error': 'Route not found',
        'method': request.method,
        'path': request.url.path,
        'available_routes': {
          'follow_system': '/api/follow/debug/routes',
          'debug_info': '/api/debug',
          'health_check': '/health'
        }
      }), headers: {'Content-Type': 'application/json'});
    });

    // Simple middleware pipeline
    final pipeline = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router);

    final server = await shelf_io.serve(
      pipeline,
      InternetAddress.anyIPv4,
      EnvConfig.serverPort,
    );

    // Success messages
    print('\n🎉 ================================================');
    print('✅ TikTok Backend Server with Follow System Started!');
    print('================================================');
    print('🌐 Server URL: http://${server.address.host}:${server.port}');
    print('🎯 API Base URL: http://${server.address.host}:${server.port}/api');
    print('🐛 Debug Info: http://${server.address.host}:${server.port}/api/debug');
    print('🏥 Health Check: http://${server.address.host}:${server.port}/health');
    print('📁 Static Files: http://${server.address.host}:${server.port}/uploads');
    print('');
    print('🆕 NEW FEATURES (Phase 1):');
    print('🤝 Follow System: http://${server.address.host}:${server.port}/api/follow');
    print('   - Follow/Unfollow users');
    print('   - View followers/following lists');
    print('   - Check follow status');
    print('   - Test: http://${server.address.host}:${server.port}/api/follow/test-follow-api');
    print('');
    print('📖 EXAMPLE REQUESTS:');
    print('   - Follow user: POST /api/follow/follow/USER_ID_1/USER_ID_2');
    print('   - Get followers: GET /api/follow/followers/USER_ID?page=1&limit=20');
    print('   - Check status: GET /api/follow/status/USER_ID_1/USER_ID_2');
    print('================================================\n');

  } catch (e, stackTrace) {
    print('\n❌ ================================================');
    print('CRITICAL ERROR: Failed to start TikTok Backend Server');
    print('================================================');
    print('Error: $e');
    print('Stack trace: $stackTrace');
    print('================================================\n');
    exit(1);
  }
}