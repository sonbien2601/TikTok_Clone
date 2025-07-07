// FINAL VERSION - Apply the manual filter fix permanently
// tiktok_backend/lib/src/features/search/search_routes.dart

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where;
import 'package:tiktok_backend/src/core/config/database_service.dart';

Router createSearchRoutes() {
  final router = Router();

  router.get('/test', (Request request) {
    return Response.ok(jsonEncode({
      'status': 'Search routes are working!',
      'version': 'Fixed exact match version',
      'timestamp': DateTime.now().toIso8601String(),
    }), headers: {'Content-Type': 'application/json'});
  });

  // FINAL FIXED USER SEARCH
  router.get('/users', (Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final query = queryParams['q']?.trim() ?? '';
      final limit = int.tryParse(queryParams['limit'] ?? '20') ?? 20;
      final currentUserId = queryParams['currentUserId'];

      print('[SearchRoutes] User search: "$query" (${query.length} chars)');

      if (query.length < 2) {
        return Response.ok(jsonEncode({
          'users': [],
          'searchQuery': query,
          'totalFound': 0,
          'searchType': 'too_short',
        }), headers: {'Content-Type': 'application/json'});
      }

      final usersCollection = DatabaseService.db.collection('users');
      final followsCollection = DatabaseService.db.collection('follows');
      
      // STEP 1: Get potential exact matches from MongoDB
      final potentialExactMatches = await usersCollection
          .find(where.raw({
            r'$or': [
              {'username': query},
              {'displayName': query},
            ]
          }))
          .toList();

      // STEP 2: Manual filter for TRUE exact matches (fix MongoDB quirks)
      final exactMatches = potentialExactMatches.where((user) {
        final username = user['username']?.toString().trim() ?? '';
        final displayName = user['displayName']?.toString().trim() ?? '';
        return username == query || displayName == query;
      }).toList();

      print('[SearchRoutes] MongoDB found ${potentialExactMatches.length}, manual filter: ${exactMatches.length}');

      List<Map<String, dynamic>> finalResults = [];
      String searchType = 'none';

      if (exactMatches.isNotEmpty) {
        // Use exact matches
        finalResults = exactMatches;
        searchType = 'exact';
        print('[SearchRoutes] Using ${exactMatches.length} exact matches');
      } else if (query.length >= 3) {
        // STEP 3: Contains search with manual filter
        final potentialContainsMatches = await usersCollection
            .find(where.raw({
              r'$or': [
                {'username': {r'$regex': query, r'$options': 'i'}},
                {'displayName': {r'$regex': query, r'$options': 'i'}},
              ]
            }))
            .take(limit * 2) // Get more to filter
            .toList();

        // Manual filter for contains (more precise)
        final containsMatches = potentialContainsMatches.where((user) {
          final username = user['username']?.toString().toLowerCase() ?? '';
          final displayName = user['displayName']?.toString().toLowerCase() ?? '';
          final queryLower = query.toLowerCase();
          return username.contains(queryLower) || displayName.contains(queryLower);
        }).take(limit).toList();

        finalResults = containsMatches;
        searchType = 'contains';
        print('[SearchRoutes] Using ${containsMatches.length} contains matches');
      } else {
        finalResults = [];
        searchType = 'none';
        print('[SearchRoutes] No matches (query too short and no exact)');
      }

      // Build response with follow status
      final results = <Map<String, dynamic>>[];
      
      for (final user in finalResults) {
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

        // Check follow status
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

      print('[SearchRoutes] Final: ${results.length} users, type: $searchType');

      return Response.ok(jsonEncode({
        'users': results,
        'searchQuery': query,
        'totalFound': results.length,
        'searchType': searchType,
      }), headers: {'Content-Type': 'application/json'});

    } catch (e, s) {
      print('[SearchRoutes] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Search failed: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  });

  // FIXED VIDEO SEARCH - Only return videos that actually contain query
  router.get('/videos', (Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final query = queryParams['q']?.trim() ?? '';
      final limit = int.tryParse(queryParams['limit'] ?? '20') ?? 20;

      print('[SearchRoutes] Video search: "$query"');

      if (query.length < 2) {
        return Response.ok(jsonEncode({
          'videos': [],
          'searchQuery': query,
          'totalFound': 0,
        }), headers: {'Content-Type': 'application/json'});
      }

      final videosCollection = DatabaseService.db.collection('videos');
      final usersCollection = DatabaseService.db.collection('users');

      // Get potential video matches
      final potentialVideos = await videosCollection
          .find(where.raw({
            r'$or': [
              {'description': {r'$regex': query, r'$options': 'i'}},
              {'hashtags': {r'$elemMatch': {r'$regex': query, r'$options': 'i'}}},
            ]
          }))
          .take(limit * 2) // Get more to filter
          .toList();

      // Manual filter - ensure videos actually contain the query
      final filteredVideos = potentialVideos.where((video) {
        final description = video['description']?.toString().toLowerCase() ?? '';
        final hashtags = (video['hashtags'] as List<dynamic>? ?? [])
            .map((h) => h.toString().toLowerCase()).toList();
        
        final queryLower = query.toLowerCase();
        final matchesDescription = description.contains(queryLower);
        final matchesHashtags = hashtags.any((tag) => tag.contains(queryLower));
        
        return matchesDescription || matchesHashtags;
      }).take(limit).toList();

      print('[SearchRoutes] Videos: MongoDB found ${potentialVideos.length}, filtered: ${filteredVideos.length}');

      // Sort manually by popularity
      filteredVideos.sort((a, b) {
        final aViews = a['viewsCount'] as int? ?? 0;
        final bViews = b['viewsCount'] as int? ?? 0;
        return bViews.compareTo(aViews);
      });

      // Build results with user data
      final results = <Map<String, dynamic>>[];

      for (final video in filteredVideos) {
        final userId = video['userId'] as ObjectId;
        final user = await usersCollection.findOne(where.id(userId));

        final videoResult = {
          'id': (video['_id'] as ObjectId).toHexString(),
          'description': video['description'] ?? '',
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
            'username': user?['username'] ?? 'Unknown',
            'displayName': user?['displayName'] ?? user?['username'] ?? 'Unknown',
            'avatarUrl': user?['avatarUrl'],
            'isVerified': user?['isVerified'] ?? false,
          },
        };

        results.add(videoResult);
      }

      return Response.ok(jsonEncode({
        'videos': results,
        'searchQuery': query,
        'totalFound': results.length,
      }), headers: {'Content-Type': 'application/json'});

    } catch (e, s) {
      print('[SearchRoutes] Video search error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Video search failed: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  });

  // TRENDING (unchanged)
  router.get('/trending', (Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final limit = int.tryParse(queryParams['limit'] ?? '10') ?? 10;
      final currentUserId = queryParams['currentUserId'];

      final usersCollection = DatabaseService.db.collection('users');
      final followsCollection = DatabaseService.db.collection('follows');
      
      final users = await usersCollection
          .find(where.gte('followersCount', 0))
          .take(50)
          .toList();

      // Sort by followers
      users.sort((a, b) {
        final aFollowers = a['followersCount'] as int? ?? 0;
        final bFollowers = b['followersCount'] as int? ?? 0;
        return bFollowers.compareTo(aFollowers);
      });

      final topUsers = users.take(limit).toList();
      final results = <Map<String, dynamic>>[];

      for (final user in topUsers) {
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
          'trendingScore': (user['followersCount'] ?? 0) * 1.0,
          'createdAt': user['createdAt'],
        };

        // Check follow status
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

      return Response.ok(jsonEncode({
        'trendingUsers': results,
        'timeframe': '7d',
      }), headers: {'Content-Type': 'application/json'});

    } catch (e, s) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Trending failed: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  });

  return router;
}