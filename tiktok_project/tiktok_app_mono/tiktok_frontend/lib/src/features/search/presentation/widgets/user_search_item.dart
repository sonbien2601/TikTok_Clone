// tiktok_frontend/lib/src/features/search/presentation/widgets/user_search_item.dart
import 'package:flutter/material.dart';
import 'package:tiktok_frontend/src/features/search/domain/models/search_model.dart';

class UserSearchItem extends StatefulWidget {
  final SearchUser user;
  final VoidCallback? onTap;
  final VoidCallback? onFollowTap;
  final bool showTrendingBadge;
  final int? trendingRank;
  final bool showRecentActivity;

  const UserSearchItem({
    super.key,
    required this.user,
    this.onTap,
    this.onFollowTap,
    this.showTrendingBadge = false,
    this.trendingRank,
    this.showRecentActivity = false,
  });

  @override
  State<UserSearchItem> createState() => _UserSearchItemState();
}

class _UserSearchItemState extends State<UserSearchItem> {
  bool _isFollowLoading = false;

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildTrendingBadge() {
    if (!widget.showTrendingBadge || widget.trendingRank == null) {
      return const SizedBox.shrink();
    }

    Color badgeColor;
    IconData badgeIcon;
    
    switch (widget.trendingRank!) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            '#${widget.trendingRank}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (!widget.showRecentActivity || widget.user.recentActivity == null) {
      return const SizedBox.shrink();
    }

    final activity = widget.user.recentActivity!;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.whatshot,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${activity.recentVideos} videos, ${_formatCount(activity.recentViews)} views this ${activity.timeframe}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // User Avatar with trending badge overlay
                  Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.showTrendingBadge 
                                ? Theme.of(context).primaryColor.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: widget.user.avatarUrl != null
                              ? Image.network(
                                  widget.user.avatarUrl!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.grey[600],
                                  ),
                                ),
                        ),
                      ),
                      
                      // Trending score badge
                      if (widget.user.trendingScore != null && widget.user.trendingScore! > 0)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.local_fire_department,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.user.displayName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.user.isVerified)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.verified,
                                  size: 18,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '@${widget.user.username}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        
                        if (widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.user.bio!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        
                        const SizedBox(height: 8),
                        
                        // Stats row
                        Row(
                          children: [
                            _buildStatItem(
                              icon: Icons.people,
                              count: widget.user.followersCount,
                              label: 'Followers',
                            ),
                            const SizedBox(width: 16),
                            _buildStatItem(
                              icon: Icons.video_library,
                              count: widget.user.videosCount,
                              label: 'Videos',
                            ),
                            const Spacer(),
                            _buildTrendingBadge(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Follow Button
                  if (widget.onFollowTap != null)
                    SizedBox(
                      width: 80,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: _isFollowLoading ? null : () async {
                          setState(() {
                            _isFollowLoading = true;
                          });
                          
                          try {
                            widget.onFollowTap?.call();
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isFollowLoading = false;
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.user.isFollowing == true
                              ? Colors.grey[300]
                              : Theme.of(context).primaryColor,
                          foregroundColor: widget.user.isFollowing == true
                              ? Colors.grey[700]
                              : Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isFollowLoading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    widget.user.isFollowing == true
                                        ? Colors.grey[700]!
                                        : Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                widget.user.isFollowing == true ? 'Following' : 'Follow',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
              
              // Recent Activity (if enabled)
              _buildRecentActivity(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}