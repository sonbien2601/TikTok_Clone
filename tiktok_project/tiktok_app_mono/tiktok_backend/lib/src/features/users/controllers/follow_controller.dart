// tiktok_backend/lib/src/features/users/controllers/follow_controller.dart
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify, SelectorBuilder;
import 'package:shelf/shelf.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';

class FollowController {
  
  // Follow a user
  static Future<Response> followUserHandler(Request request, String currentUserId, String targetUserId) async {
    print('[FollowController] User $currentUserId attempting to follow $targetUserId');
    
    try {
      // Validate user IDs
      if (currentUserId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(currentUserId) ||
          targetUserId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(targetUserId)) {
        return Response(400, body: jsonEncode({'error': 'Invalid user ID format'}));
      }

      // Prevent self-follow
      if (currentUserId == targetUserId) {
        return Response(400, body: jsonEncode({'error': 'Cannot follow yourself'}));
      }

      final usersCollection = DatabaseService.db.collection('users');
      final currentUserObjectId = ObjectId.fromHexString(currentUserId);
      final targetUserObjectId = ObjectId.fromHexString(targetUserId);

      // Check if both users exist
      final currentUser = await usersCollection.findOne({'_id': currentUserObjectId});
      final targetUser = await usersCollection.findOne({'_id': targetUserObjectId});

      if (currentUser == null) {
        return Response(404, body: jsonEncode({'error': 'Current user not found'}));
      }
      if (targetUser == null) {
        return Response(404, body: jsonEncode({'error': 'Target user not found'}));
      }

      // Check if already following
      final currentUserFollowing = (currentUser['following'] as List?)?.cast<ObjectId>() ?? [];
      if (currentUserFollowing.contains(targetUserObjectId)) {
        return Response(409, body: jsonEncode({'error': 'Already following this user'}));
      }

      // Update current user's following list
      final updateCurrentUser = await usersCollection.updateOne(
        where.id(currentUserObjectId),
        modify
          .push('following', targetUserObjectId)
          .inc('followingCount', 1)
          .set('updatedAt', DateTime.now().toIso8601String())
      );

      // Update target user's followers list
      final updateTargetUser = await usersCollection.updateOne(
        where.id(targetUserObjectId),
        modify
          .push('followers', currentUserObjectId)
          .inc('followersCount', 1)
          .set('updatedAt', DateTime.now().toIso8601String())
      );

      if (updateCurrentUser.isSuccess && updateTargetUser.isSuccess) {
        // Get updated counts
        final updatedCurrentUser = await usersCollection.findOne({'_id': currentUserObjectId});
        final updatedTargetUser = await usersCollection.findOne({'_id': targetUserObjectId});

        return Response.ok(
          jsonEncode({
            'message': 'Successfully followed user',
            'isFollowing': true,
            'followerCount': updatedTargetUser?['followersCount'] ?? 0,
            'followingCount': updatedCurrentUser?['followingCount'] ?? 0,
          }),
          headers: {'Content-Type': 'application/json'}
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to update follow relationship'})
        );
      }

    } catch (e, stackTrace) {
      print('[FollowController.followUser] Error: $e \nStack: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'})
      );
    }
  }

  // Unfollow a user
  static Future<Response> unfollowUserHandler(Request request, String currentUserId, String targetUserId) async {
    print('[FollowController] User $currentUserId attempting to unfollow $targetUserId');
    
    try {
      // Validate user IDs
      if (currentUserId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(currentUserId) ||
          targetUserId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(targetUserId)) {
        return Response(400, body: jsonEncode({'error': 'Invalid user ID format'}));
      }

      // Prevent self-unfollow
      if (currentUserId == targetUserId) {
        return Response(400, body: jsonEncode({'error': 'Cannot unfollow yourself'}));
      }

      final usersCollection = DatabaseService.db.collection('users');
      final currentUserObjectId = ObjectId.fromHexString(currentUserId);
      final targetUserObjectId = ObjectId.fromHexString(targetUserId);

      // Check if both users exist
      final currentUser = await usersCollection.findOne({'_id': currentUserObjectId});
      final targetUser = await usersCollection.findOne({'_id': targetUserObjectId});

      if (currentUser == null) {
        return Response(404, body: jsonEncode({'error': 'Current user not found'}));
      }
      if (targetUser == null) {
        return Response(404, body: jsonEncode({'error': 'Target user not found'}));
      }

      // Check if currently following
      final currentUserFollowing = (currentUser['following'] as List?)?.cast<ObjectId>() ?? [];
      if (!currentUserFollowing.contains(targetUserObjectId)) {
        return Response(409, body: jsonEncode({'error': 'Not following this user'}));
      }

      // Update current user's following list
      final updateCurrentUser = await usersCollection.updateOne(
        where.id(currentUserObjectId),
        modify
          .pull('following', targetUserObjectId)
          .inc('followingCount', -1)
          .set('updatedAt', DateTime.now().toIso8601String())
      );

      // Update target user's followers list
      final updateTargetUser = await usersCollection.updateOne(
        where.id(targetUserObjectId),
        modify
          .pull('followers', currentUserObjectId)
          .inc('followersCount', -1)
          .set('updatedAt', DateTime.now().toIso8601String())
      );

      if (updateCurrentUser.isSuccess && updateTargetUser.isSuccess) {
        // Get updated counts
        final updatedCurrentUser = await usersCollection.findOne({'_id': currentUserObjectId});
        final updatedTargetUser = await usersCollection.findOne({'_id': targetUserObjectId});

        return Response.ok(
          jsonEncode({
            'message': 'Successfully unfollowed user',
            'isFollowing': false,
            'followerCount': updatedTargetUser?['followersCount'] ?? 0,
            'followingCount': updatedCurrentUser?['followingCount'] ?? 0,
          }),
          headers: {'Content-Type': 'application/json'}
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to update unfollow relationship'})
        );
      }

    } catch (e, stackTrace) {
      print('[FollowController.unfollowUser] Error: $e \nStack: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'})
      );
    }
  }

  // Get followers list
  static Future<Response> getFollowersHandler(Request request, String userId) async {
    print('[FollowController] Getting followers for user: $userId');
    
    try {
      if (userId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(userId)) {
        return Response(400, body: jsonEncode({'error': 'Invalid user ID format'}));
      }

      final userObjectId = ObjectId.fromHexString(userId);
      
      // Parse pagination parameters
      final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;
      final skip = (page - 1) * limit;

      final usersCollection = DatabaseService.db.collection('users');

      // Check if user exists
      final user = await usersCollection.findOne({'_id': userObjectId});
      if (user == null) {
        return Response(404, body: jsonEncode({'error': 'User not found'}));
      }

      // Get followers list
      final followerIds = (user['followers'] as List?)?.cast<ObjectId>() ?? [];
      
      if (followerIds.isEmpty) {
        return Response.ok(
          jsonEncode({
            'followers': [],
            'pagination': {
              'currentPage': page,
              'totalPages': 1,
              'totalFollowers': 0,
              'limit': limit,
              'hasNextPage': false,
              'hasPrevPage': false,
            }
          }),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Get paginated followers
      final followersCursor = usersCollection.find(
        SelectorBuilder()
          .oneFrom('_id', followerIds)
          .sortBy('username', descending: false)
          .skip(skip)
          .limit(limit)
      );

      final List<Map<String, dynamic>> followersList = [];
      await for (var followerDoc in followersCursor) {
        final formattedFollower = _formatUserDocument(followerDoc);
        followersList.add(formattedFollower);
      }

      final totalFollowers = followerIds.length;
      final totalPages = (totalFollowers / limit).ceil();
      final hasNextPage = page < totalPages;
      final hasPrevPage = page > 1;

      return Response.ok(
        jsonEncode({
          'followers': followersList,
          'pagination': {
            'currentPage': page,
            'totalPages': totalPages,
            'totalFollowers': totalFollowers,
            'limit': limit,
            'hasNextPage': hasNextPage,
            'hasPrevPage': hasPrevPage,
          }
        }),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, stackTrace) {
      print('[FollowController.getFollowers] Error: $e \nStack: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'})
      );
    }
  }

  // Get following list
  static Future<Response> getFollowingHandler(Request request, String userId) async {
    print('[FollowController] Getting following for user: $userId');
    
    try {
      if (userId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(userId)) {
        return Response(400, body: jsonEncode({'error': 'Invalid user ID format'}));
      }

      final userObjectId = ObjectId.fromHexString(userId);
      
      // Parse pagination parameters
      final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;
      final skip = (page - 1) * limit;

      final usersCollection = DatabaseService.db.collection('users');

      // Check if user exists
      final user = await usersCollection.findOne({'_id': userObjectId});
      if (user == null) {
        return Response(404, body: jsonEncode({'error': 'User not found'}));
      }

      // Get following list
      final followingIds = (user['following'] as List?)?.cast<ObjectId>() ?? [];
      
      if (followingIds.isEmpty) {
        return Response.ok(
          jsonEncode({
            'following': [],
            'pagination': {
              'currentPage': page,
              'totalPages': 1,
              'totalFollowing': 0,
              'limit': limit,
              'hasNextPage': false,
              'hasPrevPage': false,
            }
          }),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Get paginated following
      final followingCursor = usersCollection.find(
        SelectorBuilder()
          .oneFrom('_id', followingIds)
          .sortBy('username', descending: false)
          .skip(skip)
          .limit(limit)
      );

      final List<Map<String, dynamic>> followingList = [];
      await for (var followingDoc in followingCursor) {
        final formattedFollowing = _formatUserDocument(followingDoc);
        followingList.add(formattedFollowing);
      }

      final totalFollowing = followingIds.length;
      final totalPages = (totalFollowing / limit).ceil();
      final hasNextPage = page < totalPages;
      final hasPrevPage = page > 1;

      return Response.ok(
        jsonEncode({
          'following': followingList,
          'pagination': {
            'currentPage': page,
            'totalPages': totalPages,
            'totalFollowing': totalFollowing,
            'limit': limit,
            'hasNextPage': hasNextPage,
            'hasPrevPage': hasPrevPage,
          }
        }),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, stackTrace) {
      print('[FollowController.getFollowing] Error: $e \nStack: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'})
      );
    }
  }

  // Check follow status between two users
  static Future<Response> checkFollowStatusHandler(Request request, String currentUserId, String targetUserId) async {
    print('[FollowController] Checking follow status between $currentUserId and $targetUserId');
    
    try {
      if (currentUserId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(currentUserId) ||
          targetUserId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(targetUserId)) {
        return Response(400, body: jsonEncode({'error': 'Invalid user ID format'}));
      }

      final usersCollection = DatabaseService.db.collection('users');
      final currentUserObjectId = ObjectId.fromHexString(currentUserId);
      final targetUserObjectId = ObjectId.fromHexString(targetUserId);

      // Get both users
      final currentUser = await usersCollection.findOne({'_id': currentUserObjectId});
      final targetUser = await usersCollection.findOne({'_id': targetUserObjectId});

      if (currentUser == null || targetUser == null) {
        return Response(404, body: jsonEncode({'error': 'User not found'}));
      }

      // Check follow status
      final currentUserFollowing = (currentUser['following'] as List?)?.cast<ObjectId>() ?? [];
      final isFollowing = currentUserFollowing.contains(targetUserObjectId);

      return Response.ok(
        jsonEncode({
          'isFollowing': isFollowing,
          'targetUser': {
            'id': targetUser['_id'].toHexString(),
            'username': targetUser['username'],
            'followersCount': targetUser['followersCount'] ?? 0,
            'followingCount': targetUser['followingCount'] ?? 0,
          },
        }),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, stackTrace) {
      print('[FollowController.checkFollowStatus] Error: $e \nStack: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'})
      );
    }
  }

  // Helper method to format user document for response
  static Map<String, dynamic> _formatUserDocument(Map<String, dynamic> userDoc) {
    final formattedUser = Map<String, dynamic>.from(userDoc);
    
    // Convert ObjectId to string
    if (formattedUser['_id'] is ObjectId) {
      formattedUser['id'] = (formattedUser['_id'] as ObjectId).toHexString();
      formattedUser.remove('_id');
    }

    // Remove sensitive information
    formattedUser.remove('passwordHash');
    formattedUser.remove('email'); // Don't expose email in lists
    formattedUser.remove('savedVideos');
    formattedUser.remove('following');
    formattedUser.remove('followers');

    // Keep only public profile data
    return {
      'id': formattedUser['id'],
      'username': formattedUser['username'],
      'dateOfBirth': formattedUser['dateOfBirth'],
      'gender': formattedUser['gender'],
      'interests': formattedUser['interests'] ?? [],
      'followersCount': formattedUser['followersCount'] ?? 0,
      'followingCount': formattedUser['followingCount'] ?? 0,
      'createdAt': formattedUser['createdAt'],
    };
  }
}