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
import 'package:tiktok_backend/src/features/users/follow_routes.dart';
import 'package:tiktok_backend/src/features/videos/video_routes.dart';
import 'package:tiktok_backend/src/features/comments/comment_routes.dart';
import 'package:tiktok_backend/src/features/notifications/notification_routes.dart';
import 'package:tiktok_backend/src/features/analytics/analytics_routes.dart'; // NEW: Analytics routes

Future<void> main(List<String>? args) async {
  print('[Server] 🚀 Starting TikTok Backend Server with Follow System and Analytics...');

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
        'service': 'tiktok_backend_with_follow_and_analytics',
        'version': '1.2.0',
        'timestamp': DateTime.now().toIso8601String(),
        'features': [
          'user_management',
          'follow_system',
          'video_management',
          'comment_system',
          'notification_system',
          'video_analytics', // NEW FEATURE
        ],
      }), headers: {'Content-Type': 'application/json'});
    });

    // Mount routes
    router.mount('/api/users', createUserRoutes());
    router.mount('/api/follow', createFollowRoutes());
    router.mount('/api/videos', createVideoRoutes());
    router.mount('/api/comments', createCommentRoutes());
    router.mount('/api/notifications', createNotificationRoutes());
    router.mount('/api/analytics', createAnalyticsRoutes()); // NEW: Analytics routes

    // Static file handler
    final uploadsPath = p.join(Directory.current.path, 'uploads');
    final uploadsDir = Directory(uploadsPath);
    if (!await uploadsDir.exists()) {
      await uploadsDir.create(recursive: true);
      print('[Server] ✅ Created uploads directory');
    }
    router.mount('/uploads/', createStaticHandler(uploadsPath));

    // Enhanced debug endpoint with analytics info
    router.get('/api/debug', (Request request) {
      return Response.ok(jsonEncode({
        'message': 'TikTok Backend API with Follow System & Analytics',
        'version': '1.2.0',
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
          'follow': [
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
            'GET /{videoId}',
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
          ],
          'analytics': [ // NEW ENDPOINTS
            'POST /track-view',
            'POST /track-views-bulk',
            'GET /video/{videoId}',
            'GET /user/{userId}',
            'GET /trending?timeframe=24h&limit=10',
            'GET /summary?timeframe=24h',
            'GET /debug/info'
          ]
        },
        'new_features_phase2': {
          'video_analytics': {
            'description': 'Comprehensive video analytics and view tracking',
            'features': [
              'Track individual video views',
              'Unique viewers tracking',
              'View duration analytics',
              'View source tracking (feed, profile, search)',
              'Engagement rate calculations',
              'Trending videos analysis',
              'User analytics across all videos',
              'Hourly and daily view distributions',
              'Bulk view tracking for performance'
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
          'analytics': '/api/analytics/debug/info', // NEW
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
    print('✅ TikTok Backend Server with Follow System and Analytics Started!');
    print('================================================');
    print('🌐 Server URL: http://${server.address.host}:${server.port}');
    print('🎯 API Base URL: http://${server.address.host}:${server.port}/api');
    print('🐛 Debug Info: http://${server.address.host}:${server.port}/api/debug');
    print('🏥 Health Check: http://${server.address.host}:${server.port}/health');
    print('📁 Static Files: http://${server.address.host}:${server.port}/Uploads');
    print('');
    print('🆕 NEW FEATURES (Phase 1):');
    print('🤝 Follow System: http://${server.address.host}:${server.port}/api/follow');
    print('   - Follow/Unfollow users');
    print('   - View followers/following lists');
    print('   - Check follow status');
    print('   - Test: http://${server.address.host}:${server.port}/api/follow/test-follow-api');
    print('');
    print('🆕 NEW FEATURES (Phase 2):');
    print('📊 Video Analytics: http://${server.address.host}:${server.port}/api/analytics');
    print('   - Track video views and engagement');
    print('   - Get detailed video analytics');
    print('   - View trending videos');
    print('   - User analytics dashboard');
    print('   - Test: http://${server.address.host}:${server.port}/api/analytics/debug/info');
    print('');
    print('📖 EXAMPLE REQUESTS:');
    print('   - Follow user: POST /api/follow/follow/USER_ID_1/USER_ID_2');
    print('   - Get followers: GET /api/follow/followers/USER_ID?page=1&limit=20');
    print('   - Check status: GET /api/follow/status/USER_ID_1/USER_ID_2');
    print('   - Track view: POST /api/analytics/track-view');
    print('   - Video analytics: GET /api/analytics/video/VIDEO_ID');
    print('   - User analytics: GET /api/analytics/user/USER_ID');
    print('   - Trending videos: GET /api/analytics/trending?timeframe=24h');
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