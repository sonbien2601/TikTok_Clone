// tiktok_frontend/lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:tiktok_frontend/src/app.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Quan trọng cho SharedPreferences
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthService(), // AuthService sẽ tự gọi _loadAuthState trong constructor của nó
      child: const App(),
    ),
  );
}