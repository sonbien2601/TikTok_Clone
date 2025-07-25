// tiktok_frontend/lib/src/core/providers/app_providers.dart - UPDATED WITH NOTIFICATION POPUP SERVICE
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/analytics/domain/services/analytics_service.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/notifications/domain/services/notification_service.dart'; // NEW IMPORT
import 'package:tiktok_frontend/src/features/notifications/domain/services/notification_popup_service.dart'; // NEW IMPORT
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
        
        // NEW: Notification Service
        Provider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        
        // NEW: Notification Popup Service
        Provider<NotificationPopupService>(
          create: (_) => NotificationPopupService(),
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
      print('🔔 Notification services ready');
      // ApiConfig.printConfig(); // Uncomment when you have ApiConfig
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}