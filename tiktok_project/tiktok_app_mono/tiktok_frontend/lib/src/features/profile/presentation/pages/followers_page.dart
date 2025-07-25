
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

class _FollowersPageState extends State<FollowersPage> with TickerProviderStateMixin {
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

    _loadFollowers();
    
    // Listen for scroll to load more followers
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
        
        // Start list animation after data loads
        _listController.forward();
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
        
        _showSnackBar('Lỗi khi tải thêm: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _refreshFollowers() async {
    setState(() {
      _currentPage = 1;
      _followers.clear();
    });
    
    // Reset animations
    _listController.reset();
    await _loadFollowers();
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
        borderRadius: BorderRadius.circular(16),
        color: color ?? const Color(0xFF1F1F1F).withValues(alpha: 0.8),
        border: Border.all(
          color: Colors.grey[700]!.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
              ).createShader(bounds),
              child: const Text(
                'Người theo dõi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              '@${widget.username}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _formatCount(_totalFollowers),
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
            onRefresh: _refreshFollowers,
            backgroundColor: const Color(0xFF1F1F1F),
            color: const Color(0xFFFF0000),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _followers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: const Color(0xFFFF0000),
          strokeWidth: 3,
        ),
      );
    }
    
    if (_hasError && _followers.isEmpty) {
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
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withValues(alpha: 0.3),
                      Colors.red.withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
              ),
              const SizedBox(height: 24),
              Text(
                'Lỗi khi tải danh sách người theo dõi',
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
                  borderRadius: BorderRadius.circular(25),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loadFollowers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
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
    
    if (_followers.isEmpty) {
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
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF0000).withValues(alpha: 0.3),
                      const Color(0xFFFF0000).withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.people_outline, 
                    size: 64, 
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                ).createShader(bounds),
                child: const Text(
                  'Chưa có người theo dõi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '@${widget.username} chưa có người theo dõi nào',
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.people, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_followers.length} người theo dõi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[300],
                        ),
                      ),
                      if (_totalFollowers > _followers.length)
                        Text(
                          'Tổng cộng: $_totalFollowers',
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
                      color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.3),
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
        
        // Followers list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == _followers.length) {
                // Loading more indicator
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFFFF0000),
                      strokeWidth: 3,
                    ),
                  ),
                );
              }
              
              final follower = _followers[index];
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
                      child: _buildFollowerItem(follower, index),
                    ),
                  );
                },
              );
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

  Widget _buildFollowerItem(FollowUser follower, int index) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isCurrentUser = currentUser?.id == follower.id;

    return _buildGlassMorphicContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Avatar with gradient border
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.3),
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
                child: follower.avatarUrl != null && follower.avatarUrl!.isNotEmpty
                    ? Image.network(
                        follower.avatarUrl!,
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
                Text(
                  follower.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.grey[200],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF0000).withValues(alpha: 0.3),
                            const Color(0xFFFF0000).withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${follower.formattedFollowersCount} người theo dõi',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (follower.hasInterests) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF0000).withValues(alpha: 0.3),
                                const Color(0xFFFF0000).withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            follower.interests.first,
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
                if (follower.genderDisplay.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    follower.genderDisplay,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Follow button (don't show for current user)
          if (!isCurrentUser) ...[
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FollowButtonWidget(
                targetUserId: follower.id,
                targetUsername: follower.username,
                initialIsFollowing: false, // We'll need to check this via API
                initialFollowerCount: follower.followersCount,
                style: FollowButtonStyle.compact,
                onFollowChanged: () {
                  // Optionally refresh the list or update local state
                },
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