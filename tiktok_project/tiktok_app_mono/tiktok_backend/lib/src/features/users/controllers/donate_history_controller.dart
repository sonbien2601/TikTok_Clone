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
        return Response(400, body: jsonEncode({'error': 'Missing required fields'}));
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
        return Response.ok(jsonEncode({'message': 'Donate created successfully'}));
      } else {
        return Response.internalServerError(body: jsonEncode({'error': 'Failed to create donate'}));
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // Lấy lịch sử donate của user (đã donate cho ai)
  static Future<Response> getDonateHistoryByUserHandler(Request request, String userId) async {
    try {
      final collection = DatabaseService.db.collection('donate_history');
      final objectId = ObjectId.fromHexString(userId);
      final history = await collection.find(where.eq('fromUserId', objectId)).toList();
      final result = history.map((e) => {
        ...e,
        '_id': (e['_id'] as ObjectId).toHexString(),
        'fromUserId': (e['fromUserId'] as ObjectId).toHexString(),
        'toUserId': (e['toUserId'] as ObjectId).toHexString(),
      }).toList();
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // Lấy lịch sử nhận donate của user (ai đã donate cho mình)
  static Future<Response> getReceivedDonateHistoryHandler(Request request, String userId) async {
    try {
      final collection = DatabaseService.db.collection('donate_history');
      final objectId = ObjectId.fromHexString(userId);
      final history = await collection.find(where.eq('toUserId', objectId)).toList();
      final result = history.map((e) => {
        ...e,
        '_id': (e['_id'] as ObjectId).toHexString(),
        'fromUserId': (e['fromUserId'] as ObjectId).toHexString(),
        'toUserId': (e['toUserId'] as ObjectId).toHexString(),
      }).toList();
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }
} 