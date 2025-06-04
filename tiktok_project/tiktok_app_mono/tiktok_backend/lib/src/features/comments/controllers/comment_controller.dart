// tiktok_backend/lib/src/features/comments/controllers/comment_controller.dart
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, WriteConcern, where, modify, SelectorBuilder;
import 'package:shelf/shelf.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';
import '../models/comment_model.dart'; 

class CommentController {
  static Future<Response> addCommentHandler(Request request, String videoId) async {
    print('[CommentController] Attempting to add comment to videoId: $videoId');
    try {
      final requestBody = await request.readAsString();
      if (requestBody.isEmpty) return Response(400, body: jsonEncode({'error': 'Request body is empty'}));
      final payload = jsonDecode(requestBody);

      final userIdString = payload['userId'] as String?; 
      final text = payload['text'] as String?;
      
      if (userIdString == null || text == null || text.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'UserId and comment text are required'}));
      }
      
      ObjectId videoObjectId; ObjectId userObjectId;
      try {
        videoObjectId = ObjectId.fromHexString(videoId);
        userObjectId = ObjectId.fromHexString(userIdString);
      } catch (e) {
        return Response(400, body: jsonEncode({'error': 'Invalid videoId or userId format'}));
      }

      final usersCollection = DatabaseService.db.collection('users');
      final userDoc = await usersCollection.findOne(where.id(userObjectId).fields(['username', 'avatarUrl']));
      if (userDoc == null) return Response(404, body: jsonEncode({'error': 'User not found to add comment'}));
      
      final username = userDoc['username'] as String? ?? 'Anonymous';
      final userAvatarUrl = userDoc['avatarUrl'] as String?;

      final newComment = Comment(
        videoId: videoObjectId, userId: userObjectId,
        username: username, userAvatarUrl: userAvatarUrl, text: text,
      );

      final commentsCollection = DatabaseService.db.collection('comments');
      final result = await commentsCollection.insertOne(newComment.toMap());

      if (result.isSuccess) {
        final videosCollection = DatabaseService.db.collection('videos');
        await videosCollection.updateOne(where.id(videoObjectId), modify.inc('commentsCount', 1));
        print('[CommentController] Comment added and video commentsCount updated.');

        final createdCommentMap = newComment.toMap();
        createdCommentMap['_id'] = result.id.toHexString();
        createdCommentMap['userId'] = userObjectId.toHexString();
        createdCommentMap['videoId'] = videoObjectId.toHexString();
        return Response.ok(jsonEncode(createdCommentMap), headers: {'Content-Type': 'application/json'});
      } else {
        return Response.internalServerError(body: jsonEncode({'error': 'Failed to add comment to database'}));
      }
    } catch (e, s) {
      print('[CommentController.addCommentHandler] Error: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'error': 'An unexpected error occurred while adding comment'}));
    }
  }

  static Future<Response> getVideoCommentsHandler(Request request, String videoId) async {
    print('[CommentController] Attempting to get comments for videoId: $videoId');
    try {
      ObjectId videoObjectId;
      try { videoObjectId = ObjectId.fromHexString(videoId); } 
      catch (e) { return Response(400, body: jsonEncode({'error': 'Invalid videoId format'})); }

      final commentsCollection = DatabaseService.db.collection('comments');
      final commentsCursor = commentsCollection.find(
        SelectorBuilder().eq('videoId', videoObjectId).sortBy('createdAt', descending: true)
      );
      
      final List<Map<String, dynamic>> commentsList = [];
      await for (var doc in commentsCursor) {
          doc['_id'] = (doc['_id'] as ObjectId).toHexString();
          doc['userId'] = (doc['userId'] as ObjectId).toHexString();
          doc['videoId'] = (doc['videoId'] as ObjectId).toHexString();
          commentsList.add(doc);
      }
      print('[CommentController] Returning ${commentsList.length} comments for videoId: $videoId');
      return Response.ok(jsonEncode(commentsList), headers: {'Content-Type': 'application/json'});
    } catch (e, s) {
      print('[CommentController.getVideoCommentsHandler] Error: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to fetch comments'}));
    }
  }
}