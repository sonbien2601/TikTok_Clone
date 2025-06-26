// tiktok_backend/test/follow_system_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Simple test script for follow system
Future<void> main() async {
  const baseUrl = 'http://localhost:8080/api';
  
  print('🧪 Testing Follow System...\n');
  
  // Test 1: Health check
  await testHealthCheck(baseUrl);
  
  // Test 2: Follow routes debug
  await testFollowRoutesDebug(baseUrl);
  
  // Test 3: Test follow API connection
  await testFollowApiConnection(baseUrl);
  
  print('\n✅ All tests completed!');
}

Future<void> testHealthCheck(String baseUrl) async {
  print('1. Testing health check...');
  try {
    final response = await http.get(Uri.parse('$baseUrl/../health'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('   ✅ Server is healthy: ${data['status']}');
    } else {
      print('   ❌ Health check failed: ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ Health check error: $e');
  }
}

Future<void> testFollowRoutesDebug(String baseUrl) async {
  print('\n2. Testing follow routes debug...');
  try {
    final response = await http.get(Uri.parse('$baseUrl/follow/debug/routes'));
    if (response.statusCode == 200) {
      print('   ✅ Follow routes are registered');
      print('   📋 Available routes:');
      final lines = response.body.split('\n');
      for (var line in lines.take(10)) {
        if (line.trim().isNotEmpty) {
          print('      $line');
        }
      }
    } else {
      print('   ❌ Follow routes debug failed: ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ Follow routes debug error: $e');
  }
}

Future<void> testFollowApiConnection(String baseUrl) async {
  print('\n3. Testing follow API connection...');
  try {
    final response = await http.get(Uri.parse('$baseUrl/follow/test-follow-api'));
    if (response.statusCode == 200) {
      print('   ✅ Follow API is working: ${response.body}');
    } else {
      print('   ❌ Follow API test failed: ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ Follow API test error: $e');
  }
}

// Example follow operations test (requires actual user IDs)
Future<void> testFollowOperations(String baseUrl, String currentUserId, String targetUserId) async {
  print('\n4. Testing follow operations...');
  
  // Test follow status check
  try {
    final statusResponse = await http.get(
      Uri.parse('$baseUrl/follow/status/$currentUserId/$targetUserId')
    );
    
    if (statusResponse.statusCode == 200) {
      final statusData = jsonDecode(statusResponse.body);
      print('   ✅ Follow status check: ${statusData['isFollowing']}');
      
      // Test follow user
      final followResponse = await http.post(
        Uri.parse('$baseUrl/follow/follow/$currentUserId/$targetUserId')
      );
      
      if (followResponse.statusCode == 200) {
        final followData = jsonDecode(followResponse.body);
        print('   ✅ Follow operation: ${followData['message']}');
        
        // Test unfollow user
        final unfollowResponse = await http.delete(
          Uri.parse('$baseUrl/follow/unfollow/$currentUserId/$targetUserId')
        );
        
        if (unfollowResponse.statusCode == 200) {
          final unfollowData = jsonDecode(unfollowResponse.body);
          print('   ✅ Unfollow operation: ${unfollowData['message']}');
        }
      }
    }
  } catch (e) {
    print('   ❌ Follow operations error: $e');
  }
}

// Run with: dart run test/follow_system_test.dart