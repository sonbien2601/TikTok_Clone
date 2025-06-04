// tiktok_frontend/lib/src/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.pink,
      scaffoldBackgroundColor: Colors.white,
      brightness: Brightness.light,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black87),
        bodyMedium: TextStyle(color: Colors.black54),
        titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: Colors.pink,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 5,
      ),
      // Bạn có thể thêm các thuộc tính theme khác ở đây
    );
  }

  static ThemeData get darkTheme {
    // TODO: Định nghĩa Dark Theme nếu bạn muốn hỗ trợ
    return ThemeData(
      primarySwatch: Colors.pink,
      scaffoldBackgroundColor: Colors.grey[900],
      brightness: Brightness.dark,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[850],
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white70),
        bodyMedium: TextStyle(color: Colors.white54),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: Colors.pinkAccent,
        unselectedItemColor: Colors.grey[400],
        backgroundColor: Colors.grey[850],
        elevation: 5,
      ),
    );
  }
}