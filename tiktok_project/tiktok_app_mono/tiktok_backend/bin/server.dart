// tiktok_backend/bin/server.dart
import 'dart:io';
import 'dart:convert';
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
import 'package:tiktok_backend/src/features/notifications/notification_routes.dart';

// --- Middleware cho CORS ---
const _corsHeaders = {
  'Access-Control-Allow-Origin': '*', 
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-Requested-With, Accept', 
  'Access-Control-Allow-Credentials': 'true',
  'Access-Control-Max-Age': '86400',
};

Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      // Handle preflight OPTIONS requests
      if (request.method == 'OPTIONS') {
        print('[CORS] Handling OPTIONS preflight request for ${request.url}');
        return Response(204, headers: _corsHeaders); 
      }
      
      // Process normal requests and add CORS headers
      final response = await innerHandler(request);
      return response.change(headers: {...response.headers, ..._corsHeaders});
    };
  };
}

// Enhanced logging middleware
Middleware enhancedLoggingMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final startTime = DateTime.now();
      final timestamp = startTime.toIso8601String();
      
      print('[${timestamp}] ${request.method} ${request.url}');
      if (request.url.queryParameters.isNotEmpty) {
        print('[Server] Query params: ${request.url.queryParameters}');
      }
      
      try {
        final response = await innerHandler(request);
        final duration = DateTime.now().difference(startTime);
        
        print('[Server] ${request.method} ${request.url.path} - ${response.statusCode} (${duration.inMilliseconds}ms)');
        return response;
      } catch (e, stackTrace) {
        final duration = DateTime.now().difference(startTime);
        print('[Server] ERROR ${request.method} ${request.url.path} - Exception after ${duration.inMilliseconds}ms: $e');
        print('[Server] StackTrace: $stackTrace');
        
        return Response.internalServerError(
          body: '{"error": "Internal server error", "timestamp": "$timestamp"}',
          headers: {'Content-Type': 'application/json', ..._corsHeaders}
        );
      }
    };
  };
}

Future<void> main() async {
  print('[Server] 🚀 TikTok Backend Server Starting...');
  print('[Server] Timestamp: ${DateTime.now().toIso8601String()}');
  
  try {
    print("[Server] Loading configuration from config.json...");
    await EnvConfig.loadConfig(); 
    print("[Server] ✅ Configuration loaded successfully.");
    
    // Log masked MongoDB URI for security
    String safeMongoUriToLog = EnvConfig.mongoDbUri;
    try {
      Uri parsedUri = Uri.parse(EnvConfig.mongoDbUri);
      if (parsedUri.userInfo.isNotEmpty) {
        safeMongoUriToLog = parsedUri.replace(userInfo: 'USER:PASS_HIDDEN').toString();
      }
    } catch (_) { /* ignore parsing error for logging */ }
    print("[Server] MongoDB URI (masked): $safeMongoUriToLog");
    
    // QUAN TRỌNG: Cố định port 8080 thay vì dùng từ config
    const int fixedPort = 8080;
    print("[Server] 🔧 OVERRIDING port from config (${EnvConfig.serverPort}) to fixed port: $fixedPort");

    print("[Server] 🔗 Connecting to MongoDB...");
    await DatabaseService.connect();
    print("[Server] ✅ MongoDB connection established successfully.");

  } catch (e, stackTrace) {
    print('[Server] ❌ FATAL: Failed to initialize server configuration or database');
    print('[Server] Error: $e');
    print('[Server] StackTrace: $stackTrace');
    print('[Server] 🛑 Server startup aborted.');
    exit(1); 
  }

  // Create main application router
  final appRouter = Router();

  // --- ROOT ENDPOINT FOR API INFO ---
  appRouter.get('/', (Request request) {
    final serverInfo = {
      'message': 'TikTok Backend API Server',
      'version': '1.0.0',
      'status': 'running',
      'timestamp': DateTime.now().toIso8601String(),
      'endpoints': {
        'health': 'GET /health',
        'users': {
          'login': 'POST /api/users/login',
          'register': 'POST /api/users/register',
        },
        'videos': {
          'feed': 'GET /api/videos/feed',
          'upload': 'POST /api/videos/upload',
          'like': 'POST /api/videos/{videoId}/like',
          'save': 'POST /api/videos/{videoId}/save',
          'debug': 'GET /api/videos/debug/info'
        },
        'comments': {
          'add': 'POST /api/comments/video/{videoId}',
          'get': 'GET /api/comments/video/{videoId}',
          'like': 'POST /api/comments/like/{commentId}',
          'reply': 'POST /api/comments/reply/{commentId}',
          'debug': 'GET /api/comments/debug/info'
        },
        'notifications': {
          'get': 'GET /api/notifications/user/{userId}',
          'unread': 'GET /api/notifications/user/{userId}/unread-count',
          'markRead': 'PUT /api/notifications/{notificationId}/read',
          'markAllRead': 'PUT /api/notifications/user/{userId}/read-all',
          'delete': 'DELETE /api/notifications/{notificationId}',
          'debug': 'GET /api/notifications/debug/info'
        },
        'static': 'GET /uploads/{filename}'
      }
    };
    return Response.ok(
      jsonEncode(serverInfo),
      headers: {'Content-Type': 'application/json'}
    );
  });

  // --- HEALTH CHECK ENDPOINT ---
  appRouter.get('/health', (Request request) {
    print('[Server] Health check requested');
    final healthInfo = {
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
      'database': 'connected',
      'uptime': 'running'
    };
    return Response.ok(
      jsonEncode(healthInfo),
      headers: {'Content-Type': 'application/json'}
    );
  });

  // --- SERVE STATIC FILES FROM UPLOADS DIRECTORY ---
  final uploadsDirPath = p.join(Directory.current.path, 'uploads');
  print('[Server] 📁 Setting up static file serving from: $uploadsDirPath');
  
  // Ensure uploads directory exists
  final uploadsDir = Directory(uploadsDirPath);
  if (!await uploadsDir.exists()) {
    await uploadsDir.create(recursive: true);
    print('[Server] ✅ Created uploads directory: $uploadsDirPath');
  }
  
  final staticFileHandler = createStaticHandler(
    uploadsDirPath, 
    defaultDocument: null, 
    serveFilesOutsidePath: false,
  );
  appRouter.mount('/uploads/', staticFileHandler);
  print("[Server] ✅ Static file handler mounted at '/uploads/'");

  // --- LEGACY HELLO ENDPOINT ---
  appRouter.get('/hello', (Request request) {
    print('[Server] Hello endpoint accessed');
    return Response.ok(
      '{"message": "Hello from TikTok Backend! Connected to MongoDB successfully.", "timestamp": "${DateTime.now().toIso8601String()}"}',
      headers: {'Content-Type': 'application/json'}
    );
  });

  // --- MOUNT API ROUTES ---
  
  // Mount User routes
  try {
    final userRouter = createUserRoutes();
    appRouter.mount('/api/users', userRouter); 
    print("[Server] ✅ User API routes mounted at '/api/users'");
  } catch (e, stackTrace) {
     print('[Server] ⚠️  WARNING: Could not mount User API routes');
     print('[Server] Error: $e');
     print('[Server] Please ensure user_routes.dart and createUserRoutes() are implemented correctly');
  }

  // Mount Video routes
  try {
    final videoRouter = createVideoRoutes();
    appRouter.mount('/api/videos', videoRouter);
    print("[Server] ✅ Video API routes mounted at '/api/videos'");
  } catch (e, stackTrace) {
     print('[Server] ⚠️  WARNING: Could not mount Video API routes');
     print('[Server] Error: $e');
     print('[Server] Please ensure video_routes.dart and createVideoRoutes() are implemented correctly');
  }

  // Mount Comment routes
  try {
    final commentRouter = createCommentRoutes(); 
    appRouter.mount('/api/comments', commentRouter);
    print("[Server] ✅ Comment API routes mounted at '/api/comments'");
  } catch (e, stackTrace) {
     print('[Server] ⚠️  WARNING: Could not mount Comment API routes');
     print('[Server] Error: $e');
     print('[Server] Comment routes are optional. Continuing without them...');
  }

  // Mount Notification routes
  try {
    final notificationRouter = createNotificationRoutes(); 
    appRouter.mount('/api/notifications', notificationRouter);
    print("[Server] ✅ Notification API routes mounted at '/api/notifications'");
  } catch (e, stackTrace) {
     print('[Server] ⚠️  WARNING: Could not mount Notification API routes');
     print('[Server] Error: $e');
     print('[Server] Notification routes are optional. Continuing without them...');
  }
  

  // --- BUILD REQUEST PROCESSING PIPELINE ---
  final handler = const Pipeline()
      .addMiddleware(enhancedLoggingMiddleware())    // Enhanced logging first
      .addMiddleware(corsMiddleware())               // CORS handling
      .addHandler(appRouter);                       // Main router

  // --- START SERVER WITH FIXED PORT ---
  const int serverPort = 8080;  // CỨNG CỐ ĐỊNH PORT 8080
  const String serverHost = 'localhost';  // Có thể thay bằng '0.0.0.0' để accept từ mọi interface

  try {
    // Try to start server on fixed port
    final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, serverPort);
    
    print('');
    print('🎉 =====================================');
    print('🚀 TikTok Backend Server STARTED!');
    print('🎉 =====================================');
    print('📍 Host: ${server.address.address}');
    print('🔌 Port: ${server.port}');
    print('🌐 Server URL: http://$serverHost:${server.port}');
    print('');
    print('📊 Available Endpoints:');
    print('   • API Info: http://$serverHost:${server.port}/');
    print('   • Health Check: http://$serverHost:${server.port}/health');
    print('   • User Login: http://$serverHost:${server.port}/api/users/login');
    print('   • Video Feed: http://$serverHost:${server.port}/api/videos/feed');
    print('   • Video Debug: http://$serverHost:${server.port}/api/videos/debug/info');
    print('   • Comments Debug: http://$serverHost:${server.port}/api/comments/debug/info');
    print('   • Notifications Debug: http://$serverHost:${server.port}/api/notifications/debug/info');
    print('   • Static Files: http://$serverHost:${server.port}/uploads/');
    print('');
    print('✅ Server is ready to accept connections...');
    print('💡 Frontend should connect to: http://$serverHost:${server.port}');
    print('🛑 Press Ctrl+C to stop the server');
    print('=====================================');
    print('');

    // Graceful shutdown handling
    ProcessSignal.sigint.watch().listen((signal) async {
      print('\n[Server] 🛑 Received shutdown signal (SIGINT)');
      print('[Server] 🔄 Shutting down gracefully...');
      
      try {
        await server.close();
        print('[Server] ✅ HTTP server stopped');
        
        await DatabaseService.close();
        print('[Server] ✅ Database connection closed');
        
        print('[Server] 👋 Server shutdown completed successfully');
        exit(0);
      } catch (e) {
        print('[Server] ❌ Error during shutdown: $e');
        exit(1);
      }
    });

  } catch (e) {
    print('');
    print('[Server] ❌ FATAL: Failed to start server on port $serverPort');
    print('[Server] Error: $e');
    
    if (e.toString().contains('Address already in use') || 
        e.toString().contains('bind failed')) {
      print('');
      print('[Server] 💡 Port $serverPort is already in use!');
      print('[Server] Solutions:');
      print('   1. Stop any other server running on port $serverPort');
      print('   2. Find and kill the process:');
      print('      • macOS/Linux: lsof -ti:$serverPort | xargs kill -9');
      print('      • Windows: netstat -ano | findstr :$serverPort');
      print('   3. Then restart this server');
      print('');
    }
    
    try {
      await DatabaseService.close();
    } catch (_) {}
    
    exit(1);
  }
}

// Import required for jsonEncode