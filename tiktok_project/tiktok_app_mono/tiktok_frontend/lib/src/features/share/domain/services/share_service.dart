// File: tiktok_project/tiktok_app_mono/tiktok_frontend/lib/src/features/share/domain/services/share_service.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:url_launcher/url_launcher.dart';

enum ShareMethod {
  whatsapp('whatsapp', 'WhatsApp'),
  facebook('facebook', 'Facebook'),
  instagram('instagram', 'Instagram'),
  twitter('twitter', 'Twitter'),
  copyLink('copy_link', 'Copy Link'),
  sms('sms', 'SMS'),
  email('email', 'Email'),
  native('native', 'Share'),
  other('other', 'Other');

  const ShareMethod(this.value, this.displayName);
  final String value;
  final String displayName;
}

class ShareResponse {
  final bool success;
  final String message;
  final ShareMethod method;
  final int newSharesCount;

  ShareResponse({
    required this.success,
    required this.message,
    required this.method,
    required this.newSharesCount,
  });

  factory ShareResponse.fromJson(Map<String, dynamic> json, ShareMethod method) {
    return ShareResponse(
      success: true,
      message: json['message'] as String? ?? 'Video shared successfully',
      method: method,
      newSharesCount: json['sharesCount'] as int? ?? 0,
    );
  }
}

class ShareService {
  static const String _appName = 'TikTok Clone';
  // Updated to use ngrok URL for testing
  static const String _baseShareUrl = 'https://d46e-2a09-bac5-d46a-25cd-00-3c4-4e.ngrok-free.app/video';
  static const String _apiBaseUrl = 'https://d46e-2a09-bac5-d46a-25cd-00-3c4-4e.ngrok-free.app';

  // Track share on backend
  Future<ShareResponse> trackVideoShare({
    required String videoId,
    required ShareMethod method,
    String? userId,
    String? customText,
  }) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/videos');
      final url = Uri.parse('$baseUrl/$videoId/share');
      
      debugPrint('[ShareService] Tracking share: videoId=$videoId, method=${method.value}');
      
      final requestBody = {
        'shareMethod': method.value,
        'userId': userId ?? '',
        'shareText': customText ?? '',
      };
      
      debugPrint('[ShareService] Request body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      debugPrint('[ShareService] Track Share Response Status: ${response.statusCode}');
      debugPrint('[ShareService] Track Share Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return ShareResponse.fromJson(responseData, method);
      } else {
        final errorMessage = 'Failed to track share. Status: ${response.statusCode}';
        debugPrint('[ShareService] $errorMessage, Body: ${response.body}');
        
        String detailedError = errorMessage;
        try {
          final errorData = jsonDecode(response.body);
          detailedError = errorData['error'] ?? errorMessage;
        } catch (e) {
          // If can't parse error, use original message
        }
        
        return ShareResponse(
          success: false,
          message: detailedError,
          method: method,
          newSharesCount: 0,
        );
      }
    } catch (e) {
      debugPrint('[ShareService] Error tracking share: $e');
      return ShareResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
        method: method,
        newSharesCount: 0,
      );
    }
  }

  // Get share URL for video
  String getShareUrl(String videoId) {
    return '$_baseShareUrl/$videoId';
  }

  // Get embeddable video URL
  String getEmbedUrl(String videoId) {
    return '$_baseShareUrl/$videoId/player';
  }

  // Get API URL for video data
  String getApiUrl(String videoId) {
    return '$_apiBaseUrl/api/public/video/$videoId';
  }

  // Generate share text with better formatting
  String generateShareText({
    required String videoTitle,
    required String username,
    required String videoId,
    String? customMessage,
  }) {
    final shareUrl = getShareUrl(videoId);
    
    if (customMessage != null && customMessage.isNotEmpty) {
      return '$customMessage\n\n🎬 "$videoTitle"\n👤 by @$username\n\n📱 Watch here: $shareUrl\n\n#TikTokClone #Viral';
    }
    
    return '🔥 Check out this amazing video by @$username!\n\n🎬 "$videoTitle"\n\n📱 Watch here: $shareUrl\n\n#TikTokClone #Viral';
  }

  // Generate platform-specific share text
  String generatePlatformShareText({
    required ShareMethod method,
    required String videoTitle,
    required String username,
    required String videoId,
    String? customMessage,
  }) {
    final shareUrl = getShareUrl(videoId);
    
    switch (method) {
      case ShareMethod.whatsapp:
        return customMessage ?? '🔥 Hey! Check out this amazing video by @$username\n\n"$videoTitle"\n\n📱 $shareUrl';
      
      case ShareMethod.facebook:
        return customMessage ?? 'Check out this incredible video by @$username on our TikTok Clone app! 🎬\n\n$shareUrl';
      
      case ShareMethod.twitter:
        final shortTitle = videoTitle.length > 50 ? '${videoTitle.substring(0, 50)}...' : videoTitle;
        return customMessage ?? '🔥 Amazing video by @$username: "$shortTitle"\n\n📱 $shareUrl\n\n#TikTokClone #Viral';
      
      case ShareMethod.email:
        return customMessage ?? '''Hi!

I wanted to share this amazing video with you:

"$videoTitle" by @$username

You can watch it here: $shareUrl

It's from our new TikTok Clone app - check it out!

Best regards''';
      
      case ShareMethod.sms:
        return customMessage ?? '🔥 Check this out: "$videoTitle" by @$username\n\n$shareUrl';
      
      default:
        return generateShareText(
          videoTitle: videoTitle,
          username: username,
          videoId: videoId,
          customMessage: customMessage,
        );
    }
  }

  // Share via native system share
  Future<ShareResponse> shareNative({
    required String videoId,
    required String videoTitle,
    required String username,
    String? userId,
    String? customMessage,
  }) async {
    try {
      final shareText = generatePlatformShareText(
        method: ShareMethod.native,
        videoTitle: videoTitle,
        username: username,
        videoId: videoId,
        customMessage: customMessage,
      );

      final result = await Share.share(shareText);
      
      ShareResponse trackResponse;
      try {
        trackResponse = await trackVideoShare(
          videoId: videoId,
          method: ShareMethod.native,
          userId: userId,
          customText: shareText,
        );
      } catch (e) {
        debugPrint('[ShareService] Error tracking native share: $e');
        trackResponse = ShareResponse(
          success: false,
          message: 'Share completed but tracking failed',
          method: ShareMethod.native,
          newSharesCount: 0,
        );
      }

      return ShareResponse(
        success: result.status == ShareResultStatus.success,
        message: result.status == ShareResultStatus.success 
            ? 'Video shared successfully!' 
            : 'Share was cancelled',
        method: ShareMethod.native,
        newSharesCount: trackResponse.newSharesCount,
      );
    } catch (e) {
      debugPrint('[ShareService] Error in native share: $e');
      return ShareResponse(
        success: false,
        message: 'Failed to share: $e',
        method: ShareMethod.native,
        newSharesCount: 0,
      );
    }
  }

  // Share via WhatsApp
  Future<ShareResponse> shareToWhatsApp({
    required String videoId,
    required String videoTitle,
    required String username,
    String? userId,
    String? customMessage,
  }) async {
    try {
      final shareText = generatePlatformShareText(
        method: ShareMethod.whatsapp,
        videoTitle: videoTitle,
        username: username,
        videoId: videoId,
        customMessage: customMessage,
      );

      final whatsappUrl = _getWhatsAppUrl(shareText);
      
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
        
        final trackResponse = await trackVideoShare(
          videoId: videoId,
          method: ShareMethod.whatsapp,
          userId: userId,
          customText: shareText,
        );

        return ShareResponse(
          success: true,
          message: 'Shared to WhatsApp!',
          method: ShareMethod.whatsapp,
          newSharesCount: trackResponse.newSharesCount,
        );
      } else {
        throw Exception('WhatsApp not installed');
      }
    } catch (e) {
      debugPrint('[ShareService] Error sharing to WhatsApp: $e');
      return ShareResponse(
        success: false,
        message: 'Failed to share to WhatsApp: $e',
        method: ShareMethod.whatsapp,
        newSharesCount: 0,
      );
    }
  }

  // Share via Facebook
  Future<ShareResponse> shareToFacebook({
    required String videoId,
    required String videoTitle,
    required String username,
    String? userId,
    String? customMessage,
  }) async {
    try {
      final shareText = generatePlatformShareText(
        method: ShareMethod.facebook,
        videoTitle: videoTitle,
        username: username,
        videoId: videoId,
        customMessage: customMessage,
      );

      final facebookUrl = _getFacebookUrl(shareText);
      
      if (await canLaunchUrl(Uri.parse(facebookUrl))) {
        await launchUrl(Uri.parse(facebookUrl), mode: LaunchMode.externalApplication);
        
        final trackResponse = await trackVideoShare(
          videoId: videoId,
          method: ShareMethod.facebook,
          userId: userId,
          customText: shareText,
        );

        return ShareResponse(
          success: true,
          message: 'Shared to Facebook!',
          method: ShareMethod.facebook,
          newSharesCount: trackResponse.newSharesCount,
        );
      } else {
        throw Exception('Facebook not available');
      }
    } catch (e) {
      debugPrint('[ShareService] Error sharing to Facebook: $e');
      return ShareResponse(
        success: false,
        message: 'Failed to share to Facebook: $e',
        method: ShareMethod.facebook,
        newSharesCount: 0,
      );
    }
  }

  // Share via Twitter
  Future<ShareResponse> shareToTwitter({
    required String videoId,
    required String videoTitle,
    required String username,
    String? userId,
    String? customMessage,
  }) async {
    try {
      final shareText = generatePlatformShareText(
        method: ShareMethod.twitter,
        videoTitle: videoTitle,
        username: username,
        videoId: videoId,
        customMessage: customMessage,
      );

      final twitterUrl = _getTwitterUrl(shareText);
      
      if (await canLaunchUrl(Uri.parse(twitterUrl))) {
        await launchUrl(Uri.parse(twitterUrl), mode: LaunchMode.externalApplication);
        
        final trackResponse = await trackVideoShare(
          videoId: videoId,
          method: ShareMethod.twitter,
          userId: userId,
          customText: shareText,
        );

        return ShareResponse(
          success: true,
          message: 'Shared to Twitter!',
          method: ShareMethod.twitter,
          newSharesCount: trackResponse.newSharesCount,
        );
      } else {
        throw Exception('Twitter not available');
      }
    } catch (e) {
      debugPrint('[ShareService] Error sharing to Twitter: $e');
      return ShareResponse(
        success: false,
        message: 'Failed to share to Twitter: $e',
        method: ShareMethod.twitter,
        newSharesCount: 0,
      );
    }
  }

  // Share via SMS
  Future<ShareResponse> shareToSMS({
    required String videoId,
    required String videoTitle,
    required String username,
    String? userId,
    String? customMessage,
  }) async {
    try {
      final shareText = generatePlatformShareText(
        method: ShareMethod.sms,
        videoTitle: videoTitle,
        username: username,
        videoId: videoId,
        customMessage: customMessage,
      );

      final smsUrl = _getSMSUrl(shareText);
      
      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
        
        final trackResponse = await trackVideoShare(
          videoId: videoId,
          method: ShareMethod.sms,
          userId: userId,
          customText: shareText,
        );

        return ShareResponse(
          success: true,
          message: 'Opened SMS app!',
          method: ShareMethod.sms,
          newSharesCount: trackResponse.newSharesCount,
        );
      } else {
        throw Exception('SMS not available');
      }
    } catch (e) {
      debugPrint('[ShareService] Error sharing to SMS: $e');
      return ShareResponse(
        success: false,
        message: 'Failed to share via SMS: $e',
        method: ShareMethod.sms,
        newSharesCount: 0,
      );
    }
  }

  // Share via Email
  Future<ShareResponse> shareToEmail({
    required String videoId,
    required String videoTitle,
    required String username,
    String? userId,
    String? customMessage,
  }) async {
    try {
      final shareText = generatePlatformShareText(
        method: ShareMethod.email,
        videoTitle: videoTitle,
        username: username,
        videoId: videoId,
        customMessage: customMessage,
      );

      final emailUrl = _getEmailUrl(shareText, videoTitle);
      
      if (await canLaunchUrl(Uri.parse(emailUrl))) {
        await launchUrl(Uri.parse(emailUrl));
        
        final trackResponse = await trackVideoShare(
          videoId: videoId,
          method: ShareMethod.email,
          userId: userId,
          customText: shareText,
        );

        return ShareResponse(
          success: true,
          message: 'Opened email app!',
          method: ShareMethod.email,
          newSharesCount: trackResponse.newSharesCount,
        );
      } else {
        throw Exception('Email not available');
      }
    } catch (e) {
      debugPrint('[ShareService] Error sharing to Email: $e');
      return ShareResponse(
        success: false,
        message: 'Failed to share via Email: $e',
        method: ShareMethod.email,
        newSharesCount: 0,
      );
    }
  }

  // Copy link to clipboard
  Future<ShareResponse> copyLink({
    required String videoId,
    String? userId,
  }) async {
    try {
      final shareUrl = getShareUrl(videoId);
      
      await Clipboard.setData(ClipboardData(text: shareUrl));
      debugPrint('[ShareService] Link copied to clipboard: $shareUrl');
      
      ShareResponse trackResponse;
      try {
        trackResponse = await trackVideoShare(
          videoId: videoId,
          method: ShareMethod.copyLink,
          userId: userId,
          customText: shareUrl,
        );
      } catch (e) {
        debugPrint('[ShareService] Error tracking copy link: $e');
        trackResponse = ShareResponse(
          success: true,
          message: 'Link copied but tracking failed',
          method: ShareMethod.copyLink,
          newSharesCount: 0,
        );
      }

      return ShareResponse(
        success: true,
        message: 'Link copied to clipboard!',
        method: ShareMethod.copyLink,
        newSharesCount: trackResponse.newSharesCount,
      );
    } catch (e) {
      debugPrint('[ShareService] Error copying link: $e');
      return ShareResponse(
        success: false,
        message: 'Failed to copy link: $e',
        method: ShareMethod.copyLink,
        newSharesCount: 0,
      );
    }
  }

  // Get share analytics for video
  Future<Map<String, dynamic>?> getShareAnalytics(String videoId) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/videos');
      final url = Uri.parse('$baseUrl/$videoId/share-analytics');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('[ShareService] Failed to get analytics: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[ShareService] Error getting share analytics: $e');
      return null;
    }
  }

  // Preview share content before sharing
  Map<String, String> getSharePreview({
    required ShareMethod method,
    required String videoTitle,
    required String username,
    required String videoId,
    String? customMessage,
  }) {
    return {
      'text': generatePlatformShareText(
        method: method,
        videoTitle: videoTitle,
        username: username,
        videoId: videoId,
        customMessage: customMessage,
      ),
      'url': getShareUrl(videoId),
      'embedUrl': getEmbedUrl(videoId),
      'apiUrl': getApiUrl(videoId),
    };
  }

  // Validate share URL
  Future<bool> validateShareUrl(String videoId) async {
    try {
      final url = getApiUrl(videoId);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      debugPrint('[ShareService] Share URL validation response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ShareService] Share URL validation failed: $e');
      return false;
    }
  }

  // Helper methods for generating URLs
  String _getWhatsAppUrl(String text) {
    final encodedText = Uri.encodeComponent(text);
    
    if (kIsWeb) {
      return 'https://web.whatsapp.com/send?text=$encodedText';
    } else {
      try {
        if (Platform.isIOS) {
          return 'whatsapp://send?text=$encodedText';
        } else {
          return 'https://api.whatsapp.com/send?text=$encodedText';
        }
      } catch (e) {
        return 'https://web.whatsapp.com/send?text=$encodedText';
      }
    }
  }

  String _getFacebookUrl(String text) {
    final encodedUrl = Uri.encodeComponent(getShareUrl(text.split('\n').last.trim()));
    return 'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl';
  }

  String _getTwitterUrl(String text) {
    final encodedText = Uri.encodeComponent(text);
    return 'https://twitter.com/intent/tweet?text=$encodedText';
  }

  String _getSMSUrl(String text) {
    final encodedText = Uri.encodeComponent(text);
    
    if (kIsWeb) {
      return '';
    }
    
    try {
      if (Platform.isIOS) {
        return 'sms:&body=$encodedText';
      } else {
        return 'sms:?body=$encodedText';
      }
    } catch (e) {
      return 'sms:?body=$encodedText';
    }
  }

  String _getEmailUrl(String text, String subject) {
    final encodedText = Uri.encodeComponent(text);
    final encodedSubject = Uri.encodeComponent('Check out this video on $_appName: $subject');
    return 'mailto:?subject=$encodedSubject&body=$encodedText';
  }

  // Check if specific share method is available
  Future<bool> isShareMethodAvailable(ShareMethod method) async {
    try {
      switch (method) {
        case ShareMethod.whatsapp:
          if (kIsWeb) return true;
          return await canLaunchUrl(Uri.parse('whatsapp://'));
        case ShareMethod.facebook:
          return await canLaunchUrl(Uri.parse('fb://')) || 
                 await canLaunchUrl(Uri.parse('https://facebook.com'));
        case ShareMethod.instagram:
          return await canLaunchUrl(Uri.parse('instagram://')) ||
                 await canLaunchUrl(Uri.parse('https://instagram.com'));
        case ShareMethod.twitter:
          return await canLaunchUrl(Uri.parse('twitter://')) ||
                 await canLaunchUrl(Uri.parse('https://twitter.com'));
        case ShareMethod.sms:
          return !kIsWeb;
        case ShareMethod.email:
          return await canLaunchUrl(Uri.parse('mailto:')) ||
                 await canLaunchUrl(Uri.parse('https://mail.google.com'));
        case ShareMethod.native:
        case ShareMethod.copyLink:
        case ShareMethod.other:
          return true;
      }
    } catch (e) {
      debugPrint('[ShareService] Error checking availability for ${method.value}: $e');
      return method == ShareMethod.copyLink || method == ShareMethod.native;
    }
  }

  // Get available share methods for current platform
  Future<List<ShareMethod>> getAvailableShareMethods() async {
    final List<ShareMethod> available = [];
    
    available.addAll([
      ShareMethod.copyLink,
      ShareMethod.native,
    ]);
    
    for (final method in ShareMethod.values) {
      if (method == ShareMethod.copyLink || method == ShareMethod.native) {
        continue;
      }
      
      try {
        if (await isShareMethodAvailable(method)) {
          available.add(method);
        }
      } catch (e) {
        debugPrint('[ShareService] Error checking method ${method.value}: $e');
      }
    }
    
    if (!available.contains(ShareMethod.copyLink)) {
      available.insert(0, ShareMethod.copyLink);
    }
    if (!available.contains(ShareMethod.native)) {
      available.insert(1, ShareMethod.native);
    }
    
    return available;
  }

  // Test connection to share API
  Future<bool> testShareConnection() async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/videos');
      final healthUrl = Uri.parse('$baseUrl/debug/info');
      
      final response = await http.get(healthUrl).timeout(const Duration(seconds: 5));
      debugPrint('[ShareService] Share API test response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ShareService] Share API test failed: $e');
      return false;
    }
  }

  // Batch share tracking
  Future<bool> trackBulkShares(List<Map<String, dynamic>> shareEvents) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/analytics');
      final url = Uri.parse('$baseUrl/track-shares-bulk');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'shares': shareEvents,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[ShareService] Bulk share tracking response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ShareService] Error in bulk share tracking: $e');
      return false;
    }
  }

  // Get popular share methods
  Future<List<ShareMethod>> getPopularShareMethods() async {
    try {
      final analytics = await getShareAnalytics('summary');
      if (analytics == null) return await getAvailableShareMethods();
      
      final breakdown = analytics['globalShareMethodBreakdown'] as Map<String, dynamic>?;
      if (breakdown == null) return await getAvailableShareMethods();
      
      final sortedMethods = breakdown.entries.toList()
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));
      
      final popularMethods = <ShareMethod>[];
      for (final entry in sortedMethods) {
        final method = ShareMethod.values.firstWhere(
          (m) => m.value == entry.key,
          orElse: () => ShareMethod.other,
        );
        if (await isShareMethodAvailable(method)) {
          popularMethods.add(method);
        }
      }
      
      return popularMethods.isNotEmpty ? popularMethods : await getAvailableShareMethods();
    } catch (e) {
      debugPrint('[ShareService] Error getting popular methods: $e');
      return await getAvailableShareMethods();
    }
  }
}
