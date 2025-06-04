// tiktok_frontend/lib/src/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/core/navigation/main_tab_page.dart';
import 'package:tiktok_frontend/src/core/theme/app_theme.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/auth/presentation/pages/login_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        print('[App Widget] Rebuilding. IsAuthenticated: ${authService.isAuthenticated}, CurrentUser: ${authService.currentUser}'); // Thêm currentUser vào log
        
        return MaterialApp(
          title: 'TikTok Clone',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: authService.isAuthenticated && authService.currentUser != null // Thêm kiểm tra currentUser != null
              ? const MainTabPage() 
              : const LoginPage(),
        );
      },
    );
  }
}