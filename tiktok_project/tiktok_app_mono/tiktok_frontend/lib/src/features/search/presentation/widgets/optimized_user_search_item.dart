// tiktok_frontend/lib/src/features/search/presentation/widgets/optimized_user_search_item.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/follow/presentation/widgets/follow_button_widget.dart';
import 'package:tiktok_frontend/src/features/follow/domain/services/follow_state_manager.dart';
import 'package:tiktok_frontend/src/core/config/network_config.dart';

class OptimizedUserSearchItem extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onTap;
  final bool showTrendingBadge;
  final int? trendingRank;
  final bool showRecentActivity;
  final VoidCallback? onFollowChanged;

  const OptimizedUserSearchItem({
    super.key,
    required this.user,
    this.onTap,
    this.showTrendingBadge = false,
    this.trendingRank,
    this.showRecentActivity = false,
    this.onFollowChanged,
  });

  @override
  State<OptimizedUserSearchItem> createState() => _OptimizedUserSearchItemState();
}

class _OptimizedUserSearchItemState extends State<OptimizedUserSearchItem> {
  late FollowStateManager _followStateManager;

  @override
  void initState() {
    super.initState();
    _followStateManager = FollowStateManager();
    _followStateManager.addListener(_onFollowStateChanged);
  }

  @override
  void dispose() {
    _followStateManager.removeListener(_onFollowStateChanged);
    super.dispose();
  }

  void _onFollowStateChanged() {
    if (mounted) {
      final userId = widget.user['id'] as String?;
      if (userId != null) {
        final followInfo = _followStateManager.getFollowInfo(userId);
        if (followInfo['hasData'] == true) {
          setState(() {
            widget.user['isFollowing'] = followInfo['isFollowing'];
            widget.user['followersCount'] = followInfo['followerCount'];
          });
          widget.onFollowChanged?.call();
        }
      }
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _getAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return '';
    if (avatarUrl.startsWith('http')) return avatarUrl;
    
    // Use NetworkConfig for file URLs
    final status = NetworkConfig.getStatus();
    final cachedUrl = status['cached_url'] ?? 'http://localhost:8080';
    return '$cachedUrl$avatarUrl';
  }

  Widget _buildTrendingBadge() {
    if (!widget.showTrendingBadge || widget.trendingRank == null) {
      return const SizedBox.shrink();
    }

    Color badgeColor;
    IconData badgeIcon;
    
    switch (widget.trendingRank!) {
      case 0:
      case 1:
        badgeColor = Colors.amber;
        badgeIcon = Icons.emoji_events;
        break;
      case 2:
        badgeColor = Colors.grey[400]!;
        badgeIcon = Icons.emoji_events;
        break;
      case 3:
        badgeColor = Colors.brown[300]!;
        badgeIcon = Icons.emoji_events;
        break;
      default:
        badgeColor = Theme.of(context).primaryColor;
        badgeIcon = Icons.trending_up;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 10,
            color: badgeColor,
          ),
          const SizedBox(width: 2),
          Text(
            widget.trendingRank! < 3 ? '#${widget.trendingRank! + 1}' : 'Trending',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (!widget.showRecentActivity) return const SizedBox.shrink();
    
    final recentActivity = widget.user['recentActivity'];
    if (recentActivity == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.trending_up,
            size: 10,
            color: Colors.green,
          ),
          const SizedBox(width: 2),
          Text(
            '+${recentActivity['recentVideos'] ?? 0}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.user['id'] as String?;
    final username = widget.user['username'] as String? ?? 'unknown';
    final displayName = widget.user['displayName'] as String? ?? username;
    final avatarUrl = _getAvatarUrl(widget.user['avatarUrl'] as String?);
    final isVerified = widget.user['isVerified'] as bool? ?? false;
    final followersCount = widget.user['followersCount'] as int? ?? 0;
    final videosCount = widget.user['videosCount'] as int? ?? 0;
    final bio = widget.user['bio'] as String?;
    final isFollowing = widget.user['isFollowing'] as bool? ?? false;
    final isTopUser = widget.showTrendingBadge && (widget.trendingRank ?? 999) < 3;

    if (userId == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isTopUser ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar with trending indicator
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isTopUser 
                            ? Theme.of(context).primaryColor.withOpacity(0.4)
                            : Colors.grey.withOpacity(0.3),
                        width: isTopUser ? 2 : 1,
                      ),
                    ),
                    child: ClipOval(
                      child: avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 50,
                                height: 50,
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                child: Icon(
                                  Icons.person,
                                  size: 24,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                size: 24,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                    ),
                  ),
                  
                  // Trending rank badge
                  if (isTopUser)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: widget.trendingRank == 0 ? Colors.amber : 
                                 widget.trendingRank == 1 ? Colors.grey[400] : Colors.brown[300],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 12),
              
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and verification
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isTopUser ? FontWeight.bold : FontWeight.w600,
                              color: isTopUser ? Theme.of(context).primaryColor : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ],
                      ],
                    ),
                    
                    // Username
                    Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    // Bio (if available)
                    if (bio != null && bio.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        bio,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    const SizedBox(height: 4),
                    
                    // Stats and badges row
                    Row(
                      children: [
                        // Followers count
                        Icon(Icons.people, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 2),
                        Text(
                          _formatCount(followersCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        
                        // Videos count (if available)
                        if (videosCount > 0) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.video_library, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 2),
                          Text(
                            '$videosCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        
                        const SizedBox(width: 8),
                        
                        // Trending badge
                        _buildTrendingBadge(),
                        
                        // Recent activity
                        _buildRecentActivity(),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Follow Button
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  // Don't show follow button for self
                  if (authService.currentUser?.id == userId) {
                    return Container(
                      width: 80,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'You',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }
                  
                  return SizedBox(
                    width: 80,
                    height: 32,
                    child: FollowButtonWidget(
                      targetUserId: userId,
                      targetUsername: username,
                      initialIsFollowing: isFollowing,
                      initialFollowerCount: followersCount,
                      style: FollowButtonStyle.compact,
                      onFollowChanged: () {
                        widget.onFollowChanged?.call();
                      },
                      fontSize: 11,
                      padding: EdgeInsets.zero,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}