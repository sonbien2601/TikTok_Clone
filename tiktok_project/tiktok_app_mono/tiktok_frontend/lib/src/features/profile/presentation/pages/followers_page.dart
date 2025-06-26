// tiktok_frontend/lib/src/features/profile/presentation/pages/followers_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/follow/domain/models/follow_model.dart';
import 'package:tiktok_frontend/src/features/follow/domain/services/follow_service.dart';
import 'package:tiktok_frontend/src/features/follow/presentation/widgets/follow_button_widget.dart';

class FollowersPage extends StatefulWidget {
  final String userId;
  final String username;

  const FollowersPage({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> {
  final FollowService _followService = FollowService();
  final ScrollController _scrollController = ScrollController();
  
  List<FollowUser> _followers = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  
  // Pagination
  int _currentPage = 1;
  bool _hasNextPage = false;
  bool _isLoadingMore = false;
  int _totalFollowers = 0;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
    
    // Listen for scroll to load more followers
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
        _loadMoreFollowers();
      }
    }
  }

  Future<void> _loadFollowers() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final response = await _followService.getFollowers(
        widget.userId,
        page: 1,
        limit: 20,
      );
      
      if (mounted) {
        setState(() {
          _followers = response.users;
          _currentPage = response.pagination.currentPage;
          _hasNextPage = response.pagination.hasNextPage;
          _totalFollowers = response.pagination.totalCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[FollowersPage] Error loading followers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadMoreFollowers() async {
    if (_isLoadingMore || !_hasNextPage) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _followService.getFollowers(
        widget.userId,
        page: _currentPage + 1,
        limit: 20,
      );
      
      if (mounted) {
        setState(() {
          _followers.addAll(response.users);
          _currentPage = response.pagination.currentPage;
          _hasNextPage = response.pagination.hasNextPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('[FollowersPage] Error loading more followers: $e');
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

  Future<void> _refreshFollowers() async {
    setState(() {
      _currentPage = 1;
      _followers.clear();
    });
    
    await _loadFollowers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Người theo dõi'),
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
          if (_totalFollowers > 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatCount(_totalFollowers),
                    style: TextStyle(
                      color: Colors.blue.shade700,
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
        onRefresh: _refreshFollowers,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _followers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_hasError && _followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Lỗi khi tải danh sách người theo dõi',
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
              onPressed: _loadFollowers,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    
    if (_followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Chưa có người theo dõi',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '@${widget.username} chưa có người theo dõi nào',
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
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  '${_followers.length} người theo dõi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                if (_totalFollowers > _followers.length) ...[
                  Text(
                    ' / $_totalFollowers',
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
        
        // Followers list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == _followers.length) {
                // Loading more indicator
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              final follower = _followers[index];
              return _buildFollowerItem(follower);
            },
            childCount: _followers.length + (_isLoadingMore ? 1 : 0),
          ),
        ),
        
        // Bottom spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  Widget _buildFollowerItem(FollowUser follower) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isCurrentUser = currentUser?.id == follower.id;

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
                    Colors.blue.shade300,
                    Colors.purple.shade300,
                  ],
                ),
              ),
              child: follower.avatarUrl != null && follower.avatarUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        follower.avatarUrl!,
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
                  Text(
                    follower.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${follower.formattedFollowersCount} người theo dõi',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      if (follower.hasInterests) ...[
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
                        Text(
                          follower.interests.first,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (follower.genderDisplay.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      follower.genderDisplay,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Follow button (don't show for current user)
            if (!isCurrentUser) ...[
              const SizedBox(width: 12),
              FollowButtonWidget(
                targetUserId: follower.id,
                targetUsername: follower.username,
                initialIsFollowing: false, // We'll need to check this via API
                initialFollowerCount: follower.followersCount,
                style: FollowButtonStyle.compact,
                onFollowChanged: () {
                  // Optionally refresh the list or update local state
                },
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