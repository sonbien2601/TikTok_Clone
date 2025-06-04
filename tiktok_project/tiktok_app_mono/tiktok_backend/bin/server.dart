// tiktok_backend/bin/server.dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart'; 
import 'package:path/path.dart' as p;  
import 'package:tiktok_backend/src/core/config/env_config.dart';
import 'package:tiktok_backend/src/core/config/database_service.dart';
import 'package:tiktok_backend/src/features/users/user_routes.dart' show createUserRoutes; 
import 'package:tiktok_backend/src/features/videos/video_routes.dart' show createVideoRoutes; 
// Giả sử bạn đã tạo file này và hàm createCommentRoutes
import 'package:tiktok_backend/src/features/comments/comment_routes.dart' show createCommentRoutes; 

// --- Middleware cho CORS ---
const _corsHeaders = {
  'Access-Control-Allow-Origin': '*', 
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-Requested-With', 
  'Access-Control-Allow-Credentials': 'true',
};

Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response(204, headers: _corsHeaders); 
      }
      final response = await innerHandler(request);
      return response.change(headers: {...response.headers, ..._corsHeaders});
    };
  };
}
// --- Kết thúc Middleware CORS ---


Future<void> main() async {
  print('[Server] Main function started. Attempting to initialize...');
  try {
    print("[Server] Initializing server configuration by loading config.json...");
    // Đảm bảo bạn gọi đúng hàm loadConfig nếu đã đổi tên từ loadEnv
    // (phiên bản EnvConfig mới nhất của chúng ta dùng config.json và loadConfig)
    await EnvConfig.loadConfig(); 
    print("[Server] Configuration loaded.");
    
    String safeMongoUriToLog = EnvConfig.mongoDbUri;
    try {
      Uri parsedUri = Uri.parse(EnvConfig.mongoDbUri);
      if (parsedUri.userInfo.isNotEmpty) {
        safeMongoUriToLog = parsedUri.replace(userInfo: 'USER:PASS_HIDDEN').toString();
      }
    } catch (_) { /* ignore parsing error for logging */ }
    print("[Server] MONGO_DB_URI (masked for logging): $safeMongoUriToLog");
    print("[Server] SERVER_PORT from EnvConfig: ${EnvConfig.serverPort}");

    print("[Server] Connecting to MongoDB...");
    await DatabaseService.connect();
    print("[Server] MongoDB connection process completed successfully.");

  } catch (e) {
    print('[Server] FATAL: Failed to initialize server (EnvConfig or DatabaseService): $e');
    print('[Server] Server not starting.');
    exit(1); 
  }

  final appRouter = Router();

  // --- PHỤC VỤ FILE TĨNH TỪ THƯ MỤC UPLOADS ---
  final uploadsDirPath = p.join(Directory.current.path, 'uploads');
  print('[Server] Attempting to serve static files from: $uploadsDirPath');
  final staticFileHandler = createStaticHandler(
    uploadsDirPath, 
    defaultDocument: null, 
    serveFilesOutsidePath: false, 
  );
  appRouter.mount('/uploads/', staticFileHandler);
  print("[Server] Static file handler for '/uploads/' mounted.");


  appRouter.get('/hello', (Request request) {
    print('[Server] Received request for /hello');
    return Response.ok('Hello from Backend, connected to MongoDB!');
  });

  // Mount User routes
  try {
    appRouter.mount('/api/users', createUserRoutes()); 
    print("[Server] User API routes mounted successfully at /api/users");
  } catch (e) {
     print('[Server] WARNING: Could not mount UserApi routes. Ensure user_routes.dart and createUserRoutes() are correct. Error: $e');
  }

  // Mount Video routes
  try {
    appRouter.mount('/api/videos', createVideoRoutes());
    print("[Server] Video API routes mounted successfully at /api/videos");
  } catch (e) {
     print('[Server] WARNING: Could not mount VideoApi routes. Ensure video_routes.dart and createVideoRoutes() are correct. Error: $e');
  }

  // **BỔ SUNG MOUNT COMMENT ROUTES Ở ĐÂY**
  try {
    appRouter.mount('/api/comments', createCommentRoutes()); 
    print("[Server] Comment API routes mounted successfully at /api/comments");
  } catch (e) {
     print('[Server] WARNING: Could not mount Comment routes. Ensure comment_routes.dart and createCommentRoutes() are correct. Error: $e');
  }

  // Pipeline xử lý request
  final handler = const Pipeline()
      .addMiddleware(corsMiddleware()) 
      .addMiddleware(logRequests())    
      .addHandler(appRouter);

  final port = EnvConfig.serverPort;
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  print('🚀 Server listening on port ${server.port} at http://localhost:${server.port}');
}
