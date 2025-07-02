// tiktok_frontend/lib/src/features/follow/domain/services/follow_state_manager.dart
import 'package:flutter/foundation.dart';

// Cập nhật AuthService để sử dụng FollowStateManager
// Thêm vào auth_service.dart:

class FollowStateUpdate {
  final String userId;
  final bool isFollowing;
  final int followerCount;
  final DateTime timestamp;

  FollowStateUpdate({
    required this.userId,
    required this.isFollowing,
    required this.followerCount,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'FollowStateUpdate(userId: $userId, isFollowing: $isFollowing, followerCount: $followerCount)';
  }
}

class FollowStateManager extends ChangeNotifier {
  static final FollowStateManager _instance = FollowStateManager._internal();
  factory FollowStateManager() => _instance;
  FollowStateManager._internal();

  // Map để lưu trạng thái follow của từng user
  final Map<String, bool> _followStates = {};
  final Map<String, int> _followerCounts = {};

  // Stream để broadcast các thay đổi follow state
  final Map<String, FollowStateUpdate> _recentUpdates = {};

  // Getters
  bool isFollowing(String userId) => _followStates[userId] ?? false;
  int getFollowerCount(String userId) => _followerCounts[userId] ?? 0;

  // Cập nhật trạng thái follow cho một user
  void updateFollowState({
    required String userId,
    required bool isFollowing,
    required int followerCount,
  }) {
    print('[FollowStateManager] Updating follow state for $userId: following=$isFollowing, followers=$followerCount');
    
    final oldFollowing = _followStates[userId];
    final oldFollowerCount = _followerCounts[userId];
    
    // Chỉ cập nhật nếu có thay đổi
    if (oldFollowing != isFollowing || oldFollowerCount != followerCount) {
      _followStates[userId] = isFollowing;
      _followerCounts[userId] = followerCount;
      
      // Tạo update event
      final update = FollowStateUpdate(
        userId: userId,
        isFollowing: isFollowing,
        followerCount: followerCount,
        timestamp: DateTime.now(),
      );
      
      _recentUpdates[userId] = update;
      
      print('[FollowStateManager] Broadcasting follow state change: $update');
      
      // Notify tất cả listeners
      notifyListeners();
      
      // Cleanup old updates after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        _recentUpdates.remove(userId);
      });
    }
  }

  // Lấy thông tin follow state cho một user
  Map<String, dynamic> getFollowInfo(String userId) {
    return {
      'isFollowing': isFollowing(userId),
      'followerCount': getFollowerCount(userId),
      'hasData': _followStates.containsKey(userId),
    };
  }

  // Bulk update cho nhiều users
  void updateMultipleFollowStates(Map<String, Map<String, dynamic>> updates) {
    bool hasChanges = false;
    
    for (final entry in updates.entries) {
      final userId = entry.key;
      final data = entry.value;
      final isFollowing = data['isFollowing'] as bool? ?? false;
      final followerCount = data['followerCount'] as int? ?? 0;
      
      final oldFollowing = _followStates[userId];
      final oldFollowerCount = _followerCounts[userId];
      
      if (oldFollowing != isFollowing || oldFollowerCount != followerCount) {
        _followStates[userId] = isFollowing;
        _followerCounts[userId] = followerCount;
        hasChanges = true;
        
        // Tạo update event
        final update = FollowStateUpdate(
          userId: userId,
          isFollowing: isFollowing,
          followerCount: followerCount,
          timestamp: DateTime.now(),
        );
        
        _recentUpdates[userId] = update;
      }
    }
    
    if (hasChanges) {
      print('[FollowStateManager] Broadcasting bulk follow state changes');
      notifyListeners();
    }
  }

  // Initialize follow states from a list of users
  void initializeFromUserList(List<Map<String, dynamic>> users) {
    for (final user in users) {
      final userId = user['id'] as String?;
      final followerCount = user['followersCount'] as int? ?? 0;
      
      if (userId != null && !_followerCounts.containsKey(userId)) {
        _followerCounts[userId] = followerCount;
        // Không set isFollowing ở đây vì chúng ta chưa biết current user có follow họ không
      }
    }
  }

  // Clear all follow states (useful for logout)
  void clearAll() {
    print('[FollowStateManager] Clearing all follow states');
    _followStates.clear();
    _followerCounts.clear();
    _recentUpdates.clear();
    notifyListeners();
  }

  // Get recent updates for debugging
  List<FollowStateUpdate> getRecentUpdates() {
    return _recentUpdates.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Check if we have recent update for a user
  bool hasRecentUpdate(String userId) {
    final update = _recentUpdates[userId];
    if (update == null) return false;
    
    final now = DateTime.now();
    return now.difference(update.timestamp).inSeconds < 5; // 5 seconds threshold
  }

  @override
  void dispose() {
    _followStates.clear();
    _followerCounts.clear();
    _recentUpdates.clear();
    super.dispose();
  }
}