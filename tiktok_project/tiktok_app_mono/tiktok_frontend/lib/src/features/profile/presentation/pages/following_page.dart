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

class _FollowingPageState extends State<FollowingPage> with TickerProviderStateMixin {
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

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _listController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _loadFollowing();
    
    // Listen for scroll to load more following
    _scrollController.addListener(_onScroll);

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _listController.dispose();
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
        
        // Start list animation after data loads
        _listController.forward();
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
        
        _showSnackBar('Lỗi khi tải thêm: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _refreshFollowing() async {
    setState(() {
      _currentPage = 1;
      _following.clear();
    });
    
    // Reset animations
    _listController.reset();
    await _loadFollowing();
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? const Color(0xFFFF0000) : const Color(0xFF00C851),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildGlassMorphicContainer({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    Color? color,
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color ?? const Color(0xFF1F1F1F),
        border: Border.all(
          color: const Color(0xFF333333),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đang theo dõi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '@${widget.username}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF888888),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF0000).withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _formatCount(_totalFollowing),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            onRefresh: _refreshFollowing,
            backgroundColor: const Color(0xFF1F1F1F),
            color: const Color(0xFFFF0000),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _following.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF0000),
          strokeWidth: 3,
        ),
      );
    }
    
    if (_hasError && _following.isEmpty) {
      return Center(
        child: _buildGlassMorphicContainer(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                  ),
                ),
                child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
              ),
              const SizedBox(height: 24),
              Text(
                'Lỗi khi tải danh sách đang theo dõi',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.grey[500], 
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: const Color(0xFFFF0000),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loadFollowing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text(
                    'Thử lại',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_following.isEmpty) {
      return Center(
        child: _buildGlassMorphicContainer(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF0000).withOpacity(0.3),
                  ),
                ),
                child: const Icon(
                  Icons.person_search_outlined, 
                  size: 64, 
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Chưa theo dõi ai',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '@${widget.username} chưa theo dõi ai',
                style: TextStyle(
                  color: Colors.grey[400], 
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Header with stats
        SliverToBoxAdapter(
          child: _buildGlassMorphicContainer(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF0000).withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_search, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_following.length} đang theo dõi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[300],
                        ),
                      ),
                      if (_totalFollowing > _following.length)
                        Text(
                          'Tổng cộng: $_totalFollowing',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                if (_hasNextPage)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFF0000).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Cuộn để xem thêm',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
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
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF0000),
                      strokeWidth: 3,
                    ),
                  ),
                );
              }
              
              final followingUser = _following[index];
              return AnimatedBuilder(
                animation: _listController,
                builder: (context, child) {
                  final animationDelay = (index * 0.1).clamp(0.0, 1.0);
                  final animation = Tween<Offset>(
                    begin: const Offset(-1.0, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _listController,
                      curve: Interval(
                        animationDelay,
                        (animationDelay + 0.3).clamp(0.0, 1.0),
                        curve: Curves.easeOutBack,
                      ),
                    ),
                  );
                  
                  final fadeAnimation = Tween<double>(
                    begin: 0.0,
                    end: 1.0,
                  ).animate(
                    CurvedAnimation(
                      parent: _listController,
                      curve: Interval(
                        animationDelay,
                        (animationDelay + 0.5).clamp(0.0, 1.0),
                        curve: Curves.easeOut,
                      ),
                    ),
                  );
                  
                  return SlideTransition(
                    position: animation,
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: _buildFollowingItem(followingUser, index),
                    ),
                  );
                },
              );
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

  Widget _buildFollowingItem(FollowUser followingUser, int index) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isCurrentUser = currentUser?.id == followingUser.id;
    final isCurrentUserProfile = currentUser?.id == widget.userId;

    return _buildGlassMorphicContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Avatar with gradient border
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF0000),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF0000).withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1F1F1F),
              ),
              child: ClipOval(
                child: followingUser.avatarUrl != null && followingUser.avatarUrl!.isNotEmpty
                    ? Image.network(
                        followingUser.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultAvatar();
                        },
                      )
                    : _buildDefaultAvatar(),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.grey[200],
                        ),
                      ),
                    ),
                    // Show "Following" indicator if this is current user's following list
                    if (isCurrentUserProfile)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF0000).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'Đang theo dõi',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFF0000).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${followingUser.formattedFollowersCount} người theo dõi',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (followingUser.hasInterests) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFF0000).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            followingUser.interests.take(2).join(', '),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (followingUser.genderDisplay.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        followingUser.gender == 'male' ? Icons.male : 
                        followingUser.gender == 'female' ? Icons.female : Icons.person,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        followingUser.genderDisplay,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
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
            const SizedBox(width: 16),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Follow/Unfollow button
                if (isCurrentUserProfile) ...[
                  // Show "Unfollow" button if this is current user's following list
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: const Color(0xFFFF0000),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0000).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FollowButtonWidget(
                      targetUserId: followingUser.id,
                      targetUsername: followingUser.username,
                      initialIsFollowing: true,
                      initialFollowerCount: followingUser.followersCount,
                      style: FollowButtonStyle.compact,
                      onFollowChanged: () {
                        setState(() {
                          _following.removeWhere((user) => user.id == followingUser.id);
                          _totalFollowing = (_totalFollowing - 1).clamp(0, double.infinity).toInt();
                        });
                      },
                    ),
                  ),
                ] else ...[
                  // Show regular follow button for other users' following lists
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: const Color(0xFFFF0000),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0000).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FollowButtonWidget(
                      targetUserId: followingUser.id,
                      targetUsername: followingUser.username,
                      initialIsFollowing: false,
                      initialFollowerCount: followingUser.followersCount,
                      style: FollowButtonStyle.compact,
                      onFollowChanged: () {
                        // Optionally refresh or update local state
                      },
                    ),
                  ),
                ],
                
                // Message button
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF333333),
                    ),
                    color: const Color(0xFF1F1F1F),
                  ),
                  child: InkWell(
                    onTap: () {
                      _showSnackBar('Tính năng nhắn tin sẽ được thêm sau', isError: false);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Nhắn tin',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF0000).withOpacity(0.3),
                ),
              ),
              child: Text(
                'Bạn',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[300],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [const Color(0xFF404040), const Color(0xFF1F1F1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.grey,
        size: 30,
      ),
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