// tiktok_backend/lib/src/core/config/database_service.dart
import 'package:mongo_dart/mongo_dart.dart';
import 'package:tiktok_backend/src/core/config/env_config.dart';

class DatabaseService {
  static Db? _db;

  static Db get db {
    if (_db == null || _db!.state == State.closed) {
      throw Exception(
          "[DatabaseService] Database not initialized or connection closed. Call DatabaseService.connect() first.");
    }
    return _db!;
  }

  static Future<void> connect() async {
    if (_db != null && _db!.isConnected) {
      print("[DatabaseService] Already connected to MongoDB.");
      return;
    }
    try {
      print(
          "[DatabaseService] Attempting to connect to MongoDB using URI from EnvConfig...");
      final mongoUri = EnvConfig.mongoDbUri;
      _db = await Db.create(mongoUri);
      print("[DatabaseService] Db instance created. Opening connection...");
      // Với Atlas SRV, `secure` thường được xử lý tự động.
      // `await _db!.open();` thường là đủ.
      // Bạn có thể thử `secure: true` nếu có cảnh báo hoặc vấn đề SSL/TLS,
      // nhưng thường không cần thiết với SRV URI.
      await _db!.open(); 
      print(
          '[DatabaseService] ✅ Successfully connected to MongoDB (URI specifics hidden for safety in logs).');

      // Bỏ qua bước ping/serverStatus chi tiết vì user có thể không có quyền,
      // hoặc nếu `open()` thành công thì kết nối cơ bản đã được thiết lập.
      print(
          '[DatabaseService] Basic connection established. Further command execution will verify operational status.');
          
    } catch (e, stackTrace) {
      print(
          '[DatabaseService] ❌ Error connecting to MongoDB in DatabaseService.connect: $e');
      print('[DatabaseService] Stack trace for connection error: $stackTrace');
      _db = null; // Đặt lại _db về null nếu kết nối thất bại
      rethrow; // Ném lại lỗi để server.dart có thể bắt và dừng server nếu cần
    }
  }

  static Future<void> close() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
      _db = null; // Đặt lại _db về null sau khi đóng
      print('[DatabaseService] MongoDB connection closed.');
    }
  }
}