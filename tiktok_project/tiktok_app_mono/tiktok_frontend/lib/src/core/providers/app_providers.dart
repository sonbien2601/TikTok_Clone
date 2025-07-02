// tiktok_frontend/lib/src/core/providers/app_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/analytics/domain/services/analytics_service.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/core/services/http_service.dart';

class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core Services
        Provider<HttpService>(
          create: (_) => HttpService(),
          dispose: (_, service) => service.dispose(),
        ),
        
        // Auth Service
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        
        // Analytics Service
        ChangeNotifierProvider<AnalyticsService>(
          create: (_) => AnalyticsService(),
        ),
        
        // Add more providers here as needed
        // ChangeNotifierProvider<VideoService>(
        //   create: (_) => VideoService(),
        // ),
        // ChangeNotifierProvider<CommentService>(
        //   create: (_) => CommentService(),
        // ),
      ],
      child: child,
    );
  }
}

// Helper class to initialize services
class AppInitializer {
  static Future<void> initializeServices() async {
    // Initialize HTTP Service
    HttpService().initialize();
    
    // Print configuration in debug mode
    if (kDebugMode) {
      print('🚀 App services initialized');
      // ApiConfig.printConfig(); // Uncomment when you have ApiConfig
    }
  }
}