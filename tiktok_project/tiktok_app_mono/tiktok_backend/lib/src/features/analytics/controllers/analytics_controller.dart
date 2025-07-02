// tiktok_backend/lib/src/features/analytics/controllers/analytics_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, SelectorBuilder, modify, where;
import 'package:tiktok_backend/src/core/config/database_service.dart';

class AnalyticsController {
  
  // Track video view
  static Future<Response> trackVideoViewHandler(Request request) async {
    print('[AnalyticsController] Received track view request');
    
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

      final videoIdString = payload['videoId'] as String?;
      final userIdString = payload['userId'] as String?;
      final viewDuration = payload['viewDuration'] as int? ?? 0; // Duration in seconds
      final viewSource = payload['viewSource'] as String? ?? 'feed'; // 'feed', 'profile', 'search', etc.
      final isUniqueView = payload['isUniqueView'] as bool? ?? true;

      // Validate required fields
      if (videoIdString == null || videoIdString.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'videoId is required'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Convert to ObjectIds
      ObjectId videoObjectId;
      ObjectId? userObjectId;
      
      try {
        videoObjectId = ObjectId.fromHexString(videoIdString);
        if (userIdString != null && userIdString.isNotEmpty) {
          userObjectId = ObjectId.fromHexString(userIdString);
        }
      } catch (e) {
        return Response(400,
          body: jsonEncode({'error': 'Invalid videoId or userId format: $e'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final videosCollection = DatabaseService.db.collection('videos');
      final viewsCollection = DatabaseService.db.collection('video_views');

      // Check if video exists
      final video = await videosCollection.findOne(where.id(videoObjectId));
      if (video == null) {
        return Response(404,
          body: jsonEncode({'error': 'Video not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      print('[AnalyticsController] Tracking view for video: $videoIdString, user: $userIdString');

      // Create view record
      final viewRecord = {
        'videoId': videoObjectId,
        'userId': userObjectId,
        'viewDuration': viewDuration,
        'viewSource': viewSource,
        'timestamp': DateTime.now().toIso8601String(),
        'ipAddress': request.headers['x-forwarded-for'] ?? request.headers['x-real-ip'] ?? 'unknown',
        'userAgent': request.headers['user-agent'] ?? 'unknown',
      };

      // Insert view record
      await viewsCollection.insertOne(viewRecord);

      // Update video analytics
      List<ObjectId> uniqueViewers = (video['uniqueViewers'] as List?)?.whereType<ObjectId>().toList() ?? [];
      int currentViewsCount = video['viewsCount'] as int? ?? 0;
      int currentUniqueViewsCount = video['uniqueViewsCount'] as int? ?? 0;
      
      // Always increment total views
      currentViewsCount++;
      
      // Check if this is a unique view
      bool isNewUniqueViewer = false;
      if (userObjectId != null && !uniqueViewers.contains(userObjectId)) {
        uniqueViewers.add(userObjectId);
        currentUniqueViewsCount++;
        isNewUniqueViewer = true;
      } else if (userObjectId == null) {
        // For anonymous users, count as unique view (could be improved with IP tracking)
        currentUniqueViewsCount++;
        isNewUniqueViewer = true;
      }

      // Prepare analytics data update
      Map<String, dynamic> analyticsData = Map<String, dynamic>.from(video['analyticsData'] as Map? ?? {});
      
      // Update view sources analytics
      Map<String, dynamic> viewSources = Map<String, dynamic>.from(analyticsData['viewSources'] as Map? ?? {});
      viewSources[viewSource] = (viewSources[viewSource] as int? ?? 0) + 1;
      analyticsData['viewSources'] = viewSources;
      
      // Update total view duration
      analyticsData['totalViewDuration'] = (analyticsData['totalViewDuration'] as int? ?? 0) + viewDuration;
      
      // Update average view duration
      if (currentViewsCount > 0) {
        analyticsData['averageViewDuration'] = (analyticsData['totalViewDuration'] as int) / currentViewsCount;
      }

      // Update video document
      final updateResult = await videosCollection.updateOne(
        where.id(videoObjectId),
        modify
          .set('viewsCount', currentViewsCount)
          .set('uniqueViewsCount', currentUniqueViewsCount)
          .set('uniqueViewers', uniqueViewers)
          .set('analyticsData', analyticsData)
          .set('lastViewedAt', DateTime.now().toIso8601String())
          .set('updatedAt', DateTime.now().toIso8601String())
      );

      if (!updateResult.isSuccess) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to update video analytics'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      print('[AnalyticsController] View tracked successfully. Views: $currentViewsCount, Unique: $currentUniqueViewsCount');

      return Response.ok(jsonEncode({
        'message': 'View tracked successfully',
        'viewId': viewRecord['_id']?.toString(),
        'videoId': videoIdString,
        'totalViews': currentViewsCount,
        'uniqueViews': currentUniqueViewsCount,
        'isNewUniqueViewer': isNewUniqueViewer,
        'viewDuration': viewDuration,
        'viewSource': viewSource,
      }), headers: {'Content-Type': 'application/json'});

    } catch (e, stackTrace) {
      print('[AnalyticsController.trackVideoViewHandler] Error: $e');
      print('[AnalyticsController.trackVideoViewHandler] StackTrace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Get video analytics
  static Future<Response> getVideoAnalyticsHandler(Request request, String videoId) async {
    print('[AnalyticsController] Getting analytics for video: $videoId');
    
    try {
      // Validate videoId format
      if (videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
        return Response(400,
          body: jsonEncode({'error': 'Invalid video ID format'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      ObjectId videoObjectId;
      try {
        videoObjectId = ObjectId.fromHexString(videoId);
      } catch (e) {
        return Response(400,
          body: jsonEncode({'error': 'Invalid video ID format: $e'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final videosCollection = DatabaseService.db.collection('videos');
      final viewsCollection = DatabaseService.db.collection('video_views');

      // Get video with analytics
      final video = await videosCollection.findOne(where.id(videoObjectId));
      if (video == null) {
        return Response(404,
          body: jsonEncode({'error': 'Video not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Get detailed view analytics
      final views = await viewsCollection.find(where.eq('videoId', videoObjectId)).toList();
      
      // Calculate advanced analytics
      final analytics = _calculateAdvancedAnalytics(video, views);

      return Response.ok(jsonEncode({
        'videoId': videoId,
        'analytics': analytics,
        'message': 'Analytics retrieved successfully'
      }), headers: {'Content-Type': 'application/json'});

    } catch (e, stackTrace) {
      print('[AnalyticsController.getVideoAnalyticsHandler] Error: $e');
      print('[AnalyticsController.getVideoAnalyticsHandler] StackTrace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Get user analytics (videos they've uploaded)
  static Future<Response> getUserAnalyticsHandler(Request request, String userId) async {
    print('[AnalyticsController] Getting analytics for user: $userId');
    
    try {
      ObjectId userObjectId;
      try {
        userObjectId = ObjectId.fromHexString(userId);
      } catch (e) {
        return Response(400,
          body: jsonEncode({'error': 'Invalid user ID format: $e'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final videosCollection = DatabaseService.db.collection('videos');
      final viewsCollection = DatabaseService.db.collection('video_views');

      // Get all user's videos
      final userVideos = await videosCollection.find(where.eq('userId', userObjectId)).toList();
      
      if (userVideos.isEmpty) {
        return Response.ok(jsonEncode({
          'userId': userId,
          'analytics': {
            'totalVideos': 0,
            'totalViews': 0,
            'totalUniqueViews': 0,
            'totalLikes': 0,
            'totalComments': 0,
            'totalShares': 0,
            'averageEngagementRate': 0.0,
            'videos': []
          },
          'message': 'User has no videos'
        }), headers: {'Content-Type': 'application/json'});
      }

      // Calculate aggregated analytics
      int totalViews = 0;
      int totalUniqueViews = 0;
      int totalLikes = 0;
      int totalComments = 0;
      int totalShares = 0;
      double totalEngagementRate = 0.0;
      
      List<Map<String, dynamic>> videoAnalytics = [];

      for (final video in userVideos) {
        final views = await viewsCollection.find(where.eq('videoId', video['_id'])).toList();
        final analytics = _calculateAdvancedAnalytics(video, views);
        
        totalViews += analytics['viewsCount'] as int;
        totalUniqueViews += analytics['uniqueViewsCount'] as int;
        totalLikes += analytics['likesCount'] as int;
        totalComments += analytics['commentsCount'] as int;
        totalShares += analytics['sharesCount'] as int;
        totalEngagementRate += analytics['engagementRate'] as double;
        
        videoAnalytics.add({
          'videoId': video['_id'].toHexString(),
          'description': video['description'],
          'createdAt': video['createdAt'],
          'analytics': analytics
        });
      }

      final averageEngagementRate = userVideos.isNotEmpty ? totalEngagementRate / userVideos.length : 0.0;

      return Response.ok(jsonEncode({
        'userId': userId,
        'analytics': {
          'totalVideos': userVideos.length,
          'totalViews': totalViews,
          'totalUniqueViews': totalUniqueViews,
          'totalLikes': totalLikes,
          'totalComments': totalComments,
          'totalShares': totalShares,
          'averageEngagementRate': averageEngagementRate,
          'videos': videoAnalytics
        },
        'message': 'User analytics retrieved successfully'
      }), headers: {'Content-Type': 'application/json'});

    } catch (e, stackTrace) {
      print('[AnalyticsController.getUserAnalyticsHandler] Error: $e');
      print('[AnalyticsController.getUserAnalyticsHandler] StackTrace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Helper method to calculate advanced analytics
  static Map<String, dynamic> _calculateAdvancedAnalytics(Map<String, dynamic> video, List<Map<String, dynamic>> views) {
    final viewsCount = video['viewsCount'] as int? ?? 0;
    final uniqueViewsCount = video['uniqueViewsCount'] as int? ?? 0;
    final likesCount = video['likesCount'] as int? ?? 0;
    final commentsCount = video['commentsCount'] as int? ?? 0;
    final sharesCount = video['sharesCount'] as int? ?? 0;
    final analyticsData = Map<String, dynamic>.from(video['analyticsData'] as Map? ?? {});

    // Calculate engagement rate
    final totalEngagements = likesCount + commentsCount + sharesCount;
    final engagementRate = viewsCount > 0 ? (totalEngagements / viewsCount) * 100 : 0.0;

    // Calculate view retention
    final averageViewDuration = analyticsData['averageViewDuration'] as double? ?? 0.0;
    final totalViewDuration = analyticsData['totalViewDuration'] as int? ?? 0;

    // Calculate hourly view distribution
    final hourlyViews = <int, int>{};
    for (final view in views) {
      final timestamp = DateTime.tryParse(view['timestamp'] as String? ?? '');
      if (timestamp != null) {
        final hour = timestamp.hour;
        hourlyViews[hour] = (hourlyViews[hour] ?? 0) + 1;
      }
    }

    // Calculate daily views (last 7 days)
    final now = DateTime.now();
    final dailyViews = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyViews[dateKey] = 0;
    }

    for (final view in views) {
      final timestamp = DateTime.tryParse(view['timestamp'] as String? ?? '');
      if (timestamp != null && timestamp.isAfter(now.subtract(const Duration(days: 7)))) {
        final dateKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
        if (dailyViews.containsKey(dateKey)) {
          dailyViews[dateKey] = dailyViews[dateKey]! + 1;
        }
      }
    }

    return {
      'videoId': video['_id'].toHexString(),
      'viewsCount': viewsCount,
      'uniqueViewsCount': uniqueViewsCount,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'engagementRate': double.parse(engagementRate.toStringAsFixed(2)),
      'averageViewDuration': averageViewDuration,
      'totalViewDuration': totalViewDuration,
      'viewSources': analyticsData['viewSources'] ?? {},
      'hourlyViews': hourlyViews,
      'dailyViews': dailyViews,
      'createdAt': video['createdAt'],
      'lastViewedAt': video['lastViewedAt'],
      'uniqueViewRate': viewsCount > 0 ? double.parse(((uniqueViewsCount / viewsCount) * 100).toStringAsFixed(2)) : 0.0,
    };
  }

  // Get trending videos analytics
  static Future<Response> getTrendingAnalyticsHandler(Request request) async {
    print('[AnalyticsController] Getting trending videos analytics');
    
    try {
      final videosCollection = DatabaseService.db.collection('videos');
      
      // Parse query parameters
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '10') ?? 10;
      final timeframe = request.url.queryParameters['timeframe'] ?? '24h'; // 24h, 7d, 30d
      
      DateTime cutoffDate;
      switch (timeframe) {
        case '7d':
          cutoffDate = DateTime.now().subtract(const Duration(days: 7));
          break;
        case '30d':
          cutoffDate = DateTime.now().subtract(const Duration(days: 30));
          break;
        case '24h':
        default:
          cutoffDate = DateTime.now().subtract(const Duration(hours: 24));
          break;
      }

      // Get videos with high engagement in the timeframe
      final trendingVideos = await videosCollection
          .find(where
              .gte('lastViewedAt', cutoffDate.toIso8601String())
              .sortBy('viewsCount', descending: true)
              .limit(limit))
          .toList();

      final trendingAnalytics = trendingVideos.map((video) {
        final viewsCount = video['viewsCount'] as int? ?? 0;
        final likesCount = video['likesCount'] as int? ?? 0;
        final commentsCount = video['commentsCount'] as int? ?? 0;
        final sharesCount = video['sharesCount'] as int? ?? 0;
        final totalEngagements = likesCount + commentsCount + sharesCount;
        final engagementRate = viewsCount > 0 ? (totalEngagements / viewsCount) * 100 : 0.0;

        return {
          'videoId': video['_id'].toHexString(),
          'userId': video['userId'].toHexString(),
          'username': video['username'],
          'description': video['description'],
          'viewsCount': viewsCount,
          'likesCount': likesCount,
          'commentsCount': commentsCount,
          'sharesCount': sharesCount,
          'engagementRate': double.parse(engagementRate.toStringAsFixed(2)),
          'createdAt': video['createdAt'],
          'lastViewedAt': video['lastViewedAt'],
        };
      }).toList();

      return Response.ok(jsonEncode({
        'timeframe': timeframe,
        'limit': limit,
        'trendingVideos': trendingAnalytics,
        'message': 'Trending analytics retrieved successfully'
      }), headers: {'Content-Type': 'application/json'});

    } catch (e, stackTrace) {
      print('[AnalyticsController.getTrendingAnalyticsHandler] Error: $e');
      print('[AnalyticsController.getTrendingAnalyticsHandler] StackTrace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }
}