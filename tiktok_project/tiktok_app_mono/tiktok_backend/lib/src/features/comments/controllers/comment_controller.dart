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

      // Check if video exists and get video owner
      final videosCollection = DatabaseService.db.collection('videos');
      final videoDoc = await videosCollection.findOne(where.id(videoObjectId));
      if (videoDoc == null) {
        return Response(404, 
          body: jsonEncode({'error': 'Video not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
      
      final videoOwnerId = videoDoc['userId'] as ObjectId;

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
        
        // Create notification for video owner (if not commenting on own video)
        if (userObjectId != videoOwnerId) {
          await _createNotification(
            receiverId: videoOwnerId,
            senderId: userObjectId,
            senderUsername: username,
            type: 'comment',
            message: 'đã bình luận về video của bạn: "$text"',
            relatedVideoId: videoObjectId,
            relatedCommentId: result.id,
          );
        }
        
        print('[CommentController] Comment added successfully. ID: ${result.id}');

        // Create properly formatted response
        final responseData = {
          'message': 'Comment added successfully',
          'comment': {
            '_id': result.id!.toHexString(),
            'videoId': videoObjectId.toHexString(),
            'userId': userObjectId.toHexString(),
            'username': username,
            'text': text.trim(),
            'likesCount': 0,
            'likes': <String>[], 
            'repliesCount': 0,
            'createdAt': newComment.createdAt.toIso8601String(),
            'updatedAt': newComment.updatedAt.toIso8601String(),
            if (userAvatarUrl != null) 'userAvatarUrl': userAvatarUrl,
          }
        };

        return Response.ok(
          jsonEncode(responseData), 
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

  // Reply to a comment
  static Future<Response> replyToCommentHandler(Request request, String parentCommentId, String userIdString, String text) async {
    print('[CommentController] Replying to comment: $parentCommentId by user: $userIdString');
    
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
      ObjectId parentCommentObjectId; 
      ObjectId userObjectId;
      try {
        parentCommentObjectId = ObjectId.fromHexString(parentCommentId);
        userObjectId = ObjectId.fromHexString(userIdString);
      } catch (e) {
        return Response(400, 
          body: jsonEncode({'error': 'Invalid commentId or userId format'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final commentsCollection = DatabaseService.db.collection('comments');
      
      // Find parent comment
      final parentCommentDoc = await commentsCollection.findOne(where.id(parentCommentObjectId));
      if (parentCommentDoc == null) {
        return Response(404, 
          body: jsonEncode({'error': 'Parent comment not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final parentComment = Comment.fromMap(parentCommentDoc);
      final videoObjectId = parentComment.videoId;

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

      // Create reply comment
      final replyComment = Comment(
        videoId: videoObjectId, 
        userId: userObjectId,
        username: username, 
        userAvatarUrl: userAvatarUrl, 
        text: text.trim(),
        parentCommentId: parentCommentObjectId,
      );

      // Insert reply
      final result = await commentsCollection.insertOne(replyComment.toMap());

      if (result.isSuccess) {
        // Update parent comment's reply count
        await commentsCollection.updateOne(
          where.id(parentCommentObjectId), 
          modify.inc('repliesCount', 1)
        );
        
        // Create notification for parent comment owner (if not replying to own comment)
        if (userObjectId != parentComment.userId) {
          await _createNotification(
            receiverId: parentComment.userId,
            senderId: userObjectId,
            senderUsername: username,
            type: 'reply',
            message: 'đã trả lời bình luận của bạn: "$text"',
            relatedVideoId: videoObjectId,
            relatedCommentId: result.id,
            relatedParentCommentId: parentCommentObjectId,
          );
        }
        
        print('[CommentController] Reply added successfully. ID: ${result.id}');

        final responseData = {
          'message': 'Reply added successfully',
          'comment': {
            '_id': result.id!.toHexString(),
            'videoId': videoObjectId.toHexString(),
            'userId': userObjectId.toHexString(),
            'username': username,
            'text': text.trim(),
            'likesCount': 0,
            'likes': <String>[], 
            'repliesCount': 0,
            'parentCommentId': parentCommentObjectId.toHexString(),
            'createdAt': replyComment.createdAt.toIso8601String(),
            'updatedAt': replyComment.updatedAt.toIso8601String(),
            if (userAvatarUrl != null) 'userAvatarUrl': userAvatarUrl,
          }
        };

        return Response.ok(
          jsonEncode(responseData), 
          headers: {'Content-Type': 'application/json'}
        );
      } else {
        print('[CommentController] Failed to insert reply: ${result.writeError?.errmsg}');
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to add reply to database'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
    } catch (e, s) {
      print('[CommentController.replyToCommentHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred while adding reply: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Toggle like on comment
  static Future<Response> toggleLikeCommentHandler(Request request, String commentId, String userIdString) async {
    print('[CommentController] Toggling like on comment: $commentId by user: $userIdString');
    
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
      final commentDoc = await commentsCollection.findOne(where.id(commentObjectId));
      if (commentDoc == null) {
        return Response(404, 
          body: jsonEncode({'error': 'Comment not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final comment = Comment.fromMap(commentDoc);
      List<ObjectId> likesList = List.from(comment.likes);
      bool isCurrentlyLiked;
      
      if (likesList.contains(userObjectId)) {
        likesList.remove(userObjectId); 
        isCurrentlyLiked = false;
      } else {
        likesList.add(userObjectId); 
        isCurrentlyLiked = true;
      }

      // Update comment
      final updateResult = await commentsCollection.updateOne(
        where.id(commentObjectId),
        modify.set('likes', likesList).set('likesCount', likesList.length)
      );
      
      if (updateResult.isSuccess) {
        // Create notification for comment owner (if liking someone else's comment)
        if (isCurrentlyLiked && userObjectId != comment.userId) {
          final usersCollection = DatabaseService.db.collection('users');
          final userDoc = await usersCollection.findOne(where.id(userObjectId).fields(['username']));
          final username = userDoc?['username'] as String? ?? 'Anonymous';
          
          await _createNotification(
            receiverId: comment.userId,
            senderId: userObjectId,
            senderUsername: username,
            type: 'comment_like',
            message: 'đã thích bình luận của bạn',
            relatedVideoId: comment.videoId,
            relatedCommentId: commentObjectId,
          );
        }
        
        // Get updated comment
        final updatedCommentDoc = await commentsCollection.findOne(where.id(commentObjectId));
        if (updatedCommentDoc == null) {
          return Response(404, 
            body: jsonEncode({'error': 'Comment not found after update'}),
            headers: {'Content-Type': 'application/json'}
          );
        }

        // Format response
        final formattedComment = <String, dynamic>{
          '_id': (updatedCommentDoc['_id'] as ObjectId).toHexString(),
          'videoId': (updatedCommentDoc['videoId'] as ObjectId).toHexString(),
          'userId': (updatedCommentDoc['userId'] as ObjectId).toHexString(),
          'username': updatedCommentDoc['username'] as String? ?? 'Anonymous',
          'text': updatedCommentDoc['text'] as String? ?? '',
          'likesCount': updatedCommentDoc['likesCount'] as int? ?? 0,
          'likes': _formatLikesArray(updatedCommentDoc['likes']),
          'repliesCount': updatedCommentDoc['repliesCount'] as int? ?? 0,
          'createdAt': updatedCommentDoc['createdAt'] as String? ?? DateTime.now().toIso8601String(),
          'updatedAt': updatedCommentDoc['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
        };

        // Add optional fields
        if (updatedCommentDoc['userAvatarUrl'] != null) {
          formattedComment['userAvatarUrl'] = updatedCommentDoc['userAvatarUrl'] as String;
        }
        
        if (updatedCommentDoc['parentCommentId'] != null) {
          formattedComment['parentCommentId'] = (updatedCommentDoc['parentCommentId'] as ObjectId).toHexString();
        }
        
        return Response.ok(
          jsonEncode({
            'message': isCurrentlyLiked ? 'Comment liked' : 'Comment unliked',
            'isLiked': isCurrentlyLiked,
            'likesCount': likesList.length,
            'comment': formattedComment
          }), 
          headers: {'Content-Type': 'application/json'}
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to update like status'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
    } catch (e, s) {
      print('[CommentController.toggleLikeCommentHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred while toggling like: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Get replies for a comment
  static Future<Response> getCommentRepliesHandler(Request request, String commentId, int page, int limit) async {
    print('[CommentController] Getting replies for commentId: $commentId (page: $page, limit: $limit)');
    
    try {
      // Validate commentId
      ObjectId commentObjectId;
      try { 
        commentObjectId = ObjectId.fromHexString(commentId); 
      } catch (e) { 
        return Response(400, 
          body: jsonEncode({'error': 'Invalid commentId format'}),
          headers: {'Content-Type': 'application/json'}
        ); 
      }

      // Validate pagination parameters
      if (page < 1) page = 1;
      if (limit < 1 || limit > 100) limit = 20;
      
      final skip = (page - 1) * limit;

      // Check if parent comment exists
      final commentsCollection = DatabaseService.db.collection('comments');
      final parentCommentDoc = await commentsCollection.findOne(where.id(commentObjectId));
      if (parentCommentDoc == null) {
        return Response(404, 
          body: jsonEncode({'error': 'Parent comment not found'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      final totalReplies = parentCommentDoc['repliesCount'] as int? ?? 0;

      // Get replies with pagination
      final repliesCursor = commentsCollection.find(
        SelectorBuilder()
          .eq('parentCommentId', commentObjectId)
          .sortBy('createdAt', descending: false) // Show oldest replies first
          .skip(skip)
          .limit(limit)
      );
      
      final List<Map<String, dynamic>> repliesList = [];
      await for (var doc in repliesCursor) {
        final formattedReply = <String, dynamic>{
          '_id': (doc['_id'] as ObjectId).toHexString(),
          'videoId': (doc['videoId'] as ObjectId).toHexString(),
          'userId': (doc['userId'] as ObjectId).toHexString(),
          'username': doc['username'] as String? ?? 'Anonymous',
          'text': doc['text'] as String? ?? '',
          'likesCount': doc['likesCount'] as int? ?? 0,
          'likes': _formatLikesArray(doc['likes']),
          'repliesCount': doc['repliesCount'] as int? ?? 0,
          'parentCommentId': (doc['parentCommentId'] as ObjectId).toHexString(),
          'createdAt': (doc['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
          'updatedAt': (doc['updatedAt'] as String?) ?? DateTime.now().toIso8601String(),
        };
        
        if (doc['userAvatarUrl'] != null) {
          formattedReply['userAvatarUrl'] = doc['userAvatarUrl'] as String;
        }
        
        repliesList.add(formattedReply);
      }

      final totalPages = totalReplies > 0 ? (totalReplies / limit).ceil() : 1;
      final hasNextPage = page < totalPages;
      final hasPrevPage = page > 1;

      final responseData = {
        'replies': repliesList,
        'pagination': {
          'currentPage': page,
          'totalPages': totalPages,
          'totalReplies': totalReplies,
          'limit': limit,
          'hasNextPage': hasNextPage,
          'hasPrevPage': hasPrevPage,
        }
      };

      return Response.ok(
        jsonEncode(responseData), 
        headers: {'Content-Type': 'application/json'}
      );
      
    } catch (e, s) {
      print('[CommentController.getCommentRepliesHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch replies: $e'}),
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
      if (limit < 1 || limit > 100) limit = 20;
      
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

      // Get comments with pagination (only top-level comments)
      final commentsCollection = DatabaseService.db.collection('comments');
      final commentsCursor = commentsCollection.find(
        SelectorBuilder()
          .eq('videoId', videoObjectId)
          .eq('parentCommentId', null) // Only get top-level comments
          .sortBy('createdAt', descending: true)
          .skip(skip)
          .limit(limit)
      );
      
      final List<Map<String, dynamic>> commentsList = [];
      await for (var doc in commentsCursor) {
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

      final responseData = {
        'comments': commentsList,
        'pagination': {
          'currentPage': page,
          'totalPages': totalPages,
          'totalComments': totalComments,
          'limit': limit,
          'hasNextPage': hasNextPage,
          'hasPrevPage': hasPrevPage,
        }
      };

      return Response.ok(
        jsonEncode(responseData), 
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

  // Edit comment - EXISTING METHOD (keeping as is)
  static Future<Response> editCommentHandler(Request request, String commentId, String userIdString, String newText) async {
    print('[CommentController] Editing comment: $commentId by user: $userIdString');
    print('[CommentController] New text: "$newText"');
    
    try {
      // Validate input
      final textValidation = Comment.validateText(newText);
      if (textValidation != null) {
        return Response(400, 
          body: jsonEncode({'error': textValidation}),
          headers: {'Content-Type': 'application/json'}
        );
      }

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
          body: jsonEncode({'error': 'You can only edit your own comments'}),
          headers: {'Content-Type': 'application/json'}
        );
      }

      // Update the comment
      final updateResult = await commentsCollection.updateOne(
        where.id(commentObjectId),
        modify
          .set('text', newText.trim())
          .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      if (updateResult.isSuccess) {
        // Get the updated comment
        final updatedCommentDoc = await commentsCollection.findOne(where.id(commentObjectId));
        if (updatedCommentDoc == null) {
          return Response(404, 
            body: jsonEncode({'error': 'Comment not found after update'}),
            headers: {'Content-Type': 'application/json'}
          );
        }

        // Format response
        final formattedComment = <String, dynamic>{
          '_id': (updatedCommentDoc['_id'] as ObjectId).toHexString(),
          'videoId': (updatedCommentDoc['videoId'] as ObjectId).toHexString(),
          'userId': (updatedCommentDoc['userId'] as ObjectId).toHexString(),
          'username': updatedCommentDoc['username'] as String? ?? 'Anonymous',
          'text': updatedCommentDoc['text'] as String? ?? '',
          'likesCount': updatedCommentDoc['likesCount'] as int? ?? 0,
          'likes': _formatLikesArray(updatedCommentDoc['likes']),
          'repliesCount': updatedCommentDoc['repliesCount'] as int? ?? 0,
          'createdAt': updatedCommentDoc['createdAt'] as String? ?? DateTime.now().toIso8601String(),
          'updatedAt': updatedCommentDoc['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
        };

        // Add optional fields
        if (updatedCommentDoc['userAvatarUrl'] != null) {
          formattedComment['userAvatarUrl'] = updatedCommentDoc['userAvatarUrl'] as String;
        }
        
        if (updatedCommentDoc['parentCommentId'] != null) {
          formattedComment['parentCommentId'] = (updatedCommentDoc['parentCommentId'] as ObjectId).toHexString();
        }
        
        print('[CommentController] Comment edited successfully');
        
        return Response.ok(
          jsonEncode({
            'message': 'Comment updated successfully',
            'comment': formattedComment
          }), 
          headers: {'Content-Type': 'application/json'}
        );
      } else {
        print('[CommentController] Failed to update comment: ${updateResult.writeError?.errmsg}');
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to update comment'}),
          headers: {'Content-Type': 'application/json'}
        );
      }
    } catch (e, s) {
      print('[CommentController.editCommentHandler] Error: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'error': 'An unexpected error occurred while editing comment: $e'}),
        headers: {'Content-Type': 'application/json'}
      );
    }
  }

  // Delete comment - EXISTING METHOD (keeping as is)
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

      // Delete the comment and all its replies
      final deleteResult = await commentsCollection.deleteOne(where.id(commentObjectId));
      
      if (deleteResult.isSuccess) {
        // Delete all replies to this comment
        await commentsCollection.deleteMany(where.eq('parentCommentId', commentObjectId));
        
        // Update video's comment count (including replies)
        final videosCollection = DatabaseService.db.collection('videos');
        final replyCount = comment.repliesCount;
        final totalDecrement = 1 + replyCount; // Original comment + all replies
        
        await videosCollection.updateOne(
          where.id(comment.videoId), 
          modify.inc('commentsCount', -totalDecrement)
        );
        
        // If this is a reply, update parent comment's reply count
        if (comment.parentCommentId != null) {
          await commentsCollection.updateOne(
            where.id(comment.parentCommentId!),
            modify.inc('repliesCount', -1)
          );
        }
        
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

  // Helper method to create notifications
  static Future<void> _createNotification({
    required ObjectId receiverId,
    required ObjectId senderId,
    required String senderUsername,
    required String type,
    required String message,
    ObjectId? relatedVideoId,
    ObjectId? relatedCommentId,
    ObjectId? relatedParentCommentId,
  }) async {
    try {
      final notificationsCollection = DatabaseService.db.collection('notifications');
      
      final notification = {
        'receiverId': receiverId,
        'senderId': senderId,
        'senderUsername': senderUsername,
        'type': type,
        'message': message,
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      if (relatedVideoId != null) {
        notification['relatedVideoId'] = relatedVideoId;
      }
      
      if (relatedCommentId != null) {
        notification['relatedCommentId'] = relatedCommentId;
      }
      
      if (relatedParentCommentId != null) {
        notification['relatedParentCommentId'] = relatedParentCommentId;
      }
      
      await notificationsCollection.insertOne(notification);
      print('[CommentController] Notification created for user: $receiverId, type: $type');
    } catch (e) {
      print('[CommentController] Error creating notification: $e');
      // Don't throw error, just log it so the main operation doesn't fail
    }
  }
}