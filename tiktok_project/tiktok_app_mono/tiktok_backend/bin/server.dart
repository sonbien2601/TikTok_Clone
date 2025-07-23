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
      print('[Server] ✅ Created uploads directory at: $uploadsPath');
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
      print('[Server] Public video access: $videoId');

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

      } catch (e, s) {
        print('[Server] Error serving public video: $e\n$s');
        return _buildErrorPage();
      }
    });

    // API endpoint to get video data for embedding
    router.get('/api/public/video/<videoId>', (Request request, String videoId) async {
      print('[Server] Public video API access: $videoId');

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

      } catch (e, s) {
        print('[Server] Error in public video API: $e\n$s');
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

    // Success messages
    print('\n🎉 ================================================');
    print('✅ TikTok Backend Server with Follow System and Analytics Started!');
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
    print('🆕 NEW FEATURES (Phase 2):');
    print('📊 Video Analytics: http://${server.address.host}:${server.port}/api/analytics');
    print('   - Track video views and engagement');
    print('   - Get detailed video analytics');
    print('   - View trending videos');
    print('   - User analytics dashboard');
    print('   - Test: http://${server.address.host}:${server.port}/api/analytics/debug/info');
    print('');
    print('🆕 NEW FEATURES (Phase 3):');
    print('🔍 User Search & Discovery: http://${server.address.host}:${server.port}/api/search');
    print('   - Search users by username/email/display name');
    print('   - Get trending users with activity scoring');
    print('   - Search videos by description and hashtags');
    print('   - Real-time search suggestions');
    print('   - Test: http://${server.address.host}:${server.port}/api/search/test');
    print('');
    print('🆕 NEW FEATURES (Public Access):');
    print('🎥 Public Video Access: http://${server.address.host}:${server.port}/video/{videoId}');
    print('   - Public video landing page');
    print('   - Video embedding API: http://${server.address.host}:${server.port}/api/public/video/{videoId}');
    print('   - Social media sharing support');
    print('   - Mobile app deep linking');
    print('');
    print('📖 EXAMPLE REQUESTS:');
    print('   - Follow user: POST /api/follow/follow/USER_ID_1/USER_ID_2');
    print('   - Get followers: GET /api/follow/followers/USER_ID?page=1&limit=20');
    print('   - Check status: GET /api/follow/status/USER_ID_1/USER_ID_2');
    print('   - Track view: POST /api/analytics/track-view');
    print('   - Video analytics: GET /api/analytics/video/VIDEO_ID');
    print('   - User analytics: GET /api/analytics/user/USER_ID');
    print('   - Trending videos: GET /api/analytics/trending?timeframe=24h');
    print('   - Public video: GET /video/VIDEO_ID');
    print('   - Public video API: GET /api/public/video/VIDEO_ID');
    print('   - Search users: GET /api/search/users?q=john&limit=10');
    print('   - Trending users: GET /api/search/trending?timeframe=24h&limit=5');
    print('   - Search videos: GET /api/search/videos?q=dance&limit=10');
    print('   - Search suggestions: GET /api/search/suggestions?q=jo&limit=5');
    print('   - Search debug: GET /api/search/debug/info');
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

// Helper function to build video landing page HTML
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
  final fullVideoUrl = videoUrl.startsWith('http') ? videoUrl : 'http://localhost:8080$videoUrl';

  return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title - by @$username | TikTok Clone</title>
    
    <!-- Open Graph / Facebook -->
    <meta property="og:type" content="video.other">
    <meta property="og:url" content="http://192.168.1.100:8080/video/$videoId">
    <meta property="og:title" content="$title - by @$username">
    <meta property="og:description" content="Watch this amazing video by @$username on TikTok Clone! $viewsCount views, $likesCount likes">
    <meta property="og:video" content="$fullVideoUrl">
    <meta property="og:video:type" content="video/mp4">
    <meta property="og:video:width" content="720">
    <meta property="og:video:height" content="1280">
    
    <!-- Twitter -->
    <meta property="twitter:card" content="player">
    <meta property="twitter:url" content="http://192.168.1.100:8080/video/$videoId">
    <meta property="twitter:title" content="$title - by @$username">
    <meta property="twitter:description" content="Watch this amazing video by @$username! $viewsCount views, $likesCount likes">
    <meta property="twitter:player" content="http://192.168.1.100:8080/video/$videoId/player">
    <meta property="twitter:player:width" content="720">
    <meta property="twitter:player:height" content="1280">
    
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #ff0050, #ff4081, #9c27b0);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }
        
        .container {
            max-width: 800px;
            padding: 20px;
            text-align: center;
        }
        
        .video-card {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(20px);
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .user-info {
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 20px;
        }
        
        .avatar {
            width: 60px;
            height: 60px;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.2);
            display: flex;
            align-items: center;
            justify-content: center;
            margin-right: 15px;
            font-size: 24px;
        }
        
        .username {
            font-size: 24px;
            font-weight: bold;
        }
        
        .video-title {
            font-size: 20px;
            margin: 20px 0;
            line-height: 1.4;
        }
        
        .video-player {
            width: 100%;
            max-width: 500px;
            height: 600px;
            border-radius: 15px;
            margin: 20px auto;
            background: black;
        }
        
        .stats {
            display: flex;
            justify-content: center;
            gap: 30px;
            margin: 20px 0;
            flex-wrap: wrap;
        }
        
        .stat {
            text-align: center;
        }
        
        .stat-number {
            font-size: 24px;
            font-weight: bold;
            display: block;
        }
        
        .stat-label {
            font-size: 14px;
            opacity: 0.8;
        }
        
        .download-app {
            background: linear-gradient(45deg, #ff0050, #ff4081);
            color: white;
            border: none;
            padding: 15px 30px;
            border-radius: 30px;
            font-size: 16px;
            font-weight: bold;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
            margin-top: 20px;
            transition: transform 0.2s;
        }
        
        .download-app:hover {
            transform: scale(1.05);
        }
        
        .footer {
            margin-top: 30px;
            opacity: 0.7;
            font-size: 14px;
        }
        
        @media (max-width: 600px) {
            .container {
                padding: 10px;
            }
            
            .video-card {
                padding: 20px;
            }
            
            .video-player {
                height: 400px;
            }
            
            .stats {
                gap: 15px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="video-card">
            <div class="user-info">
                <div class="avatar">
                    ${userAvatar != null ? '<img src="$userAvatar" alt="Avatar" style="width:100%; height:100%; border-radius:50%; object-fit:cover;">' : '👤'}
                </div>
                <div class="username">@$username</div>
            </div>
            
            <div class="video-title">$title</div>
            
            <video class="video-player" controls autoplay muted loop>
                <source src="$fullVideoUrl" type="video/mp4">
                Your browser does not support the video tag.
            </video>
            
            <div class="stats">
                <div class="stat">
                    <span class="stat-number">$viewsCount</span>
                    <span class="stat-label">Views</span>
                </div>
                <div class="stat">
                    <span class="stat-number">$likesCount</span>
                    <span class="stat-label">Likes</span>
                </div>
                <div class="stat">
                    <span class="stat-number">$sharesCount</span>
                    <span class="stat-label">Shares</span>
                </div>
            </div>
            
            <a href="#" class="download-app" onclick="openApp()">
                📱 Open in TikTok Clone App
            </a>
            
            <div class="footer">
                Made with ❤️ on TikTok Clone
            </div>
        </div>
    </div>
    
    <script>
        function openApp() {
            // Try to open the mobile app
            const userAgent = navigator.userAgent.toLowerCase();
            
            if (userAgent.includes('android')) {
                // Android deep link
                window.location.href = 'tiktokclone://video/$videoId';
                
                // Fallback after 2 seconds
                setTimeout(() => {
                    window.location.href = 'https://play.google.com/store/apps/details?id=com.yourcompany.tiktokclone';
                }, 2000);
                
            } else if (userAgent.includes('iphone') || userAgent.includes('ipad')) {
                // iOS deep link
                window.location.href = 'tiktokclone://video/$videoId';
                
                // Fallback after 2 seconds
                setTimeout(() => {
                    window.location.href = 'https://apps.apple.com/app/your-tiktok-clone/id123456789';
                }, 2000);
                
            } else {
                // Desktop - show QR code or redirect to web app
                alert('Scan QR code with your phone to open in the app!');
            }
        }
        
        // Track page view
        fetch('/api/videos/$videoId/share', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                shareMethod: 'public_view',
                shareText: 'Public video view'
            })
        }).catch(console.error);
    </script>
</body>
</html>
''';
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
    print('[Server] Error tracking public view: $e');
  }
}