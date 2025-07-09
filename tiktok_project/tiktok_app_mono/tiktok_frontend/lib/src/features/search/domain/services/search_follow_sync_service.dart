// tiktok_frontend/lib/src/features/search/domain/services/search_follow_sync_service.dart
import 'package:flutter/foundation.dart';
import 'package:tiktok_frontend/src/features/follow/domain/services/follow_service.dart';
import 'package:tiktok_frontend/src/features/follow/domain/services/follow_state_manager.dart';
import 'package:tiktok_frontend/src/features/follow/domain/models/follow_model.dart';

class SearchFollowSyncService {
  static final SearchFollowSyncService _instance = SearchFollowSyncService._internal();
  factory SearchFollowSyncService() => _instance;
  SearchFollowSyncService._internal();

  final FollowService _followService = FollowService();
  final FollowStateManager _followStateManager = FollowStateManager();

  // Sync follow states for a list of users from search results
  Future<void> syncFollowStatesForUsers(List<Map<String, dynamic>> users, String? currentUserId) async {
    if (currentUserId == null || users.isEmpty) return;

    try {
      print('[SearchFollowSyncService] Syncing follow states for ${users.length} users');
      
      // Group users that need follow status check
      final usersToCheck = <String>[];
      final userMap = <String, Map<String, dynamic>>{};
      
      for (final user in users) {
        final userId = user['id'] as String?;
        if (userId != null && userId != currentUserId) {
          // Check if we already have recent data
          final followInfo = _followStateManager.getFollowInfo(userId);
          if (!followInfo['hasData'] || !_followStateManager.hasRecentUpdate(userId)) {
            usersToCheck.add(userId);
            userMap[userId] = user;
          } else {
            // Use cached data
            user['isFollowing'] = followInfo['isFollowing'];
            user['followersCount'] = followInfo['followerCount'];
          }
        }
      }

      if (usersToCheck.isEmpty) {
        print('[SearchFollowSyncService] All users have recent follow state data');
        return;
      }

      // Batch check follow statuses
      await _batchCheckFollowStatuses(usersToCheck, userMap, currentUserId);
      
    } catch (e) {
      print('[SearchFollowSyncService] Error syncing follow states: $e');
    }
  }

  // Batch check follow statuses to reduce API calls
  Future<void> _batchCheckFollowStatuses(
    List<String> userIds, 
    Map<String, Map<String, dynamic>> userMap, 
    String currentUserId
  ) async {
    const int batchSize = 5; // Process in batches to avoid overwhelming the API
    
    for (int i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();
      
      // Process batch concurrently
      final futures = batch.map((userId) => _checkSingleFollowStatus(userId, currentUserId, userMap[userId]!));
      
      try {
        await Future.wait(futures);
      } catch (e) {
        print('[SearchFollowSyncService] Error in batch $i: $e');
      }
      
      // Small delay between batches to be API-friendly
      if (i + batchSize < userIds.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  // Check follow status for a single user
  Future<void> _checkSingleFollowStatus(String userId, String currentUserId, Map<String, dynamic> userMap) async {
    try {
      final status = await _followService.checkFollowStatus(currentUserId, userId);
      
      // Update user map
      userMap['isFollowing'] = status.isFollowing;
      userMap['followersCount'] = status.targetUser.followersCount;
      
      // Update FollowStateManager
      _followStateManager.updateFollowState(
        userId: userId,
        isFollowing: status.isFollowing,
        followerCount: status.targetUser.followersCount,
      );
      
      print('[SearchFollowSyncService] ✅ Synced follow status for user $userId: following=${status.isFollowing}');
      
    } catch (e) {
      print('[SearchFollowSyncService] ❌ Failed to check follow status for user $userId: $e');
      // Keep existing data if API call fails
    }
  }

  // Optimistic update for immediate UI feedback
  void optimisticFollowUpdate(String userId, bool willFollow, Map<String, dynamic> userMap) {
    final currentFollowing = userMap['isFollowing'] as bool? ?? false;
    final currentFollowerCount = userMap['followersCount'] as int? ?? 0;
    
    // Update user map optimistically
    userMap['isFollowing'] = willFollow;
    userMap['followersCount'] = currentFollowerCount + (willFollow ? 1 : -1);
    
    // Update FollowStateManager optimistically
    _followStateManager.updateFollowState(
      userId: userId,
      isFollowing: willFollow,
      followerCount: currentFollowerCount + (willFollow ? 1 : -1),
    );
    
    print('[SearchFollowSyncService] 🔄 Optimistic update for user $userId: following=$willFollow');
  }

  // Revert optimistic update if API call fails
  void revertOptimisticUpdate(String userId, bool originalFollowing, int originalFollowerCount, Map<String, dynamic> userMap) {
    userMap['isFollowing'] = originalFollowing;
    userMap['followersCount'] = originalFollowerCount;
    
    _followStateManager.updateFollowState(
      userId: userId,
      isFollowing: originalFollowing,
      followerCount: originalFollowerCount,
    );
    
    print('[SearchFollowSyncService] ↩️ Reverted optimistic update for user $userId');
  }

  // Perform follow/unfollow action with proper state management
  Future<bool> performFollowAction(
    String currentUserId,
    String targetUserId,
    String targetUsername,
    bool currentlyFollowing,
    Map<String, dynamic> userMap,
  ) async {
    // Store original values for potential revert
    final originalFollowing = currentlyFollowing;
    final originalFollowerCount = userMap['followersCount'] as int? ?? 0;
    
    try {
      // Optimistic update
      optimisticFollowUpdate(targetUserId, !currentlyFollowing, userMap);
      
      // Perform API call
      FollowResult result;
      if (currentlyFollowing) {
        result = await _followService.unfollowUser(currentUserId, targetUserId);
      } else {
        result = await _followService.followUser(currentUserId, targetUserId);
      }
      
      // Update with actual API response
      userMap['isFollowing'] = result.isFollowing;
      userMap['followersCount'] = result.followerCount;
      
      _followStateManager.updateFollowState(
        userId: targetUserId,
        isFollowing: result.isFollowing,
        followerCount: result.followerCount,
      );
      
      print('[SearchFollowSyncService] ✅ Follow action completed for $targetUsername: ${result.message}');
      return true;
      
    } catch (e) {
      print('[SearchFollowSyncService] ❌ Follow action failed: $e');
      
      // Revert optimistic update
      revertOptimisticUpdate(targetUserId, originalFollowing, originalFollowerCount, userMap);
      
      return false;
    }
  }

  // Listen to FollowStateManager changes and update search results
  void subscribeToFollowStateChanges(VoidCallback onUpdate) {
    _followStateManager.addListener(onUpdate);
  }

  void unsubscribeFromFollowStateChanges(VoidCallback onUpdate) {
    _followStateManager.removeListener(onUpdate);
  }

  // Get current follow info for a user
  Map<String, dynamic> getFollowInfo(String userId) {
    return _followStateManager.getFollowInfo(userId);
  }

  // Initialize follow states from user data
  void initializeFollowStates(List<Map<String, dynamic>> users) {
    final updates = <String, Map<String, dynamic>>{};
    
    for (final user in users) {
      final userId = user['id'] as String?;
      if (userId != null) {
        updates[userId] = {
          'isFollowing': user['isFollowing'] ?? false,
          'followerCount': user['followersCount'] ?? 0,
        };
      }
    }
    
    if (updates.isNotEmpty) {
      _followStateManager.updateMultipleFollowStates(updates);
      print('[SearchFollowSyncService] Initialized follow states for ${updates.length} users');
    }
  }

  // Clear all cached follow states (useful for logout)
  void clearAllFollowStates() {
    _followStateManager.clearAll();
    print('[SearchFollowSyncService] Cleared all follow states');
  }
}