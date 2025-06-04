// tiktok_backend/lib/src/features/users/controllers/profile_controller.dart
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:shelf/shelf.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';
// import '../user_model.dart'; // User model không cần thiết trực tiếp ở đây nếu chỉ trả về Map

class ProfileController {
  // --- HÀM LẤY HỒ SƠ NGƯỜI DÙNG THEO ID ---
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

      userDoc.remove('passwordHash'); // Loại bỏ trường nhạy cảm
      if (userDoc['_id'] is ObjectId) { // Đảm bảo _id là string
        userDoc['_id'] = (userDoc['_id'] as ObjectId).toHexString();
      }
      
      return Response.ok(jsonEncode(userDoc), headers: {'Content-Type': 'application/json'});

    } catch (e, stackTrace) {
      print('[ProfileController.getUserProfile] Error: $e \nStack: $stackTrace');
      if (e is FormatException && e.message.contains("ObjectId")) {
         return Response(400, body: jsonEncode({'error': 'Invalid user ID format (could not convert to ObjectId)'}));
      }
      return Response.internalServerError(body: jsonEncode({'error': 'An unexpected error occurred'}));
    }
  }

  // TODO: Thêm các handler khác cho profile (ví dụ: updateUserProfileHandler)
}