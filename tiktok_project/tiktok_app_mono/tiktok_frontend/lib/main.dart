// tiktok_frontend/lib/main.dart - UPDATED WITH NOTIFICATION POPUP SERVICE
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/analytics/domain/services/analytics_service.dart';
import 'package:tiktok_frontend/src/features/notifications/domain/services/notification_service.dart'; // NEW IMPORT
import 'package:tiktok_frontend/src/features/notifications/domain/services/notification_popup_service.dart'; // NEW IMPORT
import 'package:tiktok_frontend/src/core/services/http_service.dart';
import 'package:tiktok_frontend/src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize HTTP service for analytics
  HttpService().initialize();
  
  print('🚀 TikTok Clone App Starting...');
  print('🔔 Notification services initializing...');
  
  runApp(
    MultiProvider(
      providers: [
        // HTTP Service Provider
        Provider<HttpService>(
          create: (_) {
            print('📡 HTTP Service created');
            return HttpService();
          },
          dispose: (_, service) => service.dispose(),
        ),
        
        // NEW: Notification Service Provider
        Provider<NotificationService>(
          create: (_) {
            print('🔔 Notification Service created');
            return NotificationService();
          },
        ),
        
        // NEW: Notification Popup Service Provider  
        Provider<NotificationPopupService>(
          create: (_) {
            print('🔔 Notification Popup Service created');
            return NotificationPopupService();
          },
          dispose: (_, service) {
            print('🔔 Notification Popup Service disposed');
            service.dispose();
          },
        ),
        
        // Auth Service Provider (updated to work with notification popup)
        ChangeNotifierProvider(
          create: (context) {
            print('🔐 Auth Service created');
            return AuthService();
          },
        ),
        
        // Analytics Service Provider
        ChangeNotifierProvider<AnalyticsService>(
          create: (_) {
            print('📊 Analytics Service created');
            return AnalyticsService();
          },
        ),
      ],
      child: const App(),
    ),
  );
  
  print('✅ TikTok Clone App started successfully');
}