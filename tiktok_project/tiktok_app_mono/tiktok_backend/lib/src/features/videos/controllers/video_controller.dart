import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:path/path.dart' as p;
import 'package:shelf_router/src/router.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, SelectorBuilder, modify, where;

class VideoController {
  // --- HÀM UPLOAD VIDEO ---
  static Future<Response> uploadVideoHandler(Request request) async {
    print('[VideoController] Received video upload request. Headers: ${request.headers}');
    try {
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.startsWith('multipart/form-data')) {
        print('[VideoController] Error: Not a multipart request. Content-Type: $contentType');
        return Response(400,
            body: jsonEncode({
              'error': 'Invalid request: Content-Type must be multipart/form-data.'
            }));
      }

      String? description;
      String? userIdString;
      List<int>? videoBytes;
      String? originalVideoFileName;
      String? videoMimeType;

      print('[VideoController] Starting to read multipart parts...');

      final multipartRequest = request.multipart();
      if (multipartRequest == null) {
        return Response(400,
            body: jsonEncode({
              'error': 'Failed to parse multipart data (multipartRequest is null)'
            }));
      }

      await for (final part in multipartRequest.parts) {
        final contentDisposition = part.headers['content-disposition'];
        final contentTypeHeader = part.headers['content-type'];

        print('[VideoController] Processing part. Disposition: $contentDisposition, Content-Type: $contentTypeHeader');

        if (contentDisposition != null) {
          final Map<String, String> params = _parseContentDisposition(contentDisposition);
          final partName = params['name'];
          final filename = params['filename'];

          print('[VideoController] Part name: $partName, filename: $filename');

          if (partName == 'description') {
            final bytes = await _readAllBytes(part);
            description = utf8.decode(bytes);
            print('[VideoController] Description: "$description"');
          } else if (partName == 'userId') {
            final bytes = await _readAllBytes(part);
            userIdString = utf8.decode(bytes);
            print('[VideoController] UserID from client: "$userIdString"');
          } else if (partName == 'videoFile') {
            originalVideoFileName = filename;
            videoMimeType = contentTypeHeader;
            print('[VideoController] Original video filename: "$originalVideoFileName", MimeType: "$videoMimeType"');
            videoBytes = await _readAllBytes(part);
            print('[VideoController] Video file bytes received: ${videoBytes.length} bytes');
          } else {
            print('[VideoController] Skipping unhandled part: $partName');
            await _readAllBytes(part);
          }
        } else {
          print('[VideoController] Skipping part with no content-disposition header.');
          await _readAllBytes(part);
        }
      }

      // Validation
      if (videoBytes == null || videoBytes.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'Video file is required.'}));
      }
      if (description == null || description.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'Video description is required.'}));
      }
      if (userIdString == null || userIdString.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'User ID is required for upload.'}));
      }

      ObjectId userObjectId;
      try {
        userObjectId = ObjectId.fromHexString(userIdString);
      } catch (e) {
        print('[VideoController] Invalid userId format: $userIdString');
        return Response(400, body: jsonEncode({'error': 'Invalid user ID format.'}));
      }

      // Tạo thư mục uploads nếu chưa tồn tại
      final uploadDir = Directory('uploads');
      if (!await uploadDir.exists()) {
        await uploadDir.create(recursive: true);
        print('[VideoController] Created directory: ${uploadDir.path}');
      }

      // Xác định extension của file
      String fileExtension = '.mp4';
      if (originalVideoFileName != null && originalVideoFileName.contains('.')) {
        fileExtension = p.extension(originalVideoFileName).toLowerCase();
      } else if (videoMimeType != null) {
        if (videoMimeType.contains('mp4')) fileExtension = '.mp4';
        else if (videoMimeType.contains('mov')) fileExtension = '.mov';
        else if (videoMimeType.contains('x-m4v')) fileExtension = '.m4v';
        else if (videoMimeType.contains('avi')) fileExtension = '.avi';
        else if (videoMimeType.contains('mpeg')) fileExtension = '.mpeg';
      }

      // Tạo tên file unique
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${userObjectId.toHexString()}_${timestamp}$fileExtension';
      final videoPath = p.join(uploadDir.path, uniqueFileName);

      // Lưu file video
      final file = File(videoPath);
      await file.writeAsBytes(videoBytes);
      print('[VideoController] Video saved to: $videoPath');

      // Lưu metadata vào database
      final videosCollection = DatabaseService.db.collection('videos');
      final usersCollection = DatabaseService.db.collection('users');

      // FIXED: Lấy thông tin user để denormalize vào video document
      print('[VideoController] Fetching user info for userId: $userObjectId');
      final userDocForVideo = await usersCollection.findOne(where.id(userObjectId));

      if (userDocForVideo == null) {
        print('[VideoController] ❌ User not found for ID: $userObjectId');
        // Cleanup file
        if (await file.exists()) {
          try {
            await file.delete();
            print('[VideoController] Cleaned up uploaded file due to missing user.');
          } catch (e) {
            print('[VideoController] Error deleting file: $e');
          }
        }
        return Response(404, body: jsonEncode({'error': 'User not found. Please ensure you are logged in properly.'}));
      }

      final String username = userDocForVideo['username'] as String? ?? 'Unknown User';
      final String? userAvatarUrl = userDocForVideo['avatarUrl'] as String?;

      print('[VideoController] Found user: username="$username", avatarUrl="$userAvatarUrl"');

      // Đảm bảo username không rỗng
      if (username.isEmpty || username == 'Unknown User') {
        print('[VideoController] ⚠️ Warning: Username is empty or Unknown User for userId: $userObjectId');
        print('[VideoController] User document: $userDocForVideo');
      }

      // UPDATED: Thêm analytics fields vào video document
      final videoDocument = {
        'userId': userObjectId,
        'username': username,
        'userAvatarUrl': userAvatarUrl,
        'description': description,
        'videoUrl': '/uploads/$uniqueFileName',
        'likes': <ObjectId>[],
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'saves': <ObjectId>[],
        // NEW: Analytics fields
        'viewsCount': 0,
        'uniqueViewsCount': 0,
        'uniqueViewers': <ObjectId>[],
        'analyticsData': {
          'viewSources': <String, int>{},
          'totalViewDuration': 0,
          'averageViewDuration': 0.0,
        },
        'lastViewedAt': null,
        'hashtags': _extractHashtags(description),
        'originalFileName': originalVideoFileName,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      print('[VideoController] Video document to be inserted:');
      print('[VideoController] - userId: $userObjectId');
      print('[VideoController] - username: "$username"');
      print('[VideoController] - userAvatarUrl: "$userAvatarUrl"');
      print('[VideoController] - description: "$description"');

      final result = await videosCollection.insertOne(videoDocument);
      if (result.isSuccess) {
        // Verify the inserted document
        final insertedDoc = await videosCollection.findOne(where.id(result.id));
        print('[VideoController] ✅ Inserted video with:');
        print('[VideoController] - username: "${insertedDoc?['username']}"');
        print('[VideoController] - userAvatarUrl: "${insertedDoc?['userAvatarUrl']}"');

        videoDocument['_id'] = result.id.toHexString();
        videoDocument['likes'] = [];
        videoDocument['saves'] = [];
        videoDocument['userId'] = userObjectId.toHexString();

        print('[VideoController] Video metadata saved to MongoDB. Doc ID: ${result.id.toHexString()}');
        return Response.ok(jsonEncode({
          'message': 'Video uploaded and metadata saved successfully!',
          'video': videoDocument
        }), headers: {'Content-Type': 'application/json'});
      } else {
        // Cleanup file nếu DB save thất bại
        if (await file.exists()) {
          try {
            await file.delete();
            print('[VideoController] Cleaned up uploaded file due to DB error.');
          } catch (e) {
            print('[VideoController] Error deleting file after DB error: $e');
          }
        }
        print('[VideoController] Failed to save video metadata: ${result.writeError?.errmsg}');
        return Response.internalServerError(body: jsonEncode({'error': 'Failed to save video metadata.'}));
      }

    } catch (e, stackTrace) {
      print('[VideoController.uploadVideoHandler] Error: $e');
      print('[VideoController.uploadVideoHandler] StackTrace: $stackTrace');

      if (e is FormatException) {
        return Response(400,
            body: jsonEncode(
                {'error': 'Invalid data format in request: ${e.message}'}));
      }

      if (e.toString().contains("Failed to parse multipart data") ||
          e.toString().contains("Multipart") ||
          e.toString().contains("mime")) {
        return Response(400, body: jsonEncode({'error': 'Error parsing multipart request.'}));
      }

      return Response.internalServerError(
          body: jsonEncode({'error': 'An unexpected error occurred during upload: $e'}));
    }
  }

  static Future<Response> getVideoByIdHandler(Request request, String videoId) async {
    print('[VideoController] Getting video by ID: $videoId');

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
      final usersCollection = DatabaseService.db.collection('users');

      // Find the video
      final videoDoc = await videosCollection.findOne(where.id(videoObjectId));
      if (videoDoc == null) {
        print('[VideoController] Video not found: $videoId');
        return Response(404,
          body: jsonEncode({
            'error': 'Video not found',
            'videoId': videoId,
            'message': 'The requested video does not exist or has been deleted'
          }),
          headers: {'Content-Type': 'application/json'}
        );
      }

      print('[VideoController] Found video: ${videoDoc['_id']}');

      // Get user info để đảm bảo có username
      final userId = videoDoc['userId'] as ObjectId;
      String username = videoDoc['username'] as String? ?? '';
      String? userAvatarUrl = videoDoc['userAvatarUrl'] as String?;

      // Nếu username thiếu, fetch từ users collection
      if (username.isEmpty || username == 'Unknown User') {
        print('[VideoController] Username missing, fetching from users collection...');

        final userDoc = await usersCollection.findOne(where.id(userId));
        if (userDoc != null) {
          username = userDoc['username'] as String? ?? 'Unknown User';
          userAvatarUrl = userDoc['avatarUrl'] as String?;

          // Update video document với username correct
          await videosCollection.updateOne(
            where.id(videoObjectId),
            modify.set('username', username).set('userAvatarUrl', userAvatarUrl)
          );

          print('[VideoController] Updated video with correct username: $username');
        } else {
          username = 'Deleted User';
        }
      }

      // Format response
      final responseVideo = Map<String, dynamic>.from(videoDoc);
      responseVideo['_id'] = videoObjectId.toHexString();
      responseVideo['userId'] = userId.toHexString();
      responseVideo['username'] = username;
      responseVideo['userAvatarUrl'] = userAvatarUrl;

      // Convert likes và saves arrays
      responseVideo['likes'] = (videoDoc['likes'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
      responseVideo['saves'] = (videoDoc['saves'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];

      // NEW: Add analytics data
      responseVideo['viewsCount'] = videoDoc['viewsCount'] as int? ?? 0;
      responseVideo['uniqueViewsCount'] = videoDoc['uniqueViewsCount'] as int? ?? 0;
      responseVideo['uniqueViewers'] = (videoDoc['uniqueViewers'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
      responseVideo['analyticsData'] = videoDoc['analyticsData'] ?? {};
      responseVideo['lastViewedAt'] = videoDoc['lastViewedAt'];

      // Add user object for frontend compatibility
      responseVideo['user'] = {
        'username': username,
        'avatarUrl': userAvatarUrl
      };

      print('[VideoController] ✅ Video retrieved successfully: $videoId');

      return Response.ok(
        jsonEncode({
          'video': responseVideo,
          'message': 'Video retrieved successfully'
        }),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, s) {
      print('[VideoController.getVideoByIdHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // --- HÀM LẤY DANH SÁCH VIDEO CHO FEED - FIXED ---
  static Future<Response> getFeedVideosHandler(Request request) async {
    print('[VideoController] Received request for feed videos.');
    try {
      final videosCollection = DatabaseService.db.collection('videos');
      final usersCollection = DatabaseService.db.collection('users');

      final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '10') ?? 10;
      final skip = (page - 1) * limit;

      print('[VideoController] Fetching feed: page $page, limit $limit, skip $skip');

      final videoDocsCursor = videosCollection.find(
        SelectorBuilder()
          .sortBy('createdAt', descending: true)
          .skip(skip)
          .limit(limit)
      );

      final List<Map<String, dynamic>> videosWithUserInfo = [];
      int videoIndex = 0;

      await for (var videoDoc in videoDocsCursor) {
        print('[VideoController] === Processing video $videoIndex ===');
        print('[VideoController] Video ID: ${videoDoc['_id']}');
        print('[VideoController] UserId in video: ${videoDoc['userId']}');

        final Map<String, dynamic> videoWithUser = Map.from(videoDoc);

        // Lấy thông tin user
        String username = videoDoc['username'] as String? ?? '';
        String? userAvatarUrl = videoDoc['userAvatarUrl'] as String?;
        final ObjectId userId = videoDoc['userId'] as ObjectId;

        print('[VideoController] Initial username from video doc: "$username"');
        print('[VideoController] Initial userAvatarUrl from video doc: "$userAvatarUrl"');

        // Nếu username bị thiếu hoặc là "Unknown User", fetch lại từ users collection
        if (username.isEmpty || username == 'Unknown User' || username == 'null') {
          print('[VideoController] ⚠️ Username invalid, fetching from users collection...');

          try {
            final userDoc = await usersCollection.findOne(where.id(userId));

            if (userDoc != null) {
              username = userDoc['username'] as String? ?? 'Unknown User';
              userAvatarUrl = userDoc['avatarUrl'] as String?;
              print('[VideoController] ✅ Fetched from users collection: username="$username"');

              // CẬP NHẬT LẠI VIDEO DOCUMENT để fix cho lần sau
              await videosCollection.updateOne(
                where.id(videoDoc['_id']),
                modify.set('username', username).set('userAvatarUrl', userAvatarUrl)
              );
              print('[VideoController] Updated video document with correct username');
            } else {
              print('[VideoController] ❌ User document not found for userId: $userId');
              username = 'Deleted User';
            }
          } catch (e) {
            print('[VideoController] Error fetching user: $e');
            username = 'Unknown User';
          }
        }

        // Đảm bảo username không null
        if (username.isEmpty) {
          username = 'Anonymous';
        }

        print('[VideoController] Final username: "$username"');

        // Tạo object user
        videoWithUser['user'] = {
          'username': username,
          'avatarUrl': userAvatarUrl
        };

        // Xóa các trường denormalized gốc
        videoWithUser.remove('username');
        videoWithUser.remove('userAvatarUrl');

        // Convert ObjectId thành String cho client
        if (videoDoc['_id'] is ObjectId) {
          videoWithUser['_id'] = (videoDoc['_id'] as ObjectId).toHexString();
        }
        if (videoDoc['userId'] is ObjectId) {
          videoWithUser['userId'] = (videoDoc['userId'] as ObjectId).toHexString();
        }

        // Convert likes và saves arrays thành String arrays
        videoWithUser['likes'] = (videoDoc['likes'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
        videoWithUser['saves'] = (videoDoc['saves'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];

        // NEW: Add analytics fields
        videoWithUser['viewsCount'] = videoDoc['viewsCount'] as int? ?? 0;
        videoWithUser['uniqueViewsCount'] = videoDoc['uniqueViewsCount'] as int? ?? 0;
        videoWithUser['uniqueViewers'] = (videoDoc['uniqueViewers'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
        videoWithUser['analyticsData'] = videoDoc['analyticsData'] ?? {};
        videoWithUser['lastViewedAt'] = videoDoc['lastViewedAt'];

        print('[VideoController] ✅ Video $videoIndex processed with user: ${videoWithUser['user']}');
        videosWithUserInfo.add(videoWithUser);
        videoIndex++;
      }

      print('[VideoController] === FEED SUMMARY ===');
      print('[VideoController] Total videos processed: ${videosWithUserInfo.length}');
      for (int i = 0; i < videosWithUserInfo.length; i++) {
        final user = videosWithUserInfo[i]['user'] as Map<String, dynamic>;
        print('[VideoController] Video $i username: "${user['username']}"');
      }
      print('[VideoController] =====================');

      return Response.ok(jsonEncode(videosWithUserInfo), headers: {'Content-Type': 'application/json'});

    } catch (e, stackTrace) {
      print('[VideoController.getFeedVideosHandler] Error: $e');
      print('[VideoController.getFeedVideosHandler] StackTrace: $stackTrace');
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to fetch videos: $e'}));
    }
  }

  // --- HÀM LIKE/UNLIKE VIDEO ---
  static Future<Response> toggleLikeVideoHandler(Request request, String videoId, String userIdString) async {
    print('[VideoController] toggleLikeVideo called with videoId: $videoId, userId: $userIdString');

    try {
      // Validate inputs
      if (videoId.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'Video ID cannot be empty'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      if (userIdString.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'User ID cannot be empty'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Convert to ObjectIds
      ObjectId videoObjectId;
      ObjectId userObjectId;
      try {
        videoObjectId = ObjectId.fromHexString(videoId);
        userObjectId = ObjectId.fromHexString(userIdString);
      } catch (e) {
        print('[VideoController] Invalid ObjectId format. VideoId: $videoId, UserId: $userIdString');
        return Response(400,
          body: jsonEncode({'error': 'Invalid videoId or userId format: $e'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final videosCollection = DatabaseService.db.collection('videos');
      final video = await videosCollection.findOne(where.id(videoObjectId));
      if (video == null) {
        print('[VideoController] Video not found for id: $videoId');
        return Response(404,
          body: jsonEncode({'error': 'Video not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      List<ObjectId> likesList = (video['likes'] as List?)?.whereType<ObjectId>().toList() ?? [];
      bool isCurrentlyLiked;

      if (likesList.contains(userObjectId)) {
        likesList.remove(userObjectId);
        isCurrentlyLiked = false;
        print('[VideoController] User unliked the video');
      } else {
        likesList.add(userObjectId);
        isCurrentlyLiked = true;
        print('[VideoController] User liked the video');
      }

      // Update database
      final updateResult = await videosCollection.updateOne(
          where.id(videoObjectId),
          modify.set('likes', likesList).set('likesCount', likesList.length)
      );

      if (updateResult.isSuccess) {
        // Lấy lại thông tin video mới nhất để trả về
        final updatedVideo = await videosCollection.findOne(where.id(videoObjectId));
        if (updatedVideo == null) {
          return Response(404,
            body: jsonEncode({'error': 'Video not found after update'}),
            headers: {'Content-Type': 'application/json'}
          );
        }

        // Convert ObjectIds thành Strings cho response
        final responseVideo = Map<String, dynamic>.from(updatedVideo);
        responseVideo['_id'] = (updatedVideo['_id'] as ObjectId).toHexString();
        responseVideo['userId'] = (updatedVideo['userId'] as ObjectId).toHexString();
        responseVideo['likes'] = (updatedVideo['likes'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
        responseVideo['saves'] = (updatedVideo['saves'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];

        // NEW: Add analytics data
        responseVideo['viewsCount'] = updatedVideo['viewsCount'] as int? ?? 0;
        responseVideo['uniqueViewsCount'] = updatedVideo['uniqueViewsCount'] as int? ?? 0;
        responseVideo['analyticsData'] = updatedVideo['analyticsData'] ?? {};

        // Thêm user info
        responseVideo['user'] = {
          'username': updatedVideo['username'] ?? 'Unknown User',
          'avatarUrl': updatedVideo['userAvatarUrl']
        };
        responseVideo.remove('username');
        responseVideo.remove('userAvatarUrl');

        print('[VideoController] Like toggle successful. New likes count: ${likesList.length}');
        return Response.ok(jsonEncode({
            'message': isCurrentlyLiked ? 'Video liked' : 'Video unliked',
            'isLikedByCurrentUser': isCurrentlyLiked,
            'likesCount': likesList.length,
            'video': responseVideo
            }), headers: {'Content-Type': 'application/json'});
      } else {
        print('[VideoController] Failed to update like status: ${updateResult.writeError?.errmsg}');
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to update like status'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
    } catch (e, s) {
      print('[VideoController.toggleLikeVideoHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // --- HÀM SAVE/UNSAVE VIDEO ---
  static Future<Response> toggleSaveVideoHandler(Request request, String videoId, String userIdString) async {
    print('[VideoController] toggleSaveVideo called with videoId: $videoId, userId: $userIdString');

    try {
      // Validate inputs
      if (videoId.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'Video ID cannot be empty'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      if (userIdString.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'User ID cannot be empty'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Convert to ObjectIds
      ObjectId videoObjectId;
      ObjectId userObjectId;
      try {
        videoObjectId = ObjectId.fromHexString(videoId);
        userObjectId = ObjectId.fromHexString(userIdString);
      } catch (e) {
        print('[VideoController] Invalid ObjectId format. VideoId: $videoId, UserId: $userIdString');
        return Response(400,
          body: jsonEncode({'error': 'Invalid videoId or userId format: $e'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final videosCollection = DatabaseService.db.collection('videos');
      final usersCollection = DatabaseService.db.collection('users');

      final video = await videosCollection.findOne(where.id(videoObjectId));
      if (video == null) {
        print('[VideoController] Video not found for id: $videoId');
        return Response(404,
          body: jsonEncode({'error': 'Video not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final user = await usersCollection.findOne(where.id(userObjectId));
      if (user == null) {
        print('[VideoController] User not found for id: $userIdString');
        return Response(404,
          body: jsonEncode({'error': 'User not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      List<ObjectId> videoSaves = (video['saves'] as List?)?.whereType<ObjectId>().toList() ?? [];
      List<ObjectId> userSavedVideos = (user['savedVideos'] as List?)?.whereType<ObjectId>().toList() ?? [];
      bool isCurrentlySaved;

      if (videoSaves.contains(userObjectId)) {
        videoSaves.remove(userObjectId);
        userSavedVideos.remove(videoObjectId);
        isCurrentlySaved = false;
        print('[VideoController] User unsaved the video');
      } else {
        videoSaves.add(userObjectId);
        userSavedVideos.add(videoObjectId);
        isCurrentlySaved = true;
        print('[VideoController] User saved the video');
      }

      // Update both collections
      final videoUpdateResult = await videosCollection.updateOne(
        where.id(videoObjectId),
        modify.set('saves', videoSaves)
      );
      final userUpdateResult = await usersCollection.updateOne(
        where.id(userObjectId),
        modify.set('savedVideos', userSavedVideos)
      );

      if (videoUpdateResult.isSuccess && userUpdateResult.isSuccess) {
        // Lấy lại thông tin video để trả về
        final updatedVideo = await videosCollection.findOne(where.id(videoObjectId));
        if (updatedVideo == null) {
          return Response(404,
            body: jsonEncode({'error': 'Video not found after update'}),
            headers: {'Content-Type': 'application/json'}
          );
        }

        // Convert ObjectIds thành Strings cho response
        final responseVideo = Map<String, dynamic>.from(updatedVideo);
        responseVideo['_id'] = (updatedVideo['_id'] as ObjectId).toHexString();
        responseVideo['userId'] = (updatedVideo['userId'] as ObjectId).toHexString();
        responseVideo['likes'] = (updatedVideo['likes'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
        responseVideo['saves'] = (updatedVideo['saves'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];

        // NEW: Add analytics data
        responseVideo['viewsCount'] = updatedVideo['viewsCount'] as int? ?? 0;
        responseVideo['uniqueViewsCount'] = updatedVideo['uniqueViewsCount'] as int? ?? 0;
        responseVideo['analyticsData'] = updatedVideo['analyticsData'] ?? {};

        // Thêm user info
        responseVideo['user'] = {
          'username': updatedVideo['username'] ?? 'Unknown User',
          'avatarUrl': updatedVideo['userAvatarUrl']
        };
        responseVideo.remove('username');
        responseVideo.remove('userAvatarUrl');

        print('[VideoController] Save toggle successful. New saves count: ${videoSaves.length}');
        return Response.ok(jsonEncode({
          'message': isCurrentlySaved ? 'Video saved' : 'Video unsaved',
          'isSavedByCurrentUser': isCurrentlySaved,
          'savesCount': videoSaves.length,
          'video': responseVideo
        }), headers: {'Content-Type': 'application/json'});
      } else {
        print('[VideoController] Failed to update save status. VideoUpdate: ${videoUpdateResult.isSuccess}, UserUpdate: ${userUpdateResult.isSuccess}');
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to update save status'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
    } catch (e, s) {
      print('[VideoController.toggleSaveVideoHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // --- NEW: Track video view ---
  static Future<void> trackVideoView({
    required String videoId,
    String? userId,
    int viewDuration = 0,
    String viewSource = 'feed',
  }) async {
    try {
      final videoObjectId = ObjectId.fromHexString(videoId);
      final userObjectId = userId != null && userId.isNotEmpty ? ObjectId.fromHexString(userId) : null;

      final videosCollection = DatabaseService.db.collection('videos');
      final viewsCollection = DatabaseService.db.collection('video_views');

      // Create view record
      final viewRecord = {
        'videoId': videoObjectId,
        'userId': userObjectId,
        'viewDuration': viewDuration,
        'viewSource': viewSource,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await viewsCollection.insertOne(viewRecord);

      // Update video analytics
      final video = await videosCollection.findOne(where.id(videoObjectId));
      if (video != null) {
        final currentViews = video['viewsCount'] as int? ?? 0;
        final uniqueViewers = (video['uniqueViewers'] as List?)?.whereType<ObjectId>().toList() ?? [];

        bool isNewUniqueViewer = false;
        if (userObjectId != null && !uniqueViewers.contains(userObjectId)) {
          uniqueViewers.add(userObjectId);
          isNewUniqueViewer = true;
        }

        await videosCollection.updateOne(
          where.id(videoObjectId),
          modify
            .set('viewsCount', currentViews + 1)
            .set('uniqueViewsCount', isNewUniqueViewer ? (video['uniqueViewsCount'] as int? ?? 0) + 1 : video['uniqueViewsCount'])
            .set('uniqueViewers', uniqueViewers)
            .set('lastViewedAt', DateTime.now().toIso8601String())
        );
      }
    } catch (e) {
      print('[VideoController.trackVideoView] Error: $e');
    }
  }

  // --- HÀM TRACK SHARE VIDEO ---
  static Future<Response> shareVideoHandler(Request request, String videoId) async {
    print('[VideoController] shareVideo called with videoId: $videoId');

    try {
      // Validate videoId format
      if (videoId.isEmpty || videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
        return Response(400,
          body: jsonEncode({'error': 'Invalid video ID format'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // FIXED: Parse request body ONLY ONCE
      final requestBody = await request.readAsString();
      print('[VideoController] Share request body: $requestBody');

      if (requestBody.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'Request body is empty'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      Map<String, dynamic> shareData;
      try {
        shareData = jsonDecode(requestBody);
      } catch (e) {
        print('[VideoController] JSON decode error: $e');
        return Response(400,
          body: jsonEncode({'error': 'Invalid JSON in request body: $e'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final String? userId = shareData['userId'] as String?;
      final String shareMethod = shareData['shareMethod'] as String? ?? 'unknown'; // whatsapp, facebook, copy_link, etc.
      final String? shareText = shareData['shareText'] as String?;

      print('[VideoController] Parsed share data: method=$shareMethod, userId=$userId');

      // Convert to ObjectIds
      ObjectId videoObjectId;
      ObjectId? userObjectId;

      try {
        videoObjectId = ObjectId.fromHexString(videoId);
        if (userId != null && userId.isNotEmpty) {
          userObjectId = ObjectId.fromHexString(userId);
        }
      } catch (e) {
        print('[VideoController] Invalid ObjectId format. VideoId: $videoId, UserId: $userId');
        return Response(400,
          body: jsonEncode({'error': 'Invalid videoId or userId format: $e'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final videosCollection = DatabaseService.db.collection('videos');
      final sharesCollection = DatabaseService.db.collection('video_shares'); // Track individual shares

      // Check if video exists
      final video = await videosCollection.findOne(where.id(videoObjectId));
      if (video == null) {
        print('[VideoController] Video not found for id: $videoId');
        return Response(404,
          body: jsonEncode({'error': 'Video not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Create share record for analytics
      final shareRecord = {
        'videoId': videoObjectId,
        'userId': userObjectId,
        'shareMethod': shareMethod,
        'shareText': shareText,
        'userAgent': request.headers['user-agent'],
        'timestamp': DateTime.now().toIso8601String(),
        'ipAddress': _getClientIP(request),
      };

      // Insert share record
      try {
        await sharesCollection.insertOne(shareRecord);
        print('[VideoController] Share record created for video: $videoId, method: $shareMethod');
      } catch (e) {
        print('[VideoController] Error creating share record: $e');
        // Continue execution even if share record fails
      }

      // Update video shares count
      final currentSharesCount = video['sharesCount'] as int? ?? 0;
      final newSharesCount = currentSharesCount + 1;

      print('[VideoController] Updating shares count from $currentSharesCount to $newSharesCount');

      final updateResult = await videosCollection.updateOne(
        where.id(videoObjectId),
        modify
          .set('sharesCount', newSharesCount)
          .set('updatedAt', DateTime.now().toIso8601String())
      );

      if (updateResult.isSuccess) {
        // Get updated video for response
        final updatedVideo = await videosCollection.findOne(where.id(videoObjectId));
        if (updatedVideo == null) {
          return Response(404,
            body: jsonEncode({'error': 'Video not found after update'}),
            headers: {'Content-Type': 'application/json'}
          );
        }

        // Convert ObjectIds to Strings for response
        final responseVideo = Map<String, dynamic>.from(updatedVideo);
        responseVideo['_id'] = (updatedVideo['_id'] as ObjectId).toHexString();
        responseVideo['userId'] = (updatedVideo['userId'] as ObjectId).toHexString();
        responseVideo['likes'] = (updatedVideo['likes'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
        responseVideo['saves'] = (updatedVideo['saves'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
        responseVideo['uniqueViewers'] = (updatedVideo['uniqueViewers'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];

        // Add user info
        responseVideo['user'] = {
          'username': updatedVideo['username'] ?? 'Unknown User',
          'avatarUrl': updatedVideo['userAvatarUrl']
        };
        responseVideo.remove('username');
        responseVideo.remove('userAvatarUrl');

        print('[VideoController] Share tracked successfully. New shares count: $newSharesCount');

        return Response.ok(jsonEncode({
          'message': 'Video shared successfully',
          'shareMethod': shareMethod,
          'sharesCount': newSharesCount,
          'video': responseVideo
        }), headers: {'Content-Type': 'application/json'});
      } else {
        print('[VideoController] Failed to update shares count: ${updateResult.writeError?.errmsg}');
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to update shares count'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
    } catch (e, s) {
      print('[VideoController.shareVideoHandler] Error: $e');
      print('[VideoController.shareVideoHandler] StackTrace: $s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Helper method to get client IP
  static String? _getClientIP(Request request) {
    // Check for forwarded IP first (in case of proxy/load balancer)
    String? forwardedFor = request.headers['x-forwarded-for'];
    if (forwardedFor != null && forwardedFor.isNotEmpty) {
      // Take the first IP if there are multiple
      return forwardedFor.split(',').first.trim();
    }

    // Check for real IP
    String? realIP = request.headers['x-real-ip'];
    if (realIP != null && realIP.isNotEmpty) {
      return realIP;
    }

    // Fallback to remote address (may not be available in all setups)
    return request.headers['remote-addr'] ?? 'unknown';
  }

  // --- GET SHARE ANALYTICS FOR VIDEO ---
  static Future<Response> getVideoShareAnalyticsHandler(Request request, String videoId) async {
    print('[VideoController] getVideoShareAnalytics called with videoId: $videoId');

    try {
      // Validate videoId format
      if (videoId.isEmpty || videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
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

      final sharesCollection = DatabaseService.db.collection('video_shares');
      final videosCollection = DatabaseService.db.collection('videos');

      // Get video info
      final video = await videosCollection.findOne(where.id(videoObjectId));
      if (video == null) {
        return Response(404,
          body: jsonEncode({'error': 'Video not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Get share analytics
      final sharesData = await sharesCollection.find(where.eq('videoId', videoObjectId)).toList();

      // Analyze share methods
      Map<String, int> shareMethodCounts = {};
      Map<String, int> sharesByHour = {};
      int totalShares = sharesData.length;

      for (var share in sharesData) {
        // Count by method
        final method = share['shareMethod'] as String? ?? 'unknown';
        shareMethodCounts[method] = (shareMethodCounts[method] ?? 0) + 1;

        // Count by hour
        final timestamp = share['timestamp'] as String?;
        if (timestamp != null) {
          final dateTime = DateTime.tryParse(timestamp);
          if (dateTime != null) {
            final hourKey = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:00';
            sharesByHour[hourKey] = (sharesByHour[hourKey] ?? 0) + 1;
          }
        }
      }

      // Calculate share rate
      final viewsCount = video['viewsCount'] as int? ?? 0;
      final shareRate = viewsCount > 0 ? (totalShares / viewsCount * 100) : 0.0;

      final analytics = {
        'videoId': videoId,
        'totalShares': totalShares,
        'shareRate': shareRate,
        'shareMethodBreakdown': shareMethodCounts,
        'sharesByHour': sharesByHour,
        'topShareMethod': shareMethodCounts.isNotEmpty
          ? shareMethodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : 'none',
        'viewsCount': viewsCount,
        'video': {
          'title': video['description'] as String? ?? '',
          'createdAt': video['createdAt'] as String?,
          'username': video['username'] as String? ?? 'Unknown User',
        }
      };

      return Response.ok(
        jsonEncode(analytics),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, s) {
      print('[VideoController.getVideoShareAnalyticsHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // --- ENHANCED HASHTAG EXTRACTION ---
  static List<String> _extractHashtags(String description) {
    if (description.isEmpty) return [];

    // Enhanced regex to match hashtags more accurately
    final hashtagRegex = RegExp(r'#[a-zA-Z0-9_\u00C0-\u017F\u1EA0-\u1EF9]+', unicode: true);
    final matches = hashtagRegex.allMatches(description);

    Set<String> hashtags = {};

    for (final match in matches) {
      String hashtag = match.group(0)!.toLowerCase();

      // Remove # for storage but keep for display
      String cleanHashtag = hashtag.substring(1);

      // Only add hashtags with length >= 2 and <= 50
      if (cleanHashtag.length >= 2 && cleanHashtag.length <= 50) {
        hashtags.add(cleanHashtag);
      }
    }

    print('[VideoController] Extracted hashtags: ${hashtags.toList()}');
    return hashtags.toList();
  }

  // --- GET VIDEOS BY HASHTAG ---
  static Future<Response> getVideosByHashtagHandler(Request request, String hashtag) async {
    print('[VideoController] Getting videos by hashtag: #$hashtag');

    try {
      final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;
      final sortBy = request.url.queryParameters['sortBy'] ?? 'newest'; // newest, popular, views
      final currentUserId = request.url.queryParameters['currentUserId'];

      // Validate hashtag
      if (hashtag.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'Hashtag is required'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final videosCollection = DatabaseService.db.collection('videos');
      final usersCollection = DatabaseService.db.collection('users');

      final skip = (page - 1) * limit;

      // Normalize hashtag (remove # if present, convert to lowercase)
      final normalizedHashtag = hashtag.toLowerCase().replaceFirst('#', '');

      print('[VideoController] Searching for normalized hashtag: "$normalizedHashtag"');

      // Create selector based on sorting preference
      SelectorBuilder selector = where.oneFrom('hashtags', [normalizedHashtag]);

      switch (sortBy) {
        case 'popular':
          selector = selector.sortBy('likesCount', descending: true);
          break;
        case 'views':
          selector = selector.sortBy('viewsCount', descending: true);
          break;
        case 'trending':
          // Sort by a combination of recent engagement
          selector = selector.sortBy('updatedAt', descending: true);
          break;
        default: // newest
          selector = selector.sortBy('createdAt', descending: true);
          break;
      }

      selector = selector.skip(skip).limit(limit);

      final videoDocs = await videosCollection.find(selector).toList();

      // Count total videos with this hashtag
      final totalVideos = await videosCollection.count(
        where.oneFrom('hashtags', [normalizedHashtag])
      );

      print('[VideoController] Found ${videoDocs.length} videos for hashtag, total: $totalVideos');

      // Format videos for response
      List<Map<String, dynamic>> formattedVideos = [];

      for (var videoDoc in videoDocs) {
        final video = Map<String, dynamic>.from(videoDoc);

        // Convert ObjectIds to strings
        video['_id'] = (videoDoc['_id'] as ObjectId).toHexString();
        video['userId'] = (videoDoc['userId'] as ObjectId).toHexString();

        // Convert arrays
        video['likes'] = (videoDoc['likes'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
        video['saves'] = (videoDoc['saves'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
        video['uniqueViewers'] = (videoDoc['uniqueViewers'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];

        // Get user info
        String username = videoDoc['username'] as String? ?? '';
        String? userAvatarUrl = videoDoc['userAvatarUrl'] as String?;

        // If username is missing, fetch from users collection
        if (username.isEmpty || username == 'Unknown User') {
          try {
            final userId = ObjectId.fromHexString(video['userId']);
            final userDoc = await usersCollection.findOne(where.id(userId));
            if (userDoc != null) {
              username = userDoc['username'] as String? ?? 'Unknown User';
              userAvatarUrl = userDoc['avatarUrl'] as String?;
            }
          } catch (e) {
            print('[VideoController] Error fetching user info: $e');
            username = 'Unknown User';
          }
        }

        // Add user object
        video['user'] = {
          'id': video['userId'],
          'username': username,
          'displayName': username,
          'avatarUrl': userAvatarUrl,
          'isVerified': false,
        };

        // Remove denormalized fields
        video.remove('username');
        video.remove('userAvatarUrl');

        // Ensure analytics fields are present
        video['viewsCount'] = videoDoc['viewsCount'] ?? 0;
        video['uniqueViewsCount'] = videoDoc['uniqueViewsCount'] ?? 0;
        video['analyticsData'] = videoDoc['analyticsData'] ?? {};

        formattedVideos.add(video);
      }

      // Calculate hashtag statistics
      final hashtagStats = await _calculateHashtagStatistics(normalizedHashtag, videosCollection);

      final totalPages = (totalVideos / limit).ceil();

      final response = {
        'hashtag': normalizedHashtag,
        'displayHashtag': '#$normalizedHashtag',
        'videos': formattedVideos,
        'statistics': hashtagStats,
        'pagination': {
          'currentPage': page,
          'totalPages': totalPages,
          'totalVideos': totalVideos,
          'limit': limit,
          'hasNextPage': page < totalPages,
          'hasPrevPage': page > 1,
        },
        'sortBy': sortBy,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return Response.ok(
        jsonEncode(response),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, s) {
      print('[VideoController.getVideosByHashtagHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get videos by hashtag: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // --- CALCULATE HASHTAG STATISTICS ---
  static Future<Map<String, dynamic>> _calculateHashtagStatistics(String hashtag, dynamic videosCollection) async {
    try {
      print('[VideoController] Calculating statistics for hashtag: $hashtag');

      final videos = await videosCollection.find(
        where.oneFrom('hashtags', [hashtag])
      ).toList();

      int totalVideos = videos.length;
      int totalLikes = 0;
      int totalViews = 0;
      int totalShares = 0;
      int totalComments = 0;
      Map<String, int> creatorCounts = {};
      Map<String, int> dailyCounts = {};

      for (var video in videos) {
        totalLikes += video['likesCount'] as int? ?? 0;
        totalViews += video['viewsCount'] as int? ?? 0;
        totalShares += video['sharesCount'] as int? ?? 0;
        totalComments += video['commentsCount'] as int? ?? 0;

        final username = video['username'] as String? ?? 'Unknown';
        creatorCounts[username] = (creatorCounts[username] ?? 0) + 1;

        // Count videos by day for trending analysis
        final createdAt = video['createdAt'] as String?;
        if (createdAt != null) {
          final date = DateTime.tryParse(createdAt);
          if (date != null) {
            final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
          }
        }
      }

      // Get top creators (limit to top 10)
      final topCreators = creatorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(10);

      // Calculate trending score based on recent activity
      final now = DateTime.now();
      final last7Days = now.subtract(const Duration(days: 7));
      int recentVideos = 0;
      int recentEngagement = 0;

      for (var video in videos) {
        final createdAt = video['createdAt'] as String?;
        if (createdAt != null) {
          final date = DateTime.tryParse(createdAt);
          if (date != null && date.isAfter(last7Days)) {
            recentVideos++;
            recentEngagement += (video['likesCount'] as int? ?? 0) +
                               (video['commentsCount'] as int? ?? 0) +
                               (video['sharesCount'] as int? ?? 0);
          }
        }
      }

      final trendingScore = recentVideos * 10 + recentEngagement;

      // Get daily trend data (last 30 days)
      final trendData = <Map<String, dynamic>>[];
      for (int i = 29; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        trendData.add({
          'date': dayKey,
          'count': dailyCounts[dayKey] ?? 0,
        });
      }

      final statistics = {
        'totalVideos': totalVideos,
        'totalLikes': totalLikes,
        'totalViews': totalViews,
        'totalShares': totalShares,
        'totalComments': totalComments,
        'averageLikes': totalVideos > 0 ? (totalLikes / totalVideos).round() : 0,
        'averageViews': totalVideos > 0 ? (totalViews / totalVideos).round() : 0,
        'averageEngagement': totalVideos > 0 ? ((totalLikes + totalComments + totalShares) / totalVideos).round() : 0,
        'recentVideos': recentVideos,
        'trendingScore': trendingScore,
        'topCreators': topCreators.map((e) => {
          'username': e.key,
          'videoCount': e.value,
          'percentage': totalVideos > 0 ? ((e.value / totalVideos) * 100).round() : 0,
        }).toList(),
        'trendData': trendData,
        'peakDay': dailyCounts.isNotEmpty
          ? dailyCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : null,
        'isActive': recentVideos > 0,
        'isTrending': trendingScore > 50, // Threshold for trending
      };

      print('[VideoController] Hashtag statistics calculated: ${statistics['totalVideos']} videos, trending score: ${statistics['trendingScore']}');

      return statistics;
    } catch (e) {
      print('[VideoController] Error calculating hashtag statistics: $e');
      return {
        'totalVideos': 0,
        'totalLikes': 0,
        'totalViews': 0,
        'totalShares': 0,
        'totalComments': 0,
        'averageLikes': 0,
        'averageViews': 0,
        'averageEngagement': 0,
        'recentVideos': 0,
        'trendingScore': 0,
        'topCreators': [],
        'trendData': [],
        'peakDay': null,
        'isActive': false,
        'isTrending': false,
      };
    }
  }

  // --- GET RELATED HASHTAGS ---
  static Future<Response> getRelatedHashtagsHandler(Request request, String hashtag) async {
    print('[VideoController] Getting related hashtags for: #$hashtag');

    try {
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '10') ?? 10;

      if (hashtag.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'Hashtag is required'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final videosCollection = DatabaseService.db.collection('videos');

      // Normalize hashtag
      final normalizedHashtag = hashtag.toLowerCase().replaceFirst('#', '');

      print('[VideoController] Finding videos with hashtag: $normalizedHashtag');

      // Find videos that contain this hashtag
      final videosWithHashtag = await videosCollection.find(
        where.oneFrom('hashtags', [normalizedHashtag])
      ).toList();

      print('[VideoController] Found ${videosWithHashtag.length} videos with this hashtag');

      // Count co-occurring hashtags
      Map<String, int> hashtagCounts = {};
      Map<String, Set<String>> hashtagCoOccurrence = {};

      for (var video in videosWithHashtag) {
        final hashtags = video['hashtags'] as List?;
        if (hashtags != null) {
          final videoHashtags = hashtags.map((h) => h.toString().toLowerCase()).toSet();

          // Remove the original hashtag from the set
          videoHashtags.remove(normalizedHashtag);

          for (String relatedHashtag in videoHashtags) {
            if (relatedHashtag.isNotEmpty && relatedHashtag.length > 1) {
              hashtagCounts[relatedHashtag] = (hashtagCounts[relatedHashtag] ?? 0) + 1;

              // Track which hashtags appear together
              hashtagCoOccurrence[relatedHashtag] ??= {};
              hashtagCoOccurrence[relatedHashtag]!.addAll(videoHashtags);
            }
          }
        }
      }

      print('[VideoController] Found ${hashtagCounts.length} related hashtags');

      // Calculate relevance scores and sort
      final relatedHashtags = hashtagCounts.entries.map((entry) {
        final relatedTag = entry.key;
        final coOccurrenceCount = entry.value;

        // Calculate relevance score based on:
        // 1. Co-occurrence frequency
        // 2. Overall popularity of the related hashtag
        // 3. Semantic similarity (basic implementation)

        double relevanceScore = coOccurrenceCount.toDouble();

        // Boost score for hashtags that appear frequently with this one
        final coOccurrenceRatio = coOccurrenceCount / videosWithHashtag.length;
        relevanceScore *= (1 + coOccurrenceRatio);

        // Basic semantic similarity boost
        if (relatedTag.contains(normalizedHashtag) || normalizedHashtag.contains(relatedTag)) {
          relevanceScore *= 1.5;
        }

        return {
          'hashtag': relatedTag,
          'displayHashtag': '#$relatedTag',
          'coOccurrenceCount': coOccurrenceCount,
          'relevanceScore': relevanceScore,
          'coOccurrenceRatio': (coOccurrenceRatio * 100).round(),
        };
      }).toList();

      // Sort by relevance score and limit results
      relatedHashtags.sort((a, b) => (b['relevanceScore'] as double).compareTo(a['relevanceScore'] as double));

      final limitedResults = relatedHashtags.take(limit).toList();

      final response = {
        'hashtag': normalizedHashtag,
        'displayHashtag': '#$normalizedHashtag',
        'relatedHashtags': limitedResults,
        'totalVideosAnalyzed': videosWithHashtag.length,
        'totalRelatedHashtagsFound': hashtagCounts.length,
        'limit': limit,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return Response.ok(
        jsonEncode(response),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e, s) {
      print('[VideoController.getRelatedHashtagsHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get related hashtags: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // --- UPDATE VIDEO HASHTAGS ---
  static Future<Response> updateVideoHashtagsHandler(Request request, String videoId) async {
    print('[VideoController] Updating hashtags for video: $videoId');

    try {
      // Validate videoId format
      if (videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
        return Response(400,
          body: jsonEncode({'error': 'Invalid video ID format'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final requestBody = await request.readAsString();
      if (requestBody.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'Request body is required'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      Map<String, dynamic> updateData;
      try {
        updateData = jsonDecode(requestBody);
      } catch (e) {
        return Response(400,
          body: jsonEncode({'error': 'Invalid JSON in request body'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final newDescription = updateData['description'] as String?;
      final userId = updateData['userId'] as String?;

      if (newDescription == null || newDescription.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'Description is required'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      if (userId == null || userId.isEmpty) {
        return Response(400,
          body: jsonEncode({'error': 'User ID is required'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final videoObjectId = ObjectId.fromHexString(videoId);
      final userObjectId = ObjectId.fromHexString(userId);

      final videosCollection = DatabaseService.db.collection('videos');

      // Verify video exists and user owns it
      final video = await videosCollection.findOne(where.id(videoObjectId));
      if (video == null) {
        return Response(404,
          body: jsonEncode({'error': 'Video not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final videoUserId = video['userId'] as ObjectId;
      if (videoUserId != userObjectId) {
        return Response(403,
          body: jsonEncode({'error': 'You can only update your own videos'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Extract new hashtags from description
      final newHashtags = _extractHashtags(newDescription);

      print('[VideoController] Updating video with new hashtags: $newHashtags');

      // Update video document
      final updateResult = await videosCollection.updateOne(
        where.id(videoObjectId),
        modify
          .set('description', newDescription)
          .set('hashtags', newHashtags)
          .set('updatedAt', DateTime.now().toIso8601String())
      );

      if (updateResult.isSuccess) {
        // Get updated video for response
        final updatedVideo = await videosCollection.findOne(where.id(videoObjectId));
        if (updatedVideo == null) {
          return Response(404,
            body: jsonEncode({'error': 'Video not found after update'}),
            headers: {'Content-Type': 'application/json'}
          );
        }

        // Format response
        final responseVideo = Map<String, dynamic>.from(updatedVideo);
        responseVideo['_id'] = (updatedVideo['_id'] as ObjectId).toHexString();
        responseVideo['userId'] = (updatedVideo['userId'] as ObjectId).toHexString();
        responseVideo['likes'] = (updatedVideo['likes'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
        responseVideo['saves'] = (updatedVideo['saves'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];

        // Add user info
        responseVideo['user'] = {
          'username': updatedVideo['username'] ?? 'Unknown User',
          'avatarUrl': updatedVideo['userAvatarUrl']
        };
        responseVideo.remove('username');
        responseVideo.remove('userAvatarUrl');

        print('[VideoController] Video hashtags updated successfully');

        return Response.ok(jsonEncode({
          'message': 'Video hashtags updated successfully',
          'video': responseVideo,
          'extractedHashtags': newHashtags,
        }), headers: {'Content-Type': 'application/json'});
      } else {
        print('[VideoController] Failed to update video hashtags: ${updateResult.writeError?.errmsg}');
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to update video hashtags'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

    } catch (e, s) {
      print('[VideoController.updateVideoHashtagsHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update video hashtags: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // --- CÁC HÀM HELPER ---

  /// Parse content-disposition header để lấy name và filename
  static Map<String, String> _parseContentDisposition(String contentDisposition) {
    Map<String, String> params = {};
    final parts = contentDisposition.split(';');

    for (final part in parts) {
      final trimmedPart = part.trim();
      if (trimmedPart.contains('=')) {
        final keyValue = trimmedPart.split('=');
        if (keyValue.length == 2) {
          String key = keyValue[0].trim();
          String value = keyValue[1].trim();

          // Remove quotes from value if present
          if (value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length - 1);
          }

          params[key] = value;
        }
      }
    }

    return params;
  }

  /// Đọc tất cả bytes từ một MimeMultipart stream
  static Future<List<int>> _readAllBytes(Stream<List<int>> part) async {
    final List<int> bytes = <int>[];
    await for (final chunk in part) {
      bytes.addAll(chunk);
    }
    print('[VideoController._readAllBytes] Read ${bytes.length} bytes from multipart stream');
    return bytes;
  }

  static Future<Router> getUserVideosHandler(Request request, String userId, int page, int limit) async {
    throw UnimplementedError();
  }

  static Future<Response> deleteVideoHandler(Request request, String videoId, String userIdString) async {
    try {
      if (videoId.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(videoId)) {
        return Response(400, body: jsonEncode({'error': 'Invalid video ID format'}), headers: {'Content-Type': 'application/json'});
      }
      if (userIdString.length != 24 || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(userIdString)) {
        return Response(400, body: jsonEncode({'error': 'Invalid user ID format'}), headers: {'Content-Type': 'application/json'});
      }
      final videoObjectId = ObjectId.fromHexString(videoId);
      final userObjectId = ObjectId.fromHexString(userIdString);
      final videosCollection = DatabaseService.db.collection('videos');
      final videoDoc = await videosCollection.findOne(where.id(videoObjectId));
      if (videoDoc == null) {
        return Response(404, body: jsonEncode({'error': 'Video not found'}), headers: {'Content-Type': 'application/json'});
      }
      if (videoDoc['userId'] != userObjectId) {
        return Response(403, body: jsonEncode({'error': 'You can only delete your own videos'}), headers: {'Content-Type': 'application/json'});
      }
      // Xoá file vật lý nếu có
      final videoUrl = videoDoc['videoUrl'] as String?;
      if (videoUrl != null && videoUrl.isNotEmpty) {
        try {
          final file = File(videoUrl);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('[VideoController] Warning: Failed to delete video file: $e');
        }
      }
      // Xoá document trong MongoDB
      final deleteResult = await videosCollection.deleteOne(where.id(videoObjectId));
      if (deleteResult.isSuccess) {
        return Response.ok(jsonEncode({'message': 'Video deleted successfully'}), headers: {'Content-Type': 'application/json'});
      } else {
        return Response.internalServerError(body: jsonEncode({'error': 'Failed to delete video'}), headers: {'Content-Type': 'application/json'});
      }
    } catch (e, s) {
      print('[VideoController.deleteVideoHandler] Error: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to delete video: $e'}), headers: {'Content-Type': 'application/json'});
    }
  }
}

extension VideoDocumentExtension on Map<String, dynamic> {
  /// Convert video document để trả về cho client
  Map<String, dynamic> toClientFormat() {
    final clientDoc = Map<String, dynamic>.from(this);

    // Convert ObjectIds thành Strings
    if (this['_id'] is ObjectId) {
      clientDoc['_id'] = (this['_id'] as ObjectId).toHexString();
    }
    if (this['userId'] is ObjectId) {
      clientDoc['userId'] = (this['userId'] as ObjectId).toHexString();
    }

    // Convert likes và saves arrays
    clientDoc['likes'] = (this['likes'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];
    clientDoc['saves'] = (this['saves'] as List?)?.whereType<ObjectId>().map((id) => id.toHexString()).toList() ?? [];

    // Thêm user info từ denormalized data
    clientDoc['user'] = {
      'username': this['username'] ?? 'Unknown User',
      'avatarUrl': this['userAvatarUrl']
    };

    // Remove denormalized fields
    clientDoc.remove('username');
    clientDoc.remove('userAvatarUrl');

    return clientDoc;
  }
}