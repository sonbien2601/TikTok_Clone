// tiktok_frontend/lib/src/features/analytics/domain/services/analytics_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tiktok_frontend/src/core/services/http_service.dart';
import 'package:tiktok_frontend/src/core/config/api_config.dart';
import '../models/analytics_model.dart';

class AnalyticsService extends ChangeNotifier {
  final HttpService _httpService = HttpService();
  
  // Track video view
  Future<bool> trackVideoView({
    required String videoId,
    String? userId,
    int viewDuration = 0,
    String viewSource = 'feed',
  }) async {
    try {
      debugPrint('[AnalyticsService] Tracking view for video: $videoId');
      
      final response = await _httpService.post(
        '/api/analytics/track-view', // FIXED: Added /api/ prefix
        body: {
          'videoId': videoId,
          'userId': userId,
          'viewDuration': viewDuration,
          'viewSource': viewSource,
          'isUniqueView': true,
        },
      );

      if (response.isSuccess) {
        final data = response.json;
        debugPrint('[AnalyticsService] View tracked successfully: ${data?['message']}');
        return true;
      } else {
        final error = response.json;
        debugPrint('[AnalyticsService] Failed to track view: ${error?['error']}');
        return false;
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error tracking view: $e');
      return false;
    }
  }

  // Bulk track views (for performance optimization)
  Future<bool> trackViewsBulk(List<Map<String, dynamic>> views) async {
    try {
      debugPrint('[AnalyticsService] Bulk tracking ${views.length} views');
      
      final response = await _httpService.post(
        '/api/analytics/track-views-bulk', // FIXED: Added /api/ prefix
        body: {
          'views': views,
        },
      );

      if (response.isSuccess) {
        final data = response.json;
        debugPrint('[AnalyticsService] Bulk views tracked: ${data?['totalProcessed']} processed');
        return true;
      } else {
        final error = response.json;
        debugPrint('[AnalyticsService] Failed to bulk track views: ${error?['error']}');
        return false;
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error bulk tracking views: $e');
      return false;
    }
  }

  // Get video analytics
  Future<VideoAnalytics?> getVideoAnalytics(String videoId) async {
    try {
      debugPrint('[AnalyticsService] Getting analytics for video: $videoId');
      
      final response = await _httpService.get('/api/analytics/video/$videoId'); // FIXED: Added /api/ prefix

      if (response.isSuccess) {
        final data = response.json;
        final analytics = VideoAnalytics.fromJson(data?['analytics']);
        debugPrint('[AnalyticsService] Video analytics retrieved successfully');
        return analytics;
      } else if (response.isNotFound) {
        debugPrint('[AnalyticsService] Video not found: $videoId');
        return null;
      } else {
        final error = response.json;
        debugPrint('[AnalyticsService] Failed to get video analytics: ${error?['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error getting video analytics: $e');
      return null;
    }
  }

  // Get user analytics
  Future<UserAnalytics?> getUserAnalytics(String userId) async {
    try {
      debugPrint('[AnalyticsService] Getting analytics for user: $userId');
      
      final response = await _httpService.get('/api/analytics/user/$userId'); // FIXED: Added /api/ prefix

      if (response.isSuccess) {
        final data = response.json;
        final analytics = UserAnalytics.fromJson(data?['analytics']);
        debugPrint('[AnalyticsService] User analytics retrieved successfully');
        return analytics;
      } else if (response.isNotFound) {
        debugPrint('[AnalyticsService] User not found or has no videos: $userId');
        return null;
      } else {
        final error = response.json;
        debugPrint('[AnalyticsService] Failed to get user analytics: ${error?['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error getting user analytics: $e');
      return null;
    }
  }

  // Get trending videos
  Future<List<TrendingVideo>> getTrendingVideos({
    String timeframe = '24h',
    int limit = 10,
  }) async {
    try {
      debugPrint('[AnalyticsService] Getting trending videos: timeframe=$timeframe, limit=$limit');
      
      final response = await _httpService.get(
        '/api/analytics/trending', // FIXED: Added /api/ prefix
        queryParameters: {
          'timeframe': timeframe,
          'limit': limit.toString(),
        },
      );

      if (response.isSuccess) {
        final data = response.json;
        final trendingVideos = (data?['trendingVideos'] as List? ?? [])
            .map((json) => TrendingVideo.fromJson(json))
            .toList();
        
        debugPrint('[AnalyticsService] Retrieved ${trendingVideos.length} trending videos');
        return trendingVideos;
      } else {
        final error = response.json;
        debugPrint('[AnalyticsService] Failed to get trending videos: ${error?['error']}');
        return [];
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error getting trending videos: $e');
      return [];
    }
  }

  // Get analytics summary
  Future<AnalyticsSummary?> getAnalyticsSummary({String timeframe = '24h'}) async {
    try {
      debugPrint('[AnalyticsService] Getting analytics summary: timeframe=$timeframe');
      
      final response = await _httpService.get(
        '/api/analytics/summary', // FIXED: Added /api/ prefix
        queryParameters: {
          'timeframe': timeframe,
        },
      );

      if (response.isSuccess) {
        final data = response.json;
        final summary = AnalyticsSummary.fromJson(data?['summary']);
        debugPrint('[AnalyticsService] Analytics summary retrieved successfully');
        return summary;
      } else {
        final error = response.json;
        debugPrint('[AnalyticsService] Failed to get analytics summary: ${error?['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error getting analytics summary: $e');
      return null;
    }
  }

  // Utility method for auto-tracking views with debouncing
  static final Map<String, DateTime> _lastViewTracks = {};
  static const Duration _viewTrackCooldown = Duration(seconds: 5);

  Future<void> autoTrackView({
    required String videoId,
    String? userId,
    int viewDuration = 0,
    String viewSource = 'feed',
  }) async {
    // Debounce view tracking to prevent spam
    final now = DateTime.now();
    final lastTrack = _lastViewTracks[videoId];
    
    if (lastTrack != null && now.difference(lastTrack) < _viewTrackCooldown) {
      debugPrint('[AnalyticsService] Skipping view track due to cooldown: $videoId');
      return;
    }

    _lastViewTracks[videoId] = now;
    
    // Track in background without waiting
    trackVideoView(
      videoId: videoId,
      userId: userId,
      viewDuration: viewDuration,
      viewSource: viewSource,
    ).catchError((error) {
      debugPrint('[AnalyticsService] Background view tracking failed: $error');
    });
  }

  // Clear view tracking cache (useful for testing or memory management)
  static void clearViewTrackingCache() {
    _lastViewTracks.clear();
    debugPrint('[AnalyticsService] View tracking cache cleared');
  }
}