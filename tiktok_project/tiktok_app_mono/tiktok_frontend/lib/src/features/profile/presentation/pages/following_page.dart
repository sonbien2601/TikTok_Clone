// tiktok_frontend/lib/src/features/profile/presentation/pages/following_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/follow/domain/models/follow_model.dart';
import 'package:tiktok_frontend/src/features/follow/domain/services/follow_service.dart';
import 'package:tiktok_frontend/src/features/follow/presentation/widgets/follow_button_widget.dart';

class FollowingPage extends StatefulWidget {
  final String userId;
  final String username;

  const FollowingPage({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  final FollowService _followService = FollowService();
  final ScrollController _scrollController = ScrollController();
  
  List<FollowUser> _following = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  
  // Pagination
  int _currentPage = 1;
  bool _hasNextPage = false;
  bool _isLoadingMore = false;
  int _totalFollowing = 0;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
    
    // Listen for scroll to load more following
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasNextPage && !_isLoadingMore) {
        _loadMoreFollowing();
      }
    }
  }

  Future<void> _loadFollowing() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final response = await _followService.getFollowing(
        widget.userId,
        page: 1,
        limit: 20,
      );
      
      if (mounted) {
        setState(() {
          _following = response.users;
          _currentPage = response.pagination.currentPage;
          _hasNextPage = response.pagination.hasNextPage;
          _totalFollowing = response.pagination.totalCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[FollowingPage] Error loading following: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadMoreFollowing() async {
    if (_isLoadingMore || !_hasNextPage) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _followService.getFollowing(
        widget.userId,
        page: _currentPage + 1,
        limit: 20,
      );
      
      if (mounted) {
        setState(() {
          _following.addAll(response.users);
          _currentPage = response.pagination.currentPage;
          _hasNextPage = response.pagination.hasNextPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('[FollowingPage] Error loading more following: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải thêm: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshFollowing() async {
    setState(() {
      _currentPage = 1;
      _following.clear();
    });
    
    await _loadFollowing();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đang theo dõi'),
            Text(
              '@${widget.username}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_totalFollowing > 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatCount(_totalFollowing),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFollowing,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _following.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_hasError && _following.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Lỗi khi tải danh sách đang theo dõi',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (_errorMessage != null) 
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFollowing,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    
    if (_following.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Chưa theo dõi ai',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '@${widget.username} chưa theo dõi ai',
              style: TextStyle(
                color: Colors.grey.shade500, 
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Header with stats
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.person_search, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  '${_following.length} đang theo dõi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
                if (_totalFollowing > _following.length) ...[
                  Text(
                    ' / $_totalFollowing',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const Spacer(),
                if (_hasNextPage)
                  Text(
                    'Cuộn để xem thêm',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Following list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == _following.length) {
                // Loading more indicator
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              final followingUser = _following[index];
              return _buildFollowingItem(followingUser);
            },
            childCount: _following.length + (_isLoadingMore ? 1 : 0),
          ),
        ),
        
        // Bottom spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  Widget _buildFollowingItem(FollowUser followingUser) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isCurrentUser = currentUser?.id == followingUser.id;
    final isCurrentUserProfile = currentUser?.id == widget.userId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade300,
                    Colors.blue.shade300,
                  ],
                ),
              ),
              child: followingUser.avatarUrl != null && followingUser.avatarUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        followingUser.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultAvatar();
                        },
                      ),
                    )
                  : _buildDefaultAvatar(),
            ),
            
            const SizedBox(width: 12),
            
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          followingUser.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      // Show "Following" indicator if this is current user's following list
                      if (isCurrentUserProfile)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Đang theo dõi',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${followingUser.formattedFollowersCount} người theo dõi',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      if (followingUser.hasInterests) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade500,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            followingUser.interests.take(2).join(', '),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (followingUser.genderDisplay.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          followingUser.gender == 'male' ? Icons.male : 
                          followingUser.gender == 'female' ? Icons.female : Icons.person,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          followingUser.genderDisplay,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Action buttons
            if (!isCurrentUser) ...[
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Follow/Unfollow button
                  if (isCurrentUserProfile) ...[
                    // Show "Unfollow" button if this is current user's following list
                    FollowButtonWidget(
                      targetUserId: followingUser.id,
                      targetUsername: followingUser.username,
                      initialIsFollowing: true, // Already following since it's in following list
                      initialFollowerCount: followingUser.followersCount,
                      style: FollowButtonStyle.compact,
                      onFollowChanged: () {
                        // Remove from list when unfollowed
                        setState(() {
                          _following.removeWhere((user) => user.id == followingUser.id);
                          _totalFollowing = (_totalFollowing - 1).clamp(0, double.infinity).toInt();
                        });
                      },
                    ),
                  ] else ...[
                    // Show regular follow button for other users' following lists
                    FollowButtonWidget(
                      targetUserId: followingUser.id,
                      targetUsername: followingUser.username,
                      initialIsFollowing: false, // We'll need to check this via API
                      initialFollowerCount: followingUser.followersCount,
                      style: FollowButtonStyle.compact,
                      onFollowChanged: () {
                        // Optionally refresh or update local state
                      },
                    ),
                  ],
                  
                  // Message button (for future implementation)
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tính năng nhắn tin sẽ được thêm sau'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Nhắn tin',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Bạn',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return const Icon(
      Icons.person,
      color: Colors.white,
      size: 30,
    );
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
  }
}