// tiktok_backend/lib/src/features/analytics/analytics_routes.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'controllers/analytics_controller.dart';

Router createAnalyticsRoutes() {
  final router = Router();

  // Track video view
  router.post('/track-view', (Request request) async {
    print('[AnalyticsRoutes] Track view route hit');
    try {
      return await AnalyticsController.trackVideoViewHandler(request);
    } catch (e, stackTrace) {
      print('[AnalyticsRoutes] Error in track view route: $e');
      print('[AnalyticsRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  });

  // Get video analytics
  router.get('/video/<videoId>', (Request request, String videoId) async {
    print('[AnalyticsRoutes] Get video analytics route hit with videoId: $videoId');

    if (videoId.isEmpty) {
      return Response(400,
        body: jsonEncode({
          'error': 'Video ID is required',
          'receivedVideoId': videoId,
          'path': request.url.path,
        }),
        headers: {'Content-Type': 'application/json'}
      );
    }

    try {
      return await AnalyticsController.getVideoAnalyticsHandler(request, videoId);
    } catch (e, stackTrace) {
      print('[AnalyticsRoutes] Error in get video analytics route: $e');
      print('[AnalyticsRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  });

  // Get user analytics
  router.get('/user/<userId>', (Request request, String userId) async {
    print('[AnalyticsRoutes] Get user analytics route hit with userId: $userId');

    if (userId.isEmpty) {
      return Response(400,
        body: jsonEncode({
          'error': 'User ID is required',
          'receivedUserId': userId,
          'path': request.url.path,
        }),
        headers: {'Content-Type': 'application/json'}
      );
    }

    try {
      return await AnalyticsController.getUserAnalyticsHandler(request, userId);
    } catch (e, stackTrace) {
      print('[AnalyticsRoutes] Error in get user analytics route: $e');
      print('[AnalyticsRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  });

  // Get trending videos analytics
  router.get('/trending', (Request request) async {
    print('[AnalyticsRoutes] Get trending analytics route hit');
    try {
      return await AnalyticsController.getTrendingAnalyticsHandler(request);
    } catch (e, stackTrace) {
      print('[AnalyticsRoutes] Error in get trending analytics route: $e');
      print('[AnalyticsRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  });

  // Bulk track views (for batch processing)
  router.post('/track-views-bulk', (Request request) async {
    print('[AnalyticsRoutes] Bulk track views route hit');
    
    try {
      final requestBody = await request.readAsString();
      if (requestBody.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'Request body is required'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(requestBody);
      } catch (e) {
        return Response(400,
          body: jsonEncode({'error': 'Invalid JSON format: $e'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final views = payload['views'] as List?;
      if (views == null || views.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'views array is required and cannot be empty'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Process each view (simplified bulk processing)
      final results = <Map<String, dynamic>>[];
      for (final viewData in views) {
        if (viewData is Map<String, dynamic>) {
          // Create a mock request for each view
          final mockRequest = Request('POST', Uri.parse('/track-view'), 
            body: jsonEncode(viewData),
            headers: {'content-type': 'application/json'}
          );
          
          final result = await AnalyticsController.trackVideoViewHandler(mockRequest);
          final resultBody = await result.readAsString();
          results.add({
            'videoId': viewData['videoId'],
            'status': result.statusCode,
            'response': jsonDecode(resultBody)
          });
        }
      }

      return Response.ok(jsonEncode({
        'message': 'Bulk views processed',
        'totalProcessed': results.length,
        'results': results
      }), headers: {'Content-Type': 'application/json'});

    } catch (e, stackTrace) {
      print('[AnalyticsRoutes] Error in bulk track views route: $e');
      print('[AnalyticsRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  });

  // Get analytics summary for dashboard
  router.get('/summary', (Request request) async {
    print('[AnalyticsRoutes] Get analytics summary route hit');
    
    try {
      final timeframe = request.url.queryParameters['timeframe'] ?? '24h';
      
      // This would typically aggregate data from multiple collections
      // For now, return a basic summary
      return Response.ok(jsonEncode({
        'timeframe': timeframe,
        'summary': {
          'totalViews': 0, // Would be calculated from actual data
          'totalUniqueViews': 0,
          'totalVideos': 0,
          'averageEngagementRate': 0.0,
          'topPerformingVideos': [],
          'viewTrends': {},
        },
        'message': 'Analytics summary retrieved successfully'
      }), headers: {'Content-Type': 'application/json'});

    } catch (e, stackTrace) {
      print('[AnalyticsRoutes] Error in get analytics summary route: $e');
      print('[AnalyticsRoutes] StackTrace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
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
      'message': 'Analytics routes debug info',
      'availableRoutes': [
        'POST /api/analytics/track-view',
        'POST /api/analytics/track-views-bulk',
        'GET /api/analytics/video/{videoId}',
        'GET /api/analytics/user/{userId}',
        'GET /api/analytics/trending?timeframe=24h&limit=10',
        'GET /api/analytics/summary?timeframe=24h',
        'GET /api/analytics/debug/info',
      ],
      'examples': [
        'POST /api/analytics/track-view - Body: {"videoId": "...", "userId": "...", "viewDuration": 30, "viewSource": "feed"}',
        'GET /api/analytics/video/683c24fffdf60af9cddfb22a',
        'GET /api/analytics/user/683c24fffdf60af9cddfb22a',
        'GET /api/analytics/trending?timeframe=7d&limit=20'
      ],
      'features': [
        'Track individual video views',
        'Bulk view tracking',
        'Video analytics with engagement metrics',
        'User analytics across all videos',
        'Trending videos analysis',
        'View source tracking',
        'Engagement rate calculations',
        'Hourly and daily view distributions'
      ]
    }), headers: {'Content-Type': 'application/json'});
  });

  return router;
}