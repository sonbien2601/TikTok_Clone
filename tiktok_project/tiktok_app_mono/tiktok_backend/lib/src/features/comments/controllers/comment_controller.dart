// tiktok_backend/lib/src/features/comments/controllers/comment_controller.dart
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, WriteConcern, where, modify, SelectorBuilder;
import 'package:shelf/shelf.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';
import '../models/comment_model.dart'; 

class CommentController {
  
  // Add comment to video
  static Future<Response> addCommentHandler(Request request, String videoId, String userIdString, String text) async {
    print('[CommentController] Adding comment to videoId: $videoId by user: $userIdString');
    print('[CommentController] Comment text: "$text"');
    
    try {
      // Validate input
      final textValidation = Comment.validateText(text);
      if (textValidation != null) {
        return Response(400, 
          body: jsonEncode({'error': textValidation}),
          headers: {'Content-Type': 'application/json'}
        );
      }
      
      // Convert IDs
      ObjectId videoObjectId; 
      ObjectId userObjectId;
      try {
        videoObjectId = ObjectId.fromHexString(videoId);
        userObjectId = ObjectId.fromHexString(userIdString);
      } catch (e) {
        return Response(400, 
          body: jsonEncode({'error': 'Invalid videoId or userId format'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Check if video exists
      final videosCollection = DatabaseService.db.collection('videos');
      final videoExists = await videosCollection.findOne(where.id(videoObjectId).fields(['_id']));
      if (videoExists == null) {
        return Response(404, 
          body: jsonEncode({'error': 'Video not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Get user info
      final usersCollection = DatabaseService.db.collection('users');
      final userDoc = await usersCollection.findOne(where.id(userObjectId).fields(['username', 'avatarUrl']));
      if (userDoc == null) {
        return Response(404, 
          body: jsonEncode({'error': 'User not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
      
      final username = userDoc['username'] as String? ?? 'Anonymous';
      final userAvatarUrl = userDoc['avatarUrl'] as String?;

      // Create new comment
      final newComment = Comment(
        videoId: videoObjectId, 
        userId: userObjectId,
        username: username, 
        userAvatarUrl: userAvatarUrl, 
        text: text.trim(),
      );

      // Insert comment
      final commentsCollection = DatabaseService.db.collection('comments');
      final result = await commentsCollection.insertOne(newComment.toMap());

      if (result.isSuccess) {
        // Update video's comment count
        await videosCollection.updateOne(
          where.id(videoObjectId), 
          modify.inc('commentsCount', 1)
        );
        
        print('[CommentController] Comment added successfully. ID: ${result.id}');

        // Create properly formatted response - IMPORTANT: Must be a JSON object!
        final responseData = {
          'message': 'Comment added successfully',
          'comment': {
            '_id': result.id!.toHexString(),
            'videoId': videoObjectId.toHexString(),
            'userId': userObjectId.toHexString(),
            'username': username,
            'text': text.trim(),
            'likesCount': 0,
            'likes': <String>[], // Empty array of strings
            'repliesCount': 0,
            'createdAt': newComment.createdAt.toIso8601String(),
            'updatedAt': newComment.updatedAt.toIso8601String(),
            if (userAvatarUrl != null) 'userAvatarUrl': userAvatarUrl,
          }
        };

        final jsonResponse = jsonEncode(responseData);
        print('[CommentController] Sending response: $jsonResponse');

        return Response.ok(
          jsonResponse, 
          headers: {'Content-Type': 'application/json'}
        );
      } else {
        print('[CommentController] Failed to insert comment: ${result.writeError?.errmsg}');
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to add comment to database'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
    } catch (e, s) {
      print('[CommentController.addCommentHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred while adding comment: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Get comments for video with pagination
  static Future<Response> getVideoCommentsHandler(Request request, String videoId, int page, int limit) async {
    print('[CommentController] Getting comments for videoId: $videoId (page: $page, limit: $limit)');
    
    try {
      // Validate videoId
      ObjectId videoObjectId;
      try { 
        videoObjectId = ObjectId.fromHexString(videoId); 
      } catch (e) { 
        return Response(400, 
          body: jsonEncode({'error': 'Invalid videoId format'}),
          headers: {'Content-Type': 'application/json'}
        ); 
      }

      // Validate pagination parameters
      if (page < 1) page = 1;
      if (limit < 1 || limit > 100) limit = 20; // Max 100 comments per request
      
      final skip = (page - 1) * limit;

      // Check if video exists
      final videosCollection = DatabaseService.db.collection('videos');
      final videoDoc = await videosCollection.findOne(where.id(videoObjectId).fields(['commentsCount']));
      if (videoDoc == null) {
        return Response(404, 
          body: jsonEncode({'error': 'Video not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final totalComments = videoDoc['commentsCount'] as int? ?? 0;

      // Get comments with pagination
      final commentsCollection = DatabaseService.db.collection('comments');
      final commentsCursor = commentsCollection.find(
        SelectorBuilder()
          .eq('videoId', videoObjectId)
          .eq('parentCommentId', null) // Only get top-level comments (not replies)
          .sortBy('createdAt', descending: true)
          .skip(skip)
          .limit(limit)
      );
      
      final List<Map<String, dynamic>> commentsList = [];
      await for (var doc in commentsCursor) {
        // Create properly formatted comment object
        final formattedComment = <String, dynamic>{
          '_id': (doc['_id'] as ObjectId).toHexString(),
          'videoId': (doc['videoId'] as ObjectId).toHexString(),
          'userId': (doc['userId'] as ObjectId).toHexString(),
          'username': doc['username'] as String? ?? 'Anonymous',
          'text': doc['text'] as String? ?? '',
          'likesCount': doc['likesCount'] as int? ?? 0,
          'likes': _formatLikesArray(doc['likes']),
          'repliesCount': doc['repliesCount'] as int? ?? 0,
          'createdAt': (doc['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
          'updatedAt': (doc['updatedAt'] as String?) ?? DateTime.now().toIso8601String(),
        };
        
        // Add optional fields only if they exist
        if (doc['userAvatarUrl'] != null) {
          formattedComment['userAvatarUrl'] = doc['userAvatarUrl'] as String;
        }
        
        if (doc['parentCommentId'] != null) {
          formattedComment['parentCommentId'] = (doc['parentCommentId'] as ObjectId).toHexString();
        }
        
        commentsList.add(formattedComment);
      }

      final totalPages = totalComments > 0 ? (totalComments / limit).ceil() : 1;
      final hasNextPage = page < totalPages;
      final hasPrevPage = page > 1;

      // IMPORTANT: Response must be a JSON object, not an array!
      final responseData = {
        'comments': commentsList, // This is an array INSIDE the object
        'pagination': {
          'currentPage': page,
          'totalPages': totalPages,
          'totalComments': totalComments,
          'limit': limit,
          'hasNextPage': hasNextPage,
          'hasPrevPage': hasPrevPage,
        }
      };

      final jsonResponse = jsonEncode(responseData);
      print('[CommentController] Sending response with ${commentsList.length} comments');
      print('[CommentController] Response structure: ${responseData.keys.toList()}');
      
      return Response.ok(
        jsonResponse, 
        headers: {'Content-Type': 'application/json'}
      );
      
    } catch (e, s) {
      print('[CommentController.getVideoCommentsHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch comments: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Helper method to format likes array consistently
  static List<String> _formatLikesArray(dynamic likesData) {
    if (likesData == null) return <String>[];
    
    if (likesData is List) {
      return likesData.map((like) {
        if (like is ObjectId) {
          return like.toHexString();
        } else if (like is String) {
          return like;
        } else {
          return like.toString();
        }
      }).toList().cast<String>();
    }
    
    return <String>[];
  }

  // Delete comment
  static Future<Response> deleteCommentHandler(Request request, String commentId, String userIdString) async {
    print('[CommentController] Deleting comment: $commentId by user: $userIdString');
    
    try {
      // Convert IDs
      ObjectId commentObjectId; 
      ObjectId userObjectId;
      try {
        commentObjectId = ObjectId.fromHexString(commentId);
        userObjectId = ObjectId.fromHexString(userIdString);
      } catch (e) {
        return Response(400, 
          body: jsonEncode({'error': 'Invalid commentId or userId format'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final commentsCollection = DatabaseService.db.collection('comments');
      
      // Find the comment
      final commentDoc = await commentsCollection.findOne(where.id(commentObjectId));
      if (commentDoc == null) {
        return Response(404, 
          body: jsonEncode({'error': 'Comment not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final comment = Comment.fromMap(commentDoc);
      
      // Check if user owns the comment
      if (comment.userId != userObjectId) {
        return Response(403, 
          body: jsonEncode({'error': 'You can only delete your own comments'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Delete the comment
      final deleteResult = await commentsCollection.deleteOne(where.id(commentObjectId));
      
      if (deleteResult.isSuccess) {
        // Update video's comment count
        final videosCollection = DatabaseService.db.collection('videos');
        await videosCollection.updateOne(
          where.id(comment.videoId), 
          modify.inc('commentsCount', -1)
        );
        
        print('[CommentController] Comment deleted successfully');
        
        return Response.ok(
          jsonEncode({
            'message': 'Comment deleted successfully',
            'deletedCommentId': commentId
          }), 
          headers: {'Content-Type': 'application/json'}
        );
      } else {
        print('[CommentController] Failed to delete comment: ${deleteResult.writeError?.errmsg}');
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to delete comment'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
    } catch (e, s) {
      print('[CommentController.deleteCommentHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred while deleting comment: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }
}