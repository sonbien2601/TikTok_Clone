import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tiktok_frontend/src/core/config/network_config.dart';

class UserService {
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Trả về các trường cần thiết cho donate history
        return {
          'id': data['_id'] ?? data['id'] ?? userId,
          'username': data['username'] ?? '',
          'avatarUrl': data['avatarUrl'],
        };
      }
    } catch (e) {
      // ignore
    }
    return null;
  }
} 