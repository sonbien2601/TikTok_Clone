// tiktok_frontend/lib/main.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/analytics/domain/services/analytics_service.dart';
import 'package:tiktok_frontend/src/core/services/http_service.dart';
import 'package:tiktok_frontend/src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize HTTP service for analytics
  HttpService().initialize();
  
  runApp(
    MultiProvider(
      providers: [
        // HTTP Service Provider
        Provider<HttpService>(
          create: (_) => HttpService(),
          dispose: (_, service) => service.dispose(),
        ),
        
        // Auth Service Provider (giữ nguyên)
        ChangeNotifierProvider(
          create: (context) => AuthService(),
        ),
        
        // Analytics Service Provider (thêm mới)
        ChangeNotifierProvider<AnalyticsService>(
          create: (_) => AnalyticsService(),
        ),
      ],
      child: const App(),
    ),
  );
}