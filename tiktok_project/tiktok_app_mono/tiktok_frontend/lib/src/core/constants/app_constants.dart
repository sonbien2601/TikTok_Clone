// tiktok_frontend/lib/src/core/constants/app_constants.dart
class AppConstants {
  // App Information
  static const String appName = 'TikTok Clone';
  static const String appVersion = '1.2.0';
  
  // API Constants
  static const String apiVersion = 'v1';
  
  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String settingsKey = 'app_settings';
  static const String analyticsKey = 'analytics_data';
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  static const double defaultRadius = 8.0;
  static const double smallRadius = 4.0;
  static const double largeRadius = 16.0;
  
  // Video Constants
  static const Duration maxVideoDuration = Duration(minutes: 3);
  static const Duration minVideoDuration = Duration(seconds: 3);
  
  // Analytics Constants
  static const Duration viewTrackingCooldown = Duration(seconds: 5);
  static const Duration minViewDuration = Duration(seconds: 1);
  static const int batchUploadSize = 10;
  
  // Error Messages
  static const String networkError = 'Network connection failed. Please try again.';
  static const String serverError = 'Server error occurred. Please try again later.';
  static const String unauthorizedError = 'You are not authorized. Please login again.';
  static const String videoUploadError = 'Failed to upload video. Please try again.';
  static const String analyticsError = 'Failed to track analytics. Continuing silently.';
  
  // Success Messages
  static const String videoUploadSuccess = 'Video uploaded successfully!';
  static const String likeSuccess = 'Video liked!';
  static const String followSuccess = 'User followed!';
  static const String commentSuccess = 'Comment posted!';
  
  // Validation Constants
  static const int maxUsernameLength = 30;
  static const int minUsernameLength = 3;
  static const int maxDescriptionLength = 500;
  static const int maxCommentLength = 200;
  static const int maxBioLength = 150;
  
  // Regular Expressions
  static const String emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String usernameRegex = r'^[a-zA-Z0-9_]{3,30}$';
  static const String phoneRegex = r'^\+?[\d\s\-\(\)]{10,}$';
  
  // Default Values
  static const String defaultAvatarUrl = '';
  static const String defaultUsername = 'user';
  static const String defaultBio = '';
  
  // Feature Flags
  static const bool enableAnalytics = true;
  static const bool enablePushNotifications = true;
  static const bool enableVideoFilters = true;
  static const bool enableLiveStreaming = false;
  
  // Social Features
  static const int maxFollowingPerDay = 100;
  static const int maxLikesPerDay = 500;
  static const int maxCommentsPerDay = 200;
  static const int maxVideosPerDay = 10;
}