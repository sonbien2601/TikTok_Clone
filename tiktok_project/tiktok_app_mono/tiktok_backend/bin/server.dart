import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as p;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify;

// Core imports
import 'package:tiktok_backend/src/core/config/env_config.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';

// Feature imports
import 'package:tiktok_backend/src/features/users/user_routes.dart';
import 'package:tiktok_backend/src/features/users/follow_routes.dart';
import 'package:tiktok_backend/src/features/videos/video_routes.dart';
import 'package:tiktok_backend/src/features/comments/comment_routes.dart';
import 'package:tiktok_backend/src/features/notifications/notification_routes.dart';
import 'package:tiktok_backend/src/features/analytics/analytics_routes.dart';
import 'package:tiktok_backend/src/features/search/search_routes.dart';

Future<void> main(List<String>? args) async {
  try {
    // Load configuration
    await EnvConfig.loadConfig();

    // Connect to database
    await DatabaseService.connect();

    final router = Router();

    // Health check
    router.get('/health', (Request request) {
      return Response.ok(jsonEncode({
        'status': 'healthy',
        'service': 'tiktok_backend_with_follow_analytics_and_search',
        'version': '1.3.0',
        'timestamp': DateTime.now().toIso8601String(),
        'features': [
          'user_management',
          'follow_system',
          'video_management',
          'comment_system',
          'notification_system',
          'video_analytics',
          'public_video_access',
          'user_search_and_discovery',
        ],
      }), headers: {'Content-Type': 'application/json'});
    });

    // Mount routes
    router.mount('/api/users', createUserRoutes());
    router.mount('/api/follow', createFollowRoutes());
    router.mount('/api/videos', createVideoRoutes());
    router.mount('/api/comments', createCommentRoutes());
    router.mount('/api/notifications', createNotificationRoutes());
    router.mount('/api/analytics', createAnalyticsRoutes());
    router.mount('/api/search', createSearchRoutes());

    // Static file handler with CORS support
    final uploadsPath = p.join(Directory.current.path, 'Uploads');
    final uploadsDir = Directory(uploadsPath);
    if (!await uploadsDir.exists()) {
      await uploadsDir.create(recursive: true);
    }

    router.get('/uploads/<path|.*>', (Request request, String path) async {
      final file = File(p.join(uploadsPath, path));

      if (!await file.exists()) {
        return Response.notFound('File not found');
      }

      // Xác định MIME type
      String contentType = 'application/octet-stream';
      final extension = p.extension(path).toLowerCase();
      switch (extension) {
        case '.png':
          contentType = 'image/png';
          break;
        case '.jpg':
        case '.jpeg':
          contentType = 'image/jpeg';
          break;
        case '.gif':
          contentType = 'image/gif';
          break;
        case '.webp':
          contentType = 'image/webp';
          break;
      }

      final bytes = await file.readAsBytes();

      return Response.ok(
        bytes,
        headers: {
          'Content-Type': contentType,
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
          'Cross-Origin-Resource-Policy': 'cross-origin',
          'Cache-Control': 'public, max-age=3600',
        },
      );
    });

    // OPTIONS handler for preflight
    router.options('/uploads/<path|.*>', (Request request, String path) {
      return Response.ok('', headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        'Access-Control-Max-Age': '86400',
      });
    });

    // PUBLIC VIDEO ACCESS - No auth required
    router.get('/video/<videoId>', (Request request, String videoId) async {
      try {
        // Validate video ID format
        if (videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
          return _buildVideoNotFoundPage();
        }

        ObjectId videoObjectId;
        try {
          videoObjectId = ObjectId.fromHexString(videoId);
        } catch (e) {
          return _buildVideoNotFoundPage();
        }

        final videosCollection = DatabaseService.db.collection('videos');
        final usersCollection = DatabaseService.db.collection('users');

        // Get video data
        final video = await videosCollection.findOne(where.id(videoObjectId));
        if (video == null) {
          return _buildVideoNotFoundPage();
        }

        // Get user data
        final userId = video['userId'] as ObjectId;
        final user = await usersCollection.findOne(where.id(userId));

        final username = user?['username'] as String? ?? 'Unknown User';
        final userAvatar = user?['avatarUrl'] as String?;

        // Build video landing page HTML
        final html = _buildVideoLandingPage(
          videoId: videoId,
          title: video['description'] as String? ?? 'Check out this video!',
          username: username,
          userAvatar: userAvatar,
          videoUrl: video['videoUrl'] as String? ?? '',
          viewsCount: video['viewsCount'] as int? ?? 0,
          likesCount: video['likesCount'] as int? ?? 0,
          sharesCount: video['sharesCount'] as int? ?? 0,
          createdAt: video['createdAt'] as String?,
        );

        // Track the view
        _trackPublicView(videoId);

        return Response.ok(
          html,
          headers: {
            'Content-Type': 'text/html; charset=utf-8',
            'Cache-Control': 'public, max-age=3600',
          },
        );

      } catch (e) {
        return _buildErrorPage();
      }
    });

    // API endpoint to get video data for embedding
    router.get('/api/public/video/<videoId>', (Request request, String videoId) async {
      try {
        if (videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
          return Response(404,
            body: jsonEncode({'error': 'Video not found'}),
            headers: {'Content-Type': 'application/json'}
          );
        }

        ObjectId videoObjectId;
        try {
          videoObjectId = ObjectId.fromHexString(videoId);
        } catch (e) {
          return Response(404,
            body: jsonEncode({'error': 'Invalid video ID'}),
            headers: {'Content-Type': 'application/json'}
          );
        }

        final videosCollection = DatabaseService.db.collection('videos');
        final usersCollection = DatabaseService.db.collection('users');

        final video = await videosCollection.findOne(where.id(videoObjectId));
        if (video == null) {
          return Response(404,
            body: jsonEncode({'error': 'Video not found'}),
            headers: {'Content-Type': 'application/json'}
          );
        }

        // Get user data
        final userId = video['userId'] as ObjectId;
        final user = await usersCollection.findOne(where.id(userId));

        // Build public response
        final publicVideo = {
          'id': videoId,
          'description': video['description'],
          'videoUrl': video['videoUrl'],
          'user': {
            'username': user?['username'] ?? 'Unknown User',
            'avatarUrl': user?['avatarUrl'],
          },
          'viewsCount': video['viewsCount'] ?? 0,
          'likesCount': video['likesCount'] ?? 0,
          'sharesCount': video['sharesCount'] ?? 0,
          'createdAt': video['createdAt'],
        };

        return Response.ok(
          jsonEncode(publicVideo),
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        );

      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
    });

    // Enhanced debug endpoint with analytics and public access info
    router.get('/api/debug', (Request request) {
      return Response.ok(jsonEncode({
        'message': 'TikTok Backend API with Follow System, Analytics & Search',
        'version': '1.3.0',
        'server_time': DateTime.now().toIso8601String(),
        'endpoints': {
          'users': [
            'POST /register',
            'POST /login',
            'GET /{userId}',
            'PUT /{userId}',
            'GET /{userId}/liked-videos',
            'GET /{userId}/saved-videos',
            'GET /{userId}/videos',
          ],
          'follow': [
            'POST /follow/{currentUserId}/{targetUserId}',
            'DELETE /unfollow/{currentUserId}/{targetUserId}',
            'GET /followers/{userId}?page=1&limit=20',
            'GET /following/{userId}?page=1&limit=20',
            'GET /status/{currentUserId}/{targetUserId}',
            'GET /test-follow-api',
            'GET /debug/routes',
          ],
          'videos': [
            'POST /upload',
            'GET /feed',
            'GET /{videoId}',
            'POST /{videoId}/like',
            'POST /{videoId}/save',
            'POST /{videoId}/share',
          ],
          'public_videos': [
            'GET /video/{videoId}',
            'GET /api/public/video/{videoId}',
          ],
          'comments': [
            'POST /video/{videoId}',
            'GET /video/{videoId}',
            'POST /like/{commentId}',
            'POST /reply/{commentId}',
          ],
          'notifications': [
            'GET /user/{userId}',
            'PUT /{notificationId}/read',
          ],
          'analytics': [
            'POST /track-view',
            'POST /track-views-bulk',
            'GET /video/{videoId}',
            'GET /user/{userId}',
            'GET /trending?timeframe=24h&limit=10',
            'GET /summary?timeframe=24h',
            'GET /debug/info',
          ],
          'search': [
            'GET /users?q=query&page=1&limit=20',
            'GET /trending?limit=10&timeframe=7d',
            'GET /videos?q=query&page=1&limit=20',
            'GET /suggestions?q=partial&limit=5',
            'GET /test',
            'GET /debug/info',
          ],
        },
        'new_features_phase3': {
          'user_search_and_discovery': {
            'description': 'Comprehensive user and video search functionality',
            'features': [
              'Search users by username, email, display name',
              'Trending users with activity-based scoring',
              'Video search by description and hashtags',
              'Real-time search suggestions/autocomplete',
              'Follow status integration in search results',
              'Pagination support for all search endpoints',
              'Multiple timeframe support for trending analysis',
              'Performance optimized with proper indexing',
            ],
          },
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
              'Bulk view tracking for performance',
            ],
          },
          'public_video_access': {
            'description': 'Public video sharing and viewing',
            'features': [
              'Public video landing page',
              'Open Graph and Twitter Card support',
              'Deep linking to mobile app',
              'Public video API for embedding',
              'View tracking for public access',
            ],
          },
        },
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
          'analytics': '/api/analytics/debug/info',
          'public_videos': '/video/{videoId}',
          'debug_info': '/api/debug',
          'health_check': '/health',
        },
      }), headers: {'Content-Type': 'application/json'});
    });

    // Middleware pipeline
    final pipeline = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(corsHeaders())
        .addHandler(router);

    final server = await shelf_io.serve(
      pipeline,
      InternetAddress.anyIPv4,
      EnvConfig.serverPort,
    );

  } catch (e, stackTrace) {
    exit(1);
  }
}

// Thay thế _buildVideoLandingPage bằng đọc file HTML template
String _buildVideoLandingPage({
  required String videoId,
  required String title,
  required String username,
  String? userAvatar,
  required String videoUrl,
  required int viewsCount,
  required int likesCount,
  required int sharesCount,
  String? createdAt,
}) {
  final templatePath = 'public_video_landing.html';
  String html = '';
  try {
    html = File(templatePath).readAsStringSync();
    html = html.replaceAll('{{videoId}}', videoId)
               .replaceAll('{{title}}', title)
               .replaceAll('{{username}}', username)
               .replaceAll('{{userAvatar}}', userAvatar ?? '')
               .replaceAll('{{videoUrl}}', videoUrl)
               .replaceAll('{{viewsCount}}', viewsCount.toString())
               .replaceAll('{{likesCount}}', likesCount.toString())
               .replaceAll('{{sharesCount}}', sharesCount.toString())
               .replaceAll('{{createdAt}}', createdAt ?? '');
  } catch (e) {
    html = '<html><body>Error loading video page</body></html>';
  }
  return html;
}

// Helper function for video not found page
Response _buildVideoNotFoundPage() {
  return Response(404,
    body: '''
<!DOCTYPE html>
<html>
<head>
    <title>Video Not Found | TikTok Clone</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { 
            font-family: Arial, sans-serif; 
            text-align: center; 
            padding: 50px; 
            background: linear-gradient(135deg, #ff0050, #ff4081);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: rgba(255,255,255,0.1);
            padding: 40px;
            border-radius: 20px;
            backdrop-filter: blur(20px);
        }
        h1 { font-size: 48px; margin-bottom: 20px; }
        p { font-size: 18px; margin-bottom: 30px; }
        a { 
            color: white; 
            text-decoration: none; 
            background: rgba(255,255,255,0.2);
            padding: 15px 30px;
            border-radius: 30px;
            display: inline-block;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>😕 Video Not Found</h1>
        <p>Sorry, this video doesn't exist or has been removed.</p>
        <a href="/">🏠 Go to Homepage</a>
    </div>
</body>
</html>
    ''',
    headers: {'Content-Type': 'text/html; charset=utf-8'}
  );
}

// Helper function for error page
Response _buildErrorPage() {
  return Response.internalServerError(
    body: '''
<!DOCTYPE html>
<html>
<head>
    <title>Error | TikTok Clone</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { 
            font-family: Arial, sans-serif; 
            text-align: center; 
            padding: 50px; 
            background: linear-gradient(135deg, #ff0050, #ff4081);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: rgba(255,255,255,0.1);
            padding: 40px;
            border-radius: 20px;
            backdrop-filter: blur(20px);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚠️ Something went wrong</h1>
        <p>Please try again later.</p>
        <a href="/">🏠 Go to Homepage</a>
    </div>
</body>
</html>
    ''',
    headers: {'Content-Type': 'text/html; charset=utf-8'}
  );
}

// Helper function to track public views
void _trackPublicView(String videoId) {
  try {
    // Track public view asynchronously (don't block response)
    () async {
      final videosCollection = DatabaseService.db.collection('videos');
      final videoObjectId = ObjectId.fromHexString(videoId);

      await videosCollection.updateOne(
        where.id(videoObjectId),
        modify.inc('viewsCount', 1)
      );
    }();
  } catch (e) {
    // No debug print here
  }
}