// tiktok_backend/lib/src/features/videos/controllers/video_controller.dart
import 'dart:async';
import 'dart:convert'; 
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart'; 
import 'package:path/path.dart' as p;
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
      
      // Lấy thông tin user để denormalize vào video document
      final userDocForVideo = await usersCollection.findOne(where.id(userObjectId).fields(['username', 'avatarUrl']));

      final videoDocument = {
        'userId': userObjectId, 
        'username': userDocForVideo?['username'] ?? 'Unknown User',
        'userAvatarUrl': userDocForVideo?['avatarUrl'],
        'description': description,
        'videoUrl': '/uploads/$uniqueFileName', 
        'likes': <ObjectId>[],          // Khởi tạo danh sách likes
        'likesCount': 0,               // Khởi tạo số lượng likes
        'commentsCount': 0,            // Khởi tạo số lượng comments
        'sharesCount': 0,              // Khởi tạo số lượng shares
        'saves': <ObjectId>[],         // Khởi tạo danh sách saves
        'hashtags': _extractHashtags(description),
        'originalFileName': originalVideoFileName,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final result = await videosCollection.insertOne(videoDocument);
      if (result.isSuccess) {
        videoDocument['_id'] = result.id.toHexString(); 
        videoDocument['likes'] = []; // Trả về dạng empty array cho client
        videoDocument['saves'] = []; // Trả về dạng empty array cho client
        videoDocument['userId'] = userObjectId.toHexString(); // Convert ObjectId thành String
        
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

  // --- HÀM LẤY DANH SÁCH VIDEO CHO FEED ---
  static Future<Response> getFeedVideosHandler(Request request) async {
    print('[VideoController] Received request for feed videos.');
    try {
      final videosCollection = DatabaseService.db.collection('videos');

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
      await for (var videoDoc in videoDocsCursor) {
        final Map<String, dynamic> videoWithUser = Map.from(videoDoc);
        
        // Tạo object user từ thông tin đã denormalize
        videoWithUser['user'] = {
          'username': videoDoc['username'] ?? 'Unknown User',
          'avatarUrl': videoDoc['userAvatarUrl'] 
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
        
        videosWithUserInfo.add(videoWithUser);
      }

      print('[VideoController] Returning ${videosWithUserInfo.length} videos for feed.');
      return Response.ok(jsonEncode(videosWithUserInfo), headers: {'Content-Type': 'application/json'});

    } catch (e, stackTrace) {
      print('[VideoController.getFeedVideosHandler] Error: $e');
      print('[VideoController.getFeedVideosHandler] StackTrace: $stackTrace');
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to fetch videos: $e'}));
    }
  }

  // --- HÀM LIKE/UNLIKE VIDEO (ĐƯỢC SỬA HOÀN TOÀN) ---
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

// --- HÀM SAVE/UNSAVE VIDEO (ĐƯỢC SỬA HOÀN TOÀN) ---
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
}

// --- CÁC HÀM EXTENSION TIỆN ÍCH ---

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