// tiktok_backend/lib/src/features/search/controllers/search_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where;
import 'package:tiktok_backend/src/core/config/database_service.dart';

class SearchController {
  static Future<Response> searchUsers(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final query = queryParams['q']?.trim() ?? '';
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '20') ?? 20;
      final currentUserId = queryParams['currentUserId']; // Optional for follow status

      if (query.isEmpty) {
        return Response(400, 
          body: jsonEncode({'error': 'Search query cannot be empty'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      if (query.length < 2) {
        return Response(400, 
          body: jsonEncode({'error': 'Search query must be at least 2 characters'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final usersCollection = DatabaseService.db.collection('users');
      final followsCollection = DatabaseService.db.collection('follows');

      // Build search criteria using $or operator
      final searchCriteria = {
        r'$or': [
          {'username': RegExp(query, caseSensitive: false)},
          {'email': RegExp(query, caseSensitive: false)},
          {'displayName': RegExp(query, caseSensitive: false)},
        ]
      };

      // Get total count for pagination
      final totalUsers = await usersCollection.count(where.raw(searchCriteria));

      // Get paginated results
      final users = await usersCollection
          .find(where.raw(searchCriteria))
          .skip((page - 1) * limit)
          .take(limit)
          .toList();

      // Build response with follow status if currentUserId provided
      final searchResults = <Map<String, dynamic>>[];

      for (final user in users) {
        final userId = user['_id'] as ObjectId;
        final userResult = {
          'id': userId.toHexString(),
          'username': user['username'],
          'displayName': user['displayName'] ?? user['username'],
          'avatarUrl': user['avatarUrl'],
          'bio': user['bio'],
          'followersCount': user['followersCount'] ?? 0,
          'followingCount': user['followingCount'] ?? 0,
          'videosCount': user['videosCount'] ?? 0,
          'isVerified': user['isVerified'] ?? false,
          'createdAt': user['createdAt'],
        };

        // Add follow status if currentUserId provided
        if (currentUserId != null && currentUserId.isNotEmpty) {
          try {
            final currentUserObjectId = ObjectId.fromHexString(currentUserId);
            final followRecord = await followsCollection.findOne(
              where
                  .eq('followerId', currentUserObjectId)
                  .eq('followingId', userId)
            );
            userResult['isFollowing'] = followRecord != null;
          } catch (e) {
            userResult['isFollowing'] = false;
          }
        }

        searchResults.add(userResult);
      }

      final response = {
        'users': searchResults,
        'pagination': {
          'currentPage': page,
          'totalPages': (totalUsers / limit).ceil(),
          'totalUsers': totalUsers,
          'hasNextPage': page < (totalUsers / limit).ceil(),
          'hasPreviousPage': page > 1,
        },
        'searchQuery': query,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return Response.ok(
        jsonEncode(response),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, s) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to search users'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  static Future<Response> getTrendingUsers(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final limit = int.tryParse(queryParams['limit'] ?? '10') ?? 10;
      final timeframe = queryParams['timeframe'] ?? '7d'; // 24h, 7d, 30d
      final currentUserId = queryParams['currentUserId']; // Optional for follow status

      final usersCollection = DatabaseService.db.collection('users');
      final followsCollection = DatabaseService.db.collection('follows');

      // Get users sorted by follower count and activity
      final users = await usersCollection
          .find(where.gte('followersCount', 1).sortBy('followersCount', descending: true)) // At least 1 follower, sorted by follower count descending
          .take(limit)
          .toList();

      // Build response with follow status
      final results = <Map<String, dynamic>>[];

      for (final user in users) {
        final userId = user['_id'] as ObjectId;
        
        // Calculate simple trending score
        final followersCount = user['followersCount'] as int? ?? 0;
        final videosCount = user['videosCount'] as int? ?? 0;
        final trendingScore = (followersCount * 1.0) + (videosCount * 5.0);

        final userResult = {
          'id': userId.toHexString(),
          'username': user['username'],
          'displayName': user['displayName'] ?? user['username'],
          'avatarUrl': user['avatarUrl'],
          'bio': user['bio'],
          'followersCount': followersCount,
          'followingCount': user['followingCount'] ?? 0,
          'videosCount': videosCount,
          'isVerified': user['isVerified'] ?? false,
          'trendingScore': trendingScore,
          'recentActivity': {
            'recentVideos': videosCount,
            'recentLikes': 0,
            'recentViews': 0,
            'timeframe': timeframe,
          },
          'createdAt': user['createdAt'],
        };

        // Add follow status if currentUserId provided
        if (currentUserId != null && currentUserId.isNotEmpty) {
          try {
            final currentUserObjectId = ObjectId.fromHexString(currentUserId);
            final followRecord = await followsCollection.findOne(
              where
                  .eq('followerId', currentUserObjectId)
                  .eq('followingId', userId)
            );
            userResult['isFollowing'] = followRecord != null;
          } catch (e) {
            userResult['isFollowing'] = false;
          }
        }

        results.add(userResult);
      }

      final response = {
        'trendingUsers': results,
        'timeframe': timeframe,
        'limit': limit,
        'timestamp': DateTime.now().toIso8601String(),
        'algorithm': 'followers + videos weighted scoring',
      };

      return Response.ok(
        jsonEncode(response),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, s) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get trending users'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  static Future<Response> searchVideos(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final query = queryParams['q']?.trim() ?? '';
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '20') ?? 20;

      if (query.isEmpty) {
        return Response(400, 
          body: jsonEncode({'error': 'Search query cannot be empty'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final videosCollection = DatabaseService.db.collection('videos');
      final usersCollection = DatabaseService.db.collection('users');

      // Search in video descriptions using regex
      final searchCriteria = {
        r'$or': [
          {'description': RegExp(query, caseSensitive: false)},
          {'hashtags': RegExp(query, caseSensitive: false)},
        ]
      };

      // Get total count
      final totalVideos = await videosCollection.count(where.raw(searchCriteria));

      // Get paginated results
      final videos = await videosCollection
          .find(where.raw(searchCriteria))
          .skip((page - 1) * limit)
          .take(limit)
          .toList();

      // Enrich with user data
      final videoResults = <Map<String, dynamic>>[];

      for (final video in videos) {
        final userId = video['userId'] as ObjectId;
        final user = await usersCollection.findOne(where.id(userId));

        final videoResult = {
          'id': (video['_id'] as ObjectId).toHexString(),
          'description': video['description'],
          'videoUrl': video['videoUrl'],
          'thumbnailUrl': video['thumbnailUrl'],
          'duration': video['duration'],
          'hashtags': video['hashtags'] ?? [],
          'viewsCount': video['viewsCount'] ?? 0,
          'likesCount': video['likesCount'] ?? 0,
          'commentsCount': video['commentsCount'] ?? 0,
          'sharesCount': video['sharesCount'] ?? 0,
          'createdAt': video['createdAt'],
          'user': {
            'id': userId.toHexString(),
            'username': user?['username'] ?? 'Unknown User',
            'displayName': user?['displayName'] ?? user?['username'] ?? 'Unknown User',
            'avatarUrl': user?['avatarUrl'],
            'isVerified': user?['isVerified'] ?? false,
          },
        };

        videoResults.add(videoResult);
      }

      final response = {
        'videos': videoResults,
        'pagination': {
          'currentPage': page,
          'totalPages': (totalVideos / limit).ceil(),
          'totalVideos': totalVideos,
          'hasNextPage': page < (totalVideos / limit).ceil(),
          'hasPreviousPage': page > 1,
        },
        'searchQuery': query,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return Response.ok(
        jsonEncode(response),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, s) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to search videos'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  static Future<Response> getSearchSuggestions(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final query = queryParams['q']?.trim() ?? '';
      final limit = int.tryParse(queryParams['limit'] ?? '5') ?? 5;

      if (query.length < 2) {
        return Response.ok(
          jsonEncode({
            'suggestions': [],
            'query': query,
          }),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final usersCollection = DatabaseService.db.collection('users');

      // Get username suggestions using regex
      final users = await usersCollection
          .find(where.raw({
            'username': RegExp(query, caseSensitive: false)
          }))
          .take(limit)
          .toList();

      final userSuggestions = users.map((user) => {
        'type': 'user',
        'value': user['username'],
        'displayName': user['displayName'] ?? user['username'],
        'avatarUrl': user['avatarUrl'],
        'followersCount': user['followersCount'] ?? 0,
      }).toList();

      final response = {
        'suggestions': userSuggestions,
        'query': query,
        'limit': limit,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return Response.ok(
        jsonEncode(response),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, s) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get search suggestions'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }
}