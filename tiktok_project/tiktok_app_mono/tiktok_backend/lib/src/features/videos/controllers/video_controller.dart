import 'dart:async';
import 'dart:convert'; 
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart'; 
import 'package:path/path.dart' as p;
import 'package:shelf_router/src/router.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, SelectorBuilder, MimeMultipart, modify, where;

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
          } catch(e) { 
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

  /// Extract hashtags từ description
  static List<String> _extractHashtags(String description) {
    final hashtagRegex = RegExp(r'#\w+');
    final matches = hashtagRegex.allMatches(description);
    return matches.map((match) => match.group(0)!).toList();
  }

  static Future<Router> getUserVideosHandler(Request request, String userId, int page, int limit) async {
    throw UnimplementedError();
  }

  static Future<Router> deleteVideoHandler(Request request, String videoId, String userIdString) async {
    throw UnimplementedError();
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