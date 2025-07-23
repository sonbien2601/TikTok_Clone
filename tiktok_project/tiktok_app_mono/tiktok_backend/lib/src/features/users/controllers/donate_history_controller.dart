// Sửa lại donate_history_controller.dart để trả về đúng thông tin
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify;
import 'package:shelf/shelf.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';
import '../donate_history_model.dart';

class DonateHistoryController {
  // Tạo donate mới
  static Future<Response> createDonateHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final fromUserId = data['fromUserId'] as String?;
      final toUserId = data['toUserId'] as String?;
      final amount = data['amount'] as int?;
      final donateProofImageUrl = data['donateProofImageUrl'] as String?;

      if (fromUserId == null || toUserId == null || amount == null) {
        return Response(400,
            body: jsonEncode({'error': 'Missing required fields'}));
      }

      final donate = DonateHistory(
        fromUserId: ObjectId.fromHexString(fromUserId),
        toUserId: ObjectId.fromHexString(toUserId),
        amount: amount,
        donateProofImageUrl: donateProofImageUrl,
      );

      final collection = DatabaseService.db.collection('donate_history');
      final result = await collection.insertOne(donate.toMap());

      if (result.isSuccess) {
        return Response.ok(
            jsonEncode({'message': 'Donate created successfully'}));
      } else {
        return Response.internalServerError(
            body: jsonEncode({'error': 'Failed to create donate'}));
      }
    } catch (e) {
      print('[DonateHistoryController.createDonate] Error: $e');
      return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}));
    }
  }

  // Lấy lịch sử donate của user (đã donate cho ai)
  static Future<Response> getDonateHistoryByUserHandler(
      Request request, String userId) async {
    print(
        '[DonateHistoryController] Getting donate history for userId: $userId');
    try {
      // Validate userId format
      if (userId.length != 24 ||
          !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(userId)) {
        return Response(400,
            body: jsonEncode({'error': 'Invalid user ID format'}));
      }

      final collection = DatabaseService.db.collection('donate_history');
      final usersCollection = DatabaseService.db.collection('users');
      final objectId = ObjectId.fromHexString(userId);

      // Get donate history with user info
      final history =
          await collection.find(where.eq('fromUserId', objectId)).toList();

      // Enrich data with user information
      final enrichedHistory = <Map<String, dynamic>>[];

      for (final donate in history) {
        final toUserId = donate['toUserId'] as ObjectId;

        // Get recipient user info
        final recipientUser = await usersCollection.findOne({'_id': toUserId});

        final enrichedDonate = {
          '_id': (donate['_id'] as ObjectId).toHexString(),
          'fromUserId': (donate['fromUserId'] as ObjectId).toHexString(),
          'toUserId': toUserId.toHexString(),
          'amount': donate['amount'],
          'donateProofImageUrl': donate['donateProofImageUrl'],
          'createdAt': donate['createdAt'],
          'updatedAt': donate['updatedAt'],
          // Add recipient user info
          'recipientUsername': recipientUser?['username'] ?? 'Unknown User',
          'recipientAvatarUrl': recipientUser?['avatarUrl'],
        };

        enrichedHistory.add(enrichedDonate);
      }

      // Sort by creation date (newest first)
      enrichedHistory.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      print(
          '[DonateHistoryController] Found ${enrichedHistory.length} sent donations');

      return Response.ok(jsonEncode(enrichedHistory),
          headers: {'Content-Type': 'application/json'});
    } catch (e, stackTrace) {
      print(
          '[DonateHistoryController.getDonateHistory] Error: $e \nStack: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}));
    }
  }

  // Lấy lịch sử nhận donate của user (ai đã donate cho mình)
  static Future<Response> getReceivedDonateHistoryHandler(
      Request request, String userId) async {
    print(
        '[DonateHistoryController] Getting received donate history for userId: $userId');
    try {
      // Validate userId format
      if (userId.length != 24 ||
          !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(userId)) {
        return Response(400,
            body: jsonEncode({'error': 'Invalid user ID format'}));
      }

      final collection = DatabaseService.db.collection('donate_history');
      final usersCollection = DatabaseService.db.collection('users');
      final objectId = ObjectId.fromHexString(userId);

      // Get received donate history
      final history =
          await collection.find(where.eq('toUserId', objectId)).toList();

      // Enrich data with sender user information
      final enrichedHistory = <Map<String, dynamic>>[];

      for (final donate in history) {
        final fromUserId = donate['fromUserId'] as ObjectId;

        // Get sender user info
        final senderUser = await usersCollection.findOne({'_id': fromUserId});

        final enrichedDonate = {
          '_id': (donate['_id'] as ObjectId).toHexString(),
          'fromUserId': fromUserId.toHexString(),
          'toUserId': (donate['toUserId'] as ObjectId).toHexString(),
          'amount': donate['amount'],
          'donateProofImageUrl': donate['donateProofImageUrl'],
          'createdAt': donate['createdAt'],
          'updatedAt': donate['updatedAt'],
          // Add sender user info
          'senderUsername': senderUser?['username'] ?? 'Unknown User',
          'senderAvatarUrl': senderUser?['avatarUrl'],
        };

        enrichedHistory.add(enrichedDonate);
      }

      // Sort by creation date (newest first)
      enrichedHistory.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      print(
          '[DonateHistoryController] Found ${enrichedHistory.length} received donations');

      return Response.ok(jsonEncode(enrichedHistory),
          headers: {'Content-Type': 'application/json'});
    } catch (e, stackTrace) {
      print(
          '[DonateHistoryController.getReceivedDonateHistory] Error: $e \nStack: $stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}));
    }
  }
}
