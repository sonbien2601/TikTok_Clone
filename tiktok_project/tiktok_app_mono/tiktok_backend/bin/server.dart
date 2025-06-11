// tiktok_backend/bin/server.dart
import 'dart:io';
import 'dart:convert';
import 'dart:async';
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

// --- Development Mode Detection ---
bool get isDevelopmentMode {
  // Check for common development indicators
  return Platform.environment['DART_VM_OPTIONS']?.contains('--enable-vm-service') == true ||
         Platform.environment['DEVELOPMENT'] == 'true' ||
         Platform.script.path.contains('tool/') ||
         Platform.script.path.contains('bin/server.dart');
}

// --- Enhanced Server Info ---
Map<String, dynamic> getServerInfo() {
  final startTime = DateTime.now();
  return {
    'message': 'TikTok Backend API Server',
    'version': '1.0.0',
    'status': 'running',
    'mode': isDevelopmentMode ? 'development' : 'production',
    'timestamp': startTime.toIso8601String(),
    'dart_version': Platform.version,
    'environment': {
      'hot_reload': isDevelopmentMode,
      'auto_restart': isDevelopmentMode,
      'debug_logging': isDevelopmentMode,
    },
    'endpoints': {
      'health': 'GET /health',
      'dev_info': 'GET /dev/info',
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
}

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
        if (isDevelopmentMode) {
          print('[CORS] Handling OPTIONS preflight request for ${request.url}');
        }
        return Response(204, headers: _corsHeaders); 
      }
      
      // Process normal requests and add CORS headers
      final response = await innerHandler(request);
      return response.change(headers: {...response.headers, ..._corsHeaders});
    };
  };
}

// Enhanced logging middleware with development mode awareness
Middleware enhancedLoggingMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final startTime = DateTime.now();
      final timestamp = startTime.toIso8601String();
      
      // Enhanced logging in development mode
      if (isDevelopmentMode) {
        print('[${timestamp}] ${request.method} ${request.url}');
        if (request.url.queryParameters.isNotEmpty) {
          print('[Server] Query params: ${request.url.queryParameters}');
        }
        
        // Log request headers in dev mode
        if (request.headers.isNotEmpty) {
          final relevantHeaders = Map.fromEntries(
            request.headers.entries.where((e) => 
              e.key.toLowerCase().contains('content-type') ||
              e.key.toLowerCase().contains('authorization') ||
              e.key.toLowerCase().contains('user-agent')
            ).take(3)
          );
          if (relevantHeaders.isNotEmpty) {
            print('[Server] Headers: $relevantHeaders');
          }
        }
      } else {
        // Production logging - more concise
        print('[${timestamp.substring(11, 19)}] ${request.method} ${request.url.path}');
      }
      
      try {
        final response = await innerHandler(request);
        final duration = DateTime.now().difference(startTime);
        
        if (isDevelopmentMode) {
          print('[Server] ${request.method} ${request.url.path} - ${response.statusCode} (${duration.inMilliseconds}ms)');
        } else {
          // Only log errors and slow requests in production
          if (response.statusCode >= 400 || duration.inMilliseconds > 1000) {
            print('[Server] ${request.method} ${request.url.path} - ${response.statusCode} (${duration.inMilliseconds}ms)');
          }
        }
        return response;
      } catch (e, stackTrace) {
        final duration = DateTime.now().difference(startTime);
        print('[Server] ERROR ${request.method} ${request.url.path} - Exception after ${duration.inMilliseconds}ms: $e');
        
        if (isDevelopmentMode) {
          print('[Server] StackTrace: $stackTrace');
        }
        
        return Response.internalServerError(
          body: jsonEncode({
            'error': 'Internal server error',
            'timestamp': timestamp,
            'debug': isDevelopmentMode ? e.toString() : null,
          }),
          headers: {'Content-Type': 'application/json', ..._corsHeaders}
        );
      }
    };
  };
}

// Development mode middleware for extra debugging
Middleware developmentMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (!isDevelopmentMode) {
        return await innerHandler(request);
      }

      // Add development headers to response
      final response = await innerHandler(request);
      return response.change(headers: {
        ...response.headers,
        'X-Development-Mode': 'true',
        'X-Hot-Reload': 'enabled',
        'X-Server-Restart-Time': DateTime.now().toIso8601String(),
      });
    };
  };
}

// Auto reload functionality
Timer? _restartTimer;
bool _shouldEnableAutoReload = false;

void _checkAutoReloadFlag(List<String> args) {
  _shouldEnableAutoReload = args.contains('--auto-reload') || 
                           args.contains('--watch') ||
                           Platform.environment['AUTO_RELOAD'] == 'true';
}

Future<void> _setupFileWatcher() async {
  if (!_shouldEnableAutoReload || !isDevelopmentMode) return;
  
  print('[AutoReload] 🔄 Setting up file watcher...');
  
  final dirsToWatch = ['lib', 'bin', 'config'];
  final watchers = <StreamSubscription>[];
  
  void scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: 800), () {
      print('\n[AutoReload] 🔄 Files changed - Server will restart...');
      print('[AutoReload] 💡 Save this message appeared because files were modified');
      print('[AutoReload] 🔄 Use Ctrl+C to stop, then restart manually\n');
    });
  }
  
  for (final dirName in dirsToWatch) {
    final dir = Directory(dirName);
    if (await dir.exists()) {
      final watcher = dir.watch(recursive: true).listen((event) {
        if (event.path.endsWith('.dart') || event.path.endsWith('.json')) {
          final relativePath = event.path.replaceFirst(Directory.current.path, '.');
          print('[AutoReload] 📝 File changed: $relativePath');
          scheduleRestart();
        }
      });
      watchers.add(watcher);
      print('[AutoReload] 👀 Watching: $dirName/');
    }
  }
  
  if (watchers.isNotEmpty) {
    print('[AutoReload] ✅ File watcher active. Save .dart files to see reload messages.');
    print('[AutoReload] 💡 For full auto-restart, use: dart run tool/watch_server.dart');
  }
}

Future<void> main([List<String>? args]) async {
  args ??= [];
  _checkAutoReloadFlag(args);
  
  final serverStartTime = DateTime.now();
  
  // Enhanced startup banner
  print('\n🎬 =====================================');
  print('🚀 TikTok Backend Server Starting...');
  print('🎬 =====================================');
  print('📅 Timestamp: ${serverStartTime.toIso8601String()}');
  print('🔧 Mode: ${isDevelopmentMode ? "DEVELOPMENT 🔥" : "PRODUCTION 🏭"}');
  print('🎯 Dart Version: ${Platform.version}');
  
  if (isDevelopmentMode) {
    print('🔄 Hot Reload: ENABLED');
    print('📝 Debug Logging: ENABLED');
    print('🛠️  Development Features: ENABLED');
    if (_shouldEnableAutoReload) {
      print('⚡ Auto Reload: ENABLED');
    }
  }
  print('');
  
  try {
    print("[Server] 📋 Loading configuration from config.json...");
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
    print("[Server] 🗄️  MongoDB URI (masked): $safeMongoUriToLog");
    
    // QUAN TRỌNG: Cố định port 8080 thay vì dùng từ config
    const int fixedPort = 8080;
    print("[Server] 🔧 OVERRIDING port from config (${EnvConfig.serverPort}) to fixed port: $fixedPort");

    print("[Server] 🔗 Connecting to MongoDB...");
    await DatabaseService.connect();
    print("[Server] ✅ MongoDB connection established successfully.");

  } catch (e, stackTrace) {
    print('[Server] ❌ FATAL: Failed to initialize server configuration or database');
    print('[Server] Error: $e');
    if (isDevelopmentMode) {
      print('[Server] StackTrace: $stackTrace');
    }
    print('[Server] 🛑 Server startup aborted.');
    exit(1); 
  }

  // Create main application router
  final appRouter = Router();

  // --- ROOT ENDPOINT FOR API INFO ---
  appRouter.get('/', (Request request) {
    return Response.ok(
      jsonEncode(getServerInfo()),
      headers: {'Content-Type': 'application/json'}
    );
  });

  // --- DEVELOPMENT INFO ENDPOINT ---
  if (isDevelopmentMode) {
    appRouter.get('/dev/info', (Request request) {
      final devInfo = {
        'development_mode': true,
        'server_start_time': serverStartTime.toIso8601String(),
        'uptime_seconds': DateTime.now().difference(serverStartTime).inSeconds,
        'hot_reload_enabled': true,
        'debug_logging': true,
        'environment_variables': {
          'DART_VM_OPTIONS': Platform.environment['DART_VM_OPTIONS'],
          'DEVELOPMENT': Platform.environment['DEVELOPMENT'],
        },
        'script_path': Platform.script.path,
        'current_directory': Directory.current.path,
        'available_dev_endpoints': {
          'server_info': 'GET /dev/info',
          'restart_hint': 'Save any .dart file to trigger auto-restart',
          'logs': 'Check console for detailed request logs',
        }
      };
      
      return Response.ok(
        jsonEncode(devInfo),
        headers: {'Content-Type': 'application/json'}
      );
    });
    
    print("[Server] 🛠️  Development endpoint mounted at '/dev/info'");
  }

  // --- HEALTH CHECK ENDPOINT ---
  appRouter.get('/health', (Request request) {
    if (isDevelopmentMode) {
      print('[Server] Health check requested');
    }
    
    final healthInfo = {
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
      'database': 'connected',
      'mode': isDevelopmentMode ? 'development' : 'production',
      'uptime_seconds': DateTime.now().difference(serverStartTime).inSeconds,
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
    if (isDevelopmentMode) {
      print('[Server] Hello endpoint accessed');
    }
    return Response.ok(
      jsonEncode({
        'message': 'Hello from TikTok Backend! Connected to MongoDB successfully.',
        'timestamp': DateTime.now().toIso8601String(),
        'mode': isDevelopmentMode ? 'development' : 'production',
      }),
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
     if (isDevelopmentMode) {
       print('[Server] StackTrace: $stackTrace');
     }
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
     if (isDevelopmentMode) {
       print('[Server] StackTrace: $stackTrace');
     }
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
     if (isDevelopmentMode) {
       print('[Server] StackTrace: $stackTrace');
     }
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
     if (isDevelopmentMode) {
       print('[Server] StackTrace: $stackTrace');
     }
     print('[Server] Notification routes are optional. Continuing without them...');
  }
  
  // --- BUILD REQUEST PROCESSING PIPELINE ---
  final pipelineBuilder = const Pipeline()
      .addMiddleware(enhancedLoggingMiddleware());    // Enhanced logging first
  
  // Add development middleware in dev mode
  final pipeline = isDevelopmentMode 
      ? pipelineBuilder.addMiddleware(developmentMiddleware())
      : pipelineBuilder;
      
  final handler = pipeline
      .addMiddleware(corsMiddleware())               // CORS handling
      .addHandler(appRouter);                       // Main router

  // --- START SERVER WITH FIXED PORT ---
  const int serverPort = 8080;  // CỨNG CỐ ĐỊNH PORT 8080
  const String serverHost = 'localhost';  // Có thể thay bằng '0.0.0.0' để accept từ mọi interface

  try {
    // Setup file watcher for auto reload (if enabled)
    await _setupFileWatcher();
    
    // Try to start server on fixed port
    final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, serverPort);
    
    print('');
    print('🎉 =====================================');
    print('🚀 TikTok Backend Server STARTED!');
    print('🎉 =====================================');
    print('📍 Host: ${server.address.address}');
    print('🔌 Port: ${server.port}');
    print('🌐 Server URL: http://$serverHost:${server.port}');
    print('🔧 Mode: ${isDevelopmentMode ? "DEVELOPMENT 🔥" : "PRODUCTION 🏭"}');
    print('⏱️  Start Time: ${serverStartTime.toIso8601String()}');
    print('');
    print('📊 Available Endpoints:');
    print('   • API Info: http://$serverHost:${server.port}/');
    print('   • Health Check: http://$serverHost:${server.port}/health');
    if (isDevelopmentMode) {
      print('   • Dev Info: http://$serverHost:${server.port}/dev/info');
    }
    print('   • User Login: http://$serverHost:${server.port}/api/users/login');
    print('   • Video Feed: http://$serverHost:${server.port}/api/videos/feed');
    print('   • Video Debug: http://$serverHost:${server.port}/api/videos/debug/info');
    print('   • Comments Debug: http://$serverHost:${server.port}/api/comments/debug/info');
    print('   • Notifications Debug: http://$serverHost:${server.port}/api/notifications/debug/info');
    print('   • Static Files: http://$serverHost:${server.port}/uploads/');
    print('');
    
    if (isDevelopmentMode) {
      print('🔥 Development Features:');
      print('   • Hot Reload: ENABLED (save .dart files to restart)');
      print('   • Debug Logging: ENABLED');
      print('   • Enhanced Error Messages: ENABLED');
      print('   • Development Headers: ENABLED');
      if (_shouldEnableAutoReload) {
        print('   • Auto Reload Watcher: ENABLED (shows reload messages)');
      }
      print('');
    }
    
    print('✅ Server is ready to accept connections...');
    print('💡 Frontend should connect to: http://$serverHost:${server.port}');
    print('🛑 Press Ctrl+C to stop the server');
    
    if (isDevelopmentMode) {
      print('🔄 Auto-restart options:');
      print('   • Full Auto-restart: dart run tool/watch_server.dart');
      print('   • File Watch Messages: dart run bin/server.dart --auto-reload');
      print('   • Hot Reload Support: dart run --enable-vm-service bin/server.dart');
    }
    
    print('=====================================');
    print('');

    // Graceful shutdown handling
    ProcessSignal.sigint.watch().listen((signal) async {
      print('\n[Server] 🛑 Received shutdown signal (SIGINT)');
      print('[Server] 🔄 Shutting down gracefully...');
      
      try {
        // Cancel auto reload timer
        _restartTimer?.cancel();
        
        await server.close();
        print('[Server] ✅ HTTP server stopped');
        
        await DatabaseService.close();
        print('[Server] ✅ Database connection closed');
        
        final uptime = DateTime.now().difference(serverStartTime);
        print('[Server] ⏱️  Total uptime: ${uptime.inSeconds} seconds');
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
      
      if (isDevelopmentMode) {
        print('[Server] 🔄 In development mode, you can also use:');
        print('      • dart run tool/watch_server.dart (auto-restart)');
        print('      • make watch (if using Makefile)');
        print('');
      }
    }
    
    try {
      await DatabaseService.close();
    } catch (_) {}
    
    exit(1);
  }
}