// tiktok_backend/lib/src/features/users/controllers/auth_controller.dart
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:shelf/shelf.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' show utf8;
import '../user_model.dart'; // Import User model từ thư mục cha (users)

class AuthController {
  // --- HÀM ĐĂNG KÝ ---
  static Future<Response> registerHandler(Request request) async {
    try {
      final requestBody = await request.readAsString();
      if (requestBody.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'Request body is empty'}));
      }
      final Map<String, dynamic> payload = jsonDecode(requestBody);

      final username = payload['username'] as String?;
      final email = (payload['email'] as String?)?.toLowerCase();
      final password = payload['password'] as String?;
      final dobString = payload['dateOfBirth'] as String?;
      final gender = payload['gender'] as String?;
      final interests = List<String>.from(payload['interests'] as List? ?? []);

      if (username == null || email == null || password == null) {
        return Response(400, body: jsonEncode({'error': 'Username, email, and password are required'}));
      }
      if (password.length < 6) {
        return Response(400, body: jsonEncode({'error': 'Password must be at least 6 characters long'}));
      }

      final usersCollection = DatabaseService.db.collection('users');
      final Map<String, dynamic>? existingUserEmail = await usersCollection.findOne({'email': email});
      if (existingUserEmail != null) {
        return Response(409, body: jsonEncode({'error': 'Email already exists'}));
      }
      final Map<String, dynamic>? existingUserUsername = await usersCollection.findOne({'username': username.toLowerCase()}); // Kiểm tra username chữ thường
      if (existingUserUsername != null) {
        return Response(409, body: jsonEncode({'error': 'Username already exists'}));
      }

      final hashedPassword = crypto.sha256.convert(utf8.encode(password)).toString();
      print('[AuthController] Registering user. Email: $email, Hashed: $hashedPassword');

      final newUser = User(
        username: username, // Lưu username gốc (có thể phân biệt hoa thường nếu muốn, nhưng tìm kiếm nên chuẩn hóa)
        email: email,
        passwordHash: hashedPassword,
        dateOfBirth: dobString != null ? DateTime.tryParse(dobString) : null,
        gender: gender,
        interests: interests,
      );

      final result = await usersCollection.insertOne(newUser.toMap());

      if (result.isSuccess) {
        final Map<String, dynamic>? insertedUserMapNullable = await usersCollection.findOne({'_id': result.id});
        if (insertedUserMapNullable == null) {
          return Response.internalServerError(body: jsonEncode({'error': 'Failed to retrieve user details after registration'}));
        }
        Map<String, dynamic> insertedUserMap = insertedUserMapNullable;
        insertedUserMap.remove('passwordHash');
        if (result.id != null) {
          insertedUserMap['_id'] = result.id!.toHexString();
        }
        return Response.ok(
            jsonEncode({'message': 'User registered successfully', 'user': insertedUserMap}),
            headers: {'Content-Type': 'application/json'});
      } else {
        return Response.internalServerError(body: jsonEncode({'error': 'Failed to register user: ${result.writeError?.errmsg}'}));
      }
    } catch (e, stackTrace) {
      print('[AuthController.register] Error: $e \nStack: $stackTrace');
      if (e is FormatException) {
        return Response(400, body: jsonEncode({'error': 'Invalid JSON format'}));
      }
      return Response.internalServerError(body: jsonEncode({'error': 'An unexpected error occurred'}));
    }
  }

  // --- HÀM ĐĂNG NHẬP ---
  static Future<Response> loginHandler(Request request) async {
    try {
      final requestBody = await request.readAsString();
      if (requestBody.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'Request body is empty'}));
      }
      final Map<String, dynamic> payload = jsonDecode(requestBody);

      final identifier = payload['identifier'] as String?;
      final password = payload['password'] as String?;

      if (identifier == null || password == null) {
        return Response(400, body: jsonEncode({'error': 'Identifier (username or email) and password are required'}));
      }

      final usersCollection = DatabaseService.db.collection('users');
      Map<String, dynamic>? userDocNullable;
      final lowercasedIdentifier = identifier.toLowerCase();

      if (lowercasedIdentifier.contains('@')) {
        userDocNullable = await usersCollection.findOne({'email': lowercasedIdentifier});
      }
      userDocNullable ??= await usersCollection.findOne({'username': lowercasedIdentifier});

      if (userDocNullable == null) {
        return Response(401, body: jsonEncode({'error': 'Invalid identifier or password'}));
      }
      Map<String, dynamic> userDoc = userDocNullable;

      final storedPasswordHash = userDoc['passwordHash'] as String?;
      if (storedPasswordHash == null) {
        return Response(500, body: jsonEncode({'error': 'User data integrity issue: missing password hash.'}));
      }

      final inputPasswordHash = crypto.sha256.convert(utf8.encode(password)).toString();
      if (inputPasswordHash != storedPasswordHash) {
        return Response(401, body: jsonEncode({'error': 'Invalid identifier or password'}));
      }

      userDoc.remove('passwordHash');
      if (userDoc['_id'] is ObjectId) {
        userDoc['_id'] = (userDoc['_id'] as ObjectId).toHexString();
      }
      
      // TODO: Implement JWT generation and return token
      return Response.ok(
          jsonEncode({'message': 'Login successful', 'user': userDoc}),
          headers: {'Content-Type': 'application/json'});
    } catch (e, stackTrace) {
      print('[AuthController.login] Error: $e \nStack: $stackTrace');
      if (e is FormatException) {
        return Response(400, body: jsonEncode({'error': 'Invalid JSON format'}));
      }
      return Response.internalServerError(body: jsonEncode({'error': 'An unexpected error occurred'}));
    }
  }
}