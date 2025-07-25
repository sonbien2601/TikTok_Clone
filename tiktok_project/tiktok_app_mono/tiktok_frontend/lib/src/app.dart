// tiktok_frontend/lib/src/app.dart - UPDATED WITH NOTIFICATION POPUP INTEGRATION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/auth/presentation/pages/login_page.dart';
import 'package:tiktok_frontend/src/core/navigation/main_tab_page.dart';
import 'package:tiktok_frontend/src/core/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize notification popup service after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotificationServices();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final authService = Provider.of<AuthService>(context, listen: false);
    
    switch (state) {
      case AppLifecycleState.resumed:
        print('[App] 🟢 App resumed');
        if (authService.isAuthenticated && authService.currentUser != null) {
          // Check for new notifications when app is resumed
          _checkNotificationsOnResume();
        }
        break;
      case AppLifecycleState.paused:
        print('[App] 🟡 App paused');
        break;
      case AppLifecycleState.detached:
        print('[App] 🔴 App detached');
        break;
      case AppLifecycleState.inactive:
        print('[App] ⚪ App inactive');
        break;
      case AppLifecycleState.hidden:
        print('[App] ⚫ App hidden');
        break;
    }
  }

  // NEW: Initialize notification services
  void _initializeNotificationServices() {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (authService.isAuthenticated && authService.currentUser != null) {
      print('[App] 🔔 Initializing notification services for logged in user');
      authService.initializeNotificationPopup(context);
    }
  }

  // NEW: Check notifications when app is resumed
  void _checkNotificationsOnResume() {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (authService.isAuthenticated && authService.currentUser != null) {
      print('[App] 🔔 Checking notifications on app resume');
      
      // Small delay to let UI settle
      Future.delayed(const Duration(milliseconds: 500), () {
        authService.notificationPopupService.checkNotificationsOnLogin(
          authService.currentUser!.id
        ).catchError((e) {
          print('[App] ❌ Error checking notifications on resume: $e');
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(390, 844), // iPhone 12/13/14 Pro Max, phù hợp cho mobile hiện đại
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'TikTok Clone',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: Consumer<AuthService>(
            builder: (context, authService, child) {
              print('[App] Building with auth state: ${authService.isAuthenticated}');
              
              if (authService.isAuthenticated && authService.currentUser != null) {
                print('[App] ✅ User authenticated: ${authService.currentUser!.username}');
                
                // Initialize notification popup service when user is authenticated
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    authService.initializeNotificationPopup(context);
                    print('[App] 🔔 Notification popup service initialized');
                  }
                });
                
                return const MainTabPage();
              } else {
                print('[App] 🔐 User not authenticated, showing login page');
                return const LoginPage();
              }
            },
          ),
          
          // Global navigation observer for notification popup service
          navigatorObservers: [
            _NotificationNavigatorObserver(),
          ],
        );
      },
    );
  }
}

// NEW: Navigator observer to handle notification popup service context updates
class _NotificationNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateNotificationContext();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _updateNotificationContext();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _updateNotificationContext();
  }

  void _updateNotificationContext() {
    // Update notification popup service context when navigation changes
    if (navigator?.context != null) {
      final context = navigator!.context;
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (authService.isAuthenticated && authService.currentUser != null) {
        // Update context for notification popup service
        authService.initializeNotificationPopup(context);
      }
    }
  }
}