// tiktok_backend/lib/src/features/users/controllers/profile_controller.dart
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify, SelectorBuilder;
import 'package:shelf/shelf.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';

class ProfileController {
  
  // Get user profile by ID
  static Future<Response> getUserProfileHandler(Request request, String userId) async {
    print('[ProfileController] Attempting to get profile for userId: $userId');
    try {
      if (userId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(userId)) {
        return Response(400, body: jsonEncode({'error': 'Invalid user ID format'}));
      }

      final usersCollection = DatabaseService.db.collection('users');
      final userObjectId = ObjectId.fromHexString(userId);

      final Map<String, dynamic>? userDoc = await usersCollection.findOne({'_id': userObjectId});

      if (userDoc == null) {
        return Response(404, body: jsonEncode({'error': 'User not found'}));
      }

      // Remove sensitive information
      userDoc.remove('passwordHash');
      
      // Convert ObjectId to string
      if (userDoc['_id'] is ObjectId) {
        userDoc['_id'] = (userDoc['_id'] as ObjectId).toHexString();
      }
      
      // Ensure savedVideos array is converted to strings
      if (userDoc['savedVideos'] is List) {
        userDoc['savedVideos'] = (userDoc['savedVideos'] as List)
            .map((id) => id is ObjectId ? id.toHexString() : id.toString())
            .toList();
      }
      
      return Response.ok(jsonEncode(userDoc), headers: {'Content-Type': 'application/json'});

    } catch (e, stackTrace) {
      print('[ProfileController.getUserProfile] Error: $e \nStack: $stackTrace');
      if (e is FormatException && e.message.contains("ObjectId")) {
         return Response(400, body: jsonEncode({'error': 'Invalid user ID format (could not convert to ObjectId)'}));
      }
      return Response.internalServerError(body: jsonEncode({'error': 'An unexpected error occurred: $e'}));
    }
  }

  // Update user profile
  static Future<Response> updateUserProfileHandler(Request request, String userId) async {
  print('[ProfileController] Updating profile for userId: $userId');
  try {
    if (userId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(userId)) {
      return Response(400, body: jsonEncode({'error': 'Invalid user ID format'}));
    }

    final requestBody = await request.readAsString();
    if (requestBody.isEmpty) {
      return Response(400, body: jsonEncode({'error': 'Request body is empty'}));
    }

    final Map<String, dynamic> updateData;
    try {
      updateData = jsonDecode(requestBody);
    } catch (e) {
      return Response(400, body: jsonEncode({'error': 'Invalid JSON format'}));
    }

    final usersCollection = DatabaseService.db.collection('users');
    final userObjectId = ObjectId.fromHexString(userId);

    // Check if user exists
    final existingUser = await usersCollection.findOne({'_id': userObjectId});
    if (existingUser == null) {
      return Response(404, body: jsonEncode({'error': 'User not found'}));
    }

    // Build update query using modify builder
    var modifyBuilder = modify;
    bool hasUpdates = false;
    
    if (updateData.containsKey('username')) {
      final username = updateData['username'] as String?;
      if (username != null && username.trim().isNotEmpty) {
        // Check if username already exists (excluding current user)
        final existingUsername = await usersCollection.findOne({
          'username': username.toLowerCase(),
          '_id': {'\$ne': userObjectId}
        });
        if (existingUsername != null) {
          return Response(409, body: jsonEncode({'error': 'Username already exists'}));
        }
        modifyBuilder = modifyBuilder.set('username', username.trim());
        hasUpdates = true;
      }
    }

    if (updateData.containsKey('dateOfBirth')) {
      modifyBuilder = modifyBuilder.set('dateOfBirth', updateData['dateOfBirth']);
      hasUpdates = true;
    }

    if (updateData.containsKey('gender')) {
      modifyBuilder = modifyBuilder.set('gender', updateData['gender']);
      hasUpdates = true;
    }

    if (updateData.containsKey('interests')) {
      modifyBuilder = modifyBuilder.set('interests', updateData['interests']);
      hasUpdates = true;
    }

    if (!hasUpdates) {
      return Response(400, body: jsonEncode({'error': 'No valid fields to update'}));
    }

    // Add updatedAt timestamp
    modifyBuilder = modifyBuilder.set('updatedAt', DateTime.now().toIso8601String());

    print('[ProfileController] Updating user with data: ${updateData.keys}');

    // Update user using the correct modify builder
    final updateResult = await usersCollection.updateOne(
      where.id(userObjectId),
      modifyBuilder
    );

    print('[ProfileController] Update result: ${updateResult.isSuccess}');

    if (updateResult.isSuccess) {
      // Get updated user data
      final updatedUser = await usersCollection.findOne({'_id': userObjectId});
      if (updatedUser != null) {
        updatedUser.remove('passwordHash');
        if (updatedUser['_id'] is ObjectId) {
          updatedUser['_id'] = (updatedUser['_id'] as ObjectId).toHexString();
        }
        
        print('[ProfileController] Profile updated successfully for user: $userId');
        
        return Response.ok(
          jsonEncode({
            'message': 'Profile updated successfully',
            'user': updatedUser
          }),
          headers: {'Content-Type': 'application/json'}
        );
      }
    }

    print('[ProfileController] Update failed. WriteResult: ${updateResult.writeError?.errmsg ?? "Unknown error"}');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to update profile: ${updateResult.writeError?.errmsg ?? "Unknown error"}'}));

  } catch (e, stackTrace) {
    print('[ProfileController.updateUserProfile] Error: $e \nStack: $stackTrace');
    return Response.internalServerError(body: jsonEncode({'error': 'An unexpected error occurred: $e'}));
  }
}

  // Get liked videos for user
  static Future<Response> getLikedVideosHandler(Request request, String userId) async {
    print('[ProfileController] Getting liked videos for userId: $userId');
    try {
      if (userId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(userId)) {
        return Response(400, body: jsonEncode({'error': 'Invalid user ID format'}));
      }

      final userObjectId = ObjectId.fromHexString(userId);
      
      // Parse pagination parameters
      final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;
      final skip = (page - 1) * limit;

      final videosCollection = DatabaseService.db.collection('videos');
      final usersCollection = DatabaseService.db.collection('users');

      // Check if user exists
      final userDoc = await usersCollection.findOne({'_id': userObjectId});
      if (userDoc == null) {
        return Response(404, body: jsonEncode({'error': 'User not found'}));
      }

      // Get videos that the user has liked
      final likedVideosCursor = videosCollection.find(
        SelectorBuilder()
          .eq('likes', userObjectId)
          .sortBy('createdAt', descending: true)
          .skip(skip)
          .limit(limit)
      );

      // Get total count of liked videos
      final totalLikedVideos = await videosCollection.count(
        where.eq('likes', userObjectId)
      );

      final List<Map<String, dynamic>> videosList = [];
      await for (var videoDoc in likedVideosCursor) {
        final formattedVideo = _formatVideoDocument(videoDoc);
        videosList.add(formattedVideo);
      }

      final totalPages = (totalLikedVideos / limit).ceil();
      final hasNextPage = page < totalPages;
      final hasPrevPage = page > 1;

      final responseData = {
        'videos': videosList,
        'pagination': {
          'currentPage': page,
          'totalPages': totalPages,
          'totalVideos': totalLikedVideos,
          'limit': limit,
          'hasNextPage': hasNextPage,
          'hasPrevPage': hasPrevPage,
        }
      };

      return Response.ok(
        jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, stackTrace) {
      print('[ProfileController.getLikedVideos] Error: $e \nStack: $stackTrace');
      return Response.internalServerError(body: jsonEncode({'error': 'An unexpected error occurred: $e'}));
    }
  }

  // Get saved videos for user
  static Future<Response> getSavedVideosHandler(Request request, String userId) async {
    print('[ProfileController] Getting saved videos for userId: $userId');
    try {
      if (userId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(userId)) {
        return Response(400, body: jsonEncode({'error': 'Invalid user ID format'}));
      }

      final userObjectId = ObjectId.fromHexString(userId);
      
      // Parse pagination parameters
      final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;
      final skip = (page - 1) * limit;

      final videosCollection = DatabaseService.db.collection('videos');
      final usersCollection = DatabaseService.db.collection('users');

      // Check if user exists and get saved videos list
      final userDoc = await usersCollection.findOne({'_id': userObjectId});
      if (userDoc == null) {
        return Response(404, body: jsonEncode({'error': 'User not found'}));
      }

      // Get user's saved video IDs
      final savedVideoIds = (userDoc['savedVideos'] as List?)?.whereType<ObjectId>().toList() ?? [];
      
      if (savedVideoIds.isEmpty) {
        return Response.ok(
          jsonEncode({
            'videos': [],
            'pagination': {
              'currentPage': page,
              'totalPages': 1,
              'totalVideos': 0,
              'limit': limit,
              'hasNextPage': false,
              'hasPrevPage': false,
            }
          }),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Get saved videos with pagination
      final savedVideosCursor = videosCollection.find(
        SelectorBuilder()
          .oneFrom('_id', savedVideoIds)
          .sortBy('createdAt', descending: true)
          .skip(skip)
          .limit(limit)
      );

      final List<Map<String, dynamic>> videosList = [];
      await for (var videoDoc in savedVideosCursor) {
        final formattedVideo = _formatVideoDocument(videoDoc);
        videosList.add(formattedVideo);
      }

      final totalSavedVideos = savedVideoIds.length;
      final totalPages = (totalSavedVideos / limit).ceil();
      final hasNextPage = page < totalPages;
      final hasPrevPage = page > 1;

      final responseData = {
        'videos': videosList,
        'pagination': {
          'currentPage': page,
          'totalPages': totalPages,
          'totalVideos': totalSavedVideos,
          'limit': limit,
          'hasNextPage': hasNextPage,
          'hasPrevPage': hasPrevPage,
        }
      };

      return Response.ok(
        jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, stackTrace) {
      print('[ProfileController.getSavedVideos] Error: $e \nStack: $stackTrace');
      return Response.internalServerError(body: jsonEncode({'error': 'An unexpected error occurred: $e'}));
    }
  }

  // Get user's own videos
  static Future<Response> getUserVideosHandler(Request request, String userId) async {
    print('[ProfileController] Getting user videos for userId: $userId');
    try {
      if (userId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(userId)) {
        return Response(400, body: jsonEncode({'error': 'Invalid user ID format'}));
      }

      final userObjectId = ObjectId.fromHexString(userId);
      
      // Parse pagination parameters
      final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;
      final skip = (page - 1) * limit;

      final videosCollection = DatabaseService.db.collection('videos');
      final usersCollection = DatabaseService.db.collection('users');

      // Check if user exists
      final userDoc = await usersCollection.findOne({'_id': userObjectId});
      if (userDoc == null) {
        return Response(404, body: jsonEncode({'error': 'User not found'}));
      }

      // Get user's videos
      final userVideosCursor = videosCollection.find(
        SelectorBuilder()
          .eq('userId', userObjectId)
          .sortBy('createdAt', descending: true)
          .skip(skip)
          .limit(limit)
      );

      // Get total count of user's videos
      final totalUserVideos = await videosCollection.count(
        where.eq('userId', userObjectId)
      );

      final List<Map<String, dynamic>> videosList = [];
      await for (var videoDoc in userVideosCursor) {
        final formattedVideo = _formatVideoDocument(videoDoc);
        videosList.add(formattedVideo);
      }

      final totalPages = (totalUserVideos / limit).ceil();
      final hasNextPage = page < totalPages;
      final hasPrevPage = page > 1;

      final responseData = {
        'videos': videosList,
        'pagination': {
          'currentPage': page,
          'totalPages': totalPages,
          'totalVideos': totalUserVideos,
          'limit': limit,
          'hasNextPage': hasNextPage,
          'hasPrevPage': hasPrevPage,
        }
      };

      return Response.ok(
        jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, stackTrace) {
      print('[ProfileController.getUserVideos] Error: $e \nStack: $stackTrace');
      return Response.internalServerError(body: jsonEncode({'error': 'An unexpected error occurred: $e'}));
    }
  }

  // Helper method to format video document for response
  static Map<String, dynamic> _formatVideoDocument(Map<String, dynamic> videoDoc) {
    final formattedVideo = Map<String, dynamic>.from(videoDoc);
    
    // Convert ObjectIds to strings
    if (formattedVideo['_id'] is ObjectId) {
      formattedVideo['_id'] = (formattedVideo['_id'] as ObjectId).toHexString();
    }
    
    if (formattedVideo['userId'] is ObjectId) {
      formattedVideo['userId'] = (formattedVideo['userId'] as ObjectId).toHexString();
    }

    // Convert likes and saves arrays
    formattedVideo['likes'] = (formattedVideo['likes'] as List?)
        ?.whereType<ObjectId>()
        .map((id) => id.toHexString())
        .toList() ?? [];
        
    formattedVideo['saves'] = (formattedVideo['saves'] as List?)
        ?.whereType<ObjectId>()
        .map((id) => id.toHexString())
        .toList() ?? [];

    // Add user info if available
    formattedVideo['user'] = {
      'username': formattedVideo['username'] ?? 'Unknown User',
      'avatarUrl': formattedVideo['userAvatarUrl']
    };

    // Clean up denormalized fields
    formattedVideo.remove('username');
    formattedVideo.remove('userAvatarUrl');

    return formattedVideo;
  }
}