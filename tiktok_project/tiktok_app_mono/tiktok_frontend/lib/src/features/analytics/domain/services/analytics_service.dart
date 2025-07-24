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
      final response = await _httpService.post(
        '/api/analytics/track-view',
        body: {
          'videoId': videoId,
          'userId': userId,
          'viewDuration': viewDuration,
          'viewSource': viewSource,
          'isUniqueView': true,
        },
      );

      if (response.isSuccess) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Bulk track views (for performance optimization)
  Future<bool> trackViewsBulk(List<Map<String, dynamic>> views) async {
    try {
      final response = await _httpService.post(
        '/api/analytics/track-views-bulk',
        body: {
          'views': views,
        },
      );

      if (response.isSuccess) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Get video analytics
  Future<VideoAnalytics?> getVideoAnalytics(String videoId) async {
    try {
      final response = await _httpService.get('/api/analytics/video/$videoId');

      if (response.isSuccess) {
        final data = response.json;
        final analytics = VideoAnalytics.fromJson(data?['analytics']);
        return analytics;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Get user analytics
  Future<UserAnalytics?> getUserAnalytics(String userId) async {
    try {
      final response = await _httpService.get('/api/analytics/user/$userId');

      if (response.isSuccess) {
        final data = response.json;
        final analytics = UserAnalytics.fromJson(data?['analytics']);
        return analytics;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Get trending videos
  Future<List<TrendingVideo>> getTrendingVideos({
    String timeframe = '24h',
    int limit = 10,
  }) async {
    try {
      final response = await _httpService.get(
        '/api/analytics/trending',
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
        
        return trendingVideos;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Get analytics summary
  Future<AnalyticsSummary?> getAnalyticsSummary({String timeframe = '24h'}) async {
    try {
      final response = await _httpService.get(
        '/api/analytics/summary',
        queryParameters: {
          'timeframe': timeframe,
        },
      );

      if (response.isSuccess) {
        final data = response.json;
        final summary = AnalyticsSummary.fromJson(data?['summary']);
        return summary;
      } else {
        return null;
      }
    } catch (e) {
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
      return;
    }

    _lastViewTracks[videoId] = now;
    
    // Track in background without waiting
    trackVideoView(
      videoId: videoId,
      userId: userId,
      viewDuration: viewDuration,
      viewSource: viewSource,
    ).catchError((error) {});
  }

  // Clear view tracking cache (useful for testing or memory management)
  static void clearViewTrackingCache() {
    _lastViewTracks.clear();
  }
}