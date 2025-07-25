// tiktok_frontend/lib/main.dart - UPDATED WITH NOTIFICATION POPUP SERVICE
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/analytics/domain/services/analytics_service.dart';
import 'package:tiktok_frontend/src/features/notifications/domain/services/notification_service.dart'; // NEW IMPORT
import 'package:tiktok_frontend/src/features/notifications/domain/services/notification_popup_service.dart'; // NEW IMPORT
import 'package:tiktok_frontend/src/core/services/http_service.dart';
import 'package:tiktok_frontend/src/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Đảm bảo dòng này KHÔNG bị comment
import 'package:tiktok_frontend/src/core/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // BẮT BUỘC phải có dòng này!
  );
  runApp(
    MultiProvider(
      providers: [
        // HTTP Service Provider
        Provider<HttpService>(
          create: (_) {
            return HttpService();
          },
          dispose: (_, service) => service.dispose(),
        ),
        
        // NEW: Notification Service Provider
        Provider<NotificationService>(
          create: (_) {
            return NotificationService();
          },
        ),
        
        // NEW: Notification Popup Service Provider  
        Provider<NotificationPopupService>(
          create: (_) {
            return NotificationPopupService();
          },
          dispose: (_, service) {
            service.dispose();
          },
        ),
        
        // Auth Service Provider (updated to work with notification popup)
        ChangeNotifierProvider(
          create: (context) {
            return AuthService();
          },
        ),
        
        // Analytics Service Provider
        ChangeNotifierProvider<AnalyticsService>(
          create: (_) {
            return AnalyticsService();
          },
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const App(),
    ),
  );
  
}