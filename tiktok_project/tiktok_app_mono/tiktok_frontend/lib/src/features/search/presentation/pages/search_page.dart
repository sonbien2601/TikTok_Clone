import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/follow/domain/services/follow_service.dart';
import 'package:tiktok_frontend/src/features/follow/domain/services/follow_state_manager.dart';
import 'package:tiktok_frontend/src/features/follow/presentation/widgets/follow_button_widget.dart';
import 'package:tiktok_frontend/src/core/config/network_config.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FollowService _followService = FollowService();
  late TabController _tabController;
  late FollowStateManager _followStateManager;

  bool _isSearching = false;
  bool _isLoadingTrending = false;
  List<dynamic> _userResults = [];
  List<dynamic> _videoResults = [];
  List<dynamic> _trendingUsers = [];
  String _currentQuery = '';
  String? _errorMessage;
  int _userCount = 0;
  int _videoCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _followStateManager = FollowStateManager();

    _followStateManager.addListener(_onFollowStateChanged);
    _loadTrendingUsers();
  }

  @override
  void dispose() {
    _followStateManager.removeListener(_onFollowStateChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onFollowStateChanged() {
    if (mounted) {
      setState(() {
        _updateUserFollowStates();
      });
    }
  }

  void _updateUserFollowStates() {
    for (var user in _userResults) {
      final userId = user['id'] as String?;
      if (userId != null) {
        final followInfo = _followStateManager.getFollowInfo(userId);
        if (followInfo['hasData'] == true) {
          user['isFollowing'] = followInfo['isFollowing'];
          user['followersCount'] = followInfo['followerCount'];
        }
      }
    }

    for (var user in _trendingUsers) {
      final userId = user['id'] as String?;
      if (userId != null) {
        final followInfo = _followStateManager.getFollowInfo(userId);
        if (followInfo['hasData'] == true) {
          user['isFollowing'] = followInfo['isFollowing'];
          user['followersCount'] = followInfo['followerCount'];
        }
      }
    }
  }

  Future<void> _loadTrendingUsers() async {
    setState(() {
      _isLoadingTrending = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;

      final baseUrl = await NetworkConfig.getBaseUrl('/api/search/trending');
      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          'limit': '10',
          'timeframe': '7d',
          if (currentUserId != null) 'currentUserId': currentUserId,
        },
      );

      print('[SearchPage] Loading trending users from: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _trendingUsers = data['trendingUsers'] ?? [];
            _isLoadingTrending = false;
            _errorMessage = null;
          });
          _initializeFollowStates(_trendingUsers);
        }
        print('[SearchPage] ✅ Loaded ${_trendingUsers.length} trending users');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[SearchPage] ❌ Error loading trending users: $e');
      await _loadRealUsersFromDB();
    }
  }

  Future<void> _loadRealUsersFromDB() async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final uri = Uri.parse(baseUrl);

      print('[SearchPage] Loading fallback users from: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> users = data['users'] ?? data ?? [];

        users.sort((a, b) {
          final aFollowers = a['followersCount'] ?? 0;
          final bFollowers = b['followersCount'] ?? 0;
          return bFollowers.compareTo(aFollowers);
        });

        if (mounted) {
          setState(() {
            _trendingUsers = users.take(10).toList();
            _isLoadingTrending = false;
            _errorMessage = null;
          });
          _initializeFollowStates(_trendingUsers);
        }
        print('[SearchPage] ✅ Loaded ${_trendingUsers.length} real users from DB');
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      print('[SearchPage] ❌ Error loading real users: $e');
      if (mounted) {
        setState(() {
          _isLoadingTrending = false;
          _errorMessage = 'Failed to load users. Please check your backend connection.';
        });
      }
    }
  }

  void _initializeFollowStates(List<dynamic> users) {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return;

    for (var user in users) {
      final userId = user['id'] as String?;
      final isFollowing = user['isFollowing'] as bool? ?? false;
      final followerCount = user['followersCount'] as int? ?? 0;

      if (userId != null) {
        _followStateManager.updateFollowState(
          userId: userId,
          isFollowing: isFollowing,
          followerCount: followerCount,
        );
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty || query.trim().length < 2) {
      setState(() {
        _userResults = [];
        _videoResults = [];
        _currentQuery = '';
        _userCount = 0;
        _videoCount = 0;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentQuery = query.trim();
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;

      final futures = await Future.wait([
        _searchUsers(query.trim(), currentUserId),
        _searchVideos(query.trim(), currentUserId),
      ]);

      if (mounted) {
        setState(() {
          _userResults = futures[0]['users'] ?? [];
          _videoResults = futures[1]['videos'] ?? [];
          _userCount = _userResults.length;
          _videoCount = _videoResults.length;
          _isSearching = false;
          _errorMessage = null;
        });
        _initializeFollowStates(_userResults);
      }
    } catch (e) {
      print('[SearchPage] ❌ Error performing search: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Search failed. Please try again.';
        });
      }
    }
  }

  Future<Map<String, dynamic>> _searchUsers(String query, String? currentUserId) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/search/users');
      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          'q': query,
          'page': '1',
          'limit': '20',
          if (currentUserId != null) 'currentUserId': currentUserId,
        },
      );

      print('[SearchPage] Searching users: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[SearchPage] ✅ Found ${(data['users'] as List?)?.length ?? 0} users for "$query"');
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[SearchPage] ❌ Error searching users: $e');
      return {'users': []};
    }
  }

  Future<Map<String, dynamic>> _searchVideos(String query, String? currentUserId) async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/search/videos');
      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          'q': query,
          'page': '1',
          'limit': '20',
          if (currentUserId != null) 'currentUserId': currentUserId,
        },
      );

      print('[SearchPage] Searching videos: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[SearchPage] ✅ Found ${(data['videos'] as List?)?.length ?? 0} videos for "$query"');
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[SearchPage] ❌ Error searching videos: $e');
      return {'videos': []};
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
    return '${NetworkConfig.getStatus()['cached_url'] ?? 'http://localhost:8080'}$avatarUrl';
  }

  String _getVideoUrl(String? videoUrl) {
    if (videoUrl == null || videoUrl.isEmpty) return '';
    if (videoUrl.startsWith('http')) return videoUrl;
    return '${NetworkConfig.getStatus()['cached_url'] ?? 'http://localhost:8080'}$videoUrl';
  }

  void _onFollowChanged() {
    print('[SearchPage] Follow state changed - UI will update automatically');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
          ).createShader(bounds),
          child: const Text(
            'Search & Discover',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        bottom: _currentQuery.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A).withOpacity(0.8),
                    border: Border.all(
                      color: Colors.grey[700]!.withOpacity(0.3),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFFF0050),
                    labelColor: const Color(0xFFFF0050),
                    unselectedLabelColor: Colors.grey[400],
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people, size: 16),
                            const SizedBox(width: 4),
                            Text('Users ($_userCount)'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.video_library, size: 16),
                            const SizedBox(width: 4),
                            Text('Videos ($_videoCount)'),
                          ],
                        ),
                      ),
                      const Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up, size: 16),
                            SizedBox(width: 4),
                            Text('Trending'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF2A2A2A).withOpacity(0.8),
              border: Border.all(
                color: Colors.grey[700]!.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search users, videos...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: _isSearching
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF0050),
                          ),
                        ),
                      )
                    : const Icon(Icons.search, color: Color(0xFFFF0050)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.transparent,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
              onChanged: (value) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == value && value.length >= 2) {
                    _performSearch(value);
                  } else if (value.length < 2) {
                    _performSearch('');
                  }
                });
              },
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
            ),
          ),
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF2A2A2A).withOpacity(0.8),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.1)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.grey[300], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _currentQuery.isEmpty
                ? _buildTrendingContent()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingContent() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16.0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF2A2A2A).withOpacity(0.8),
            border: Border.all(
              color: Colors.grey[700]!.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF25F4EE), Color(0xFFFF0050)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF25F4EE).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.trending_up, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                'Trending Users',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[300],
                ),
              ),
              const Spacer(),
              if (_isLoadingTrending)
                const CircularProgressIndicator(
                  color: Color(0xFFFF0050),
                  strokeWidth: 2,
                ),
            ],
          ),
        ),
        Expanded(
          child: _buildUsersList(_trendingUsers, showTrendingBadges: true),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildUsersList(_userResults),
        _buildVideosList(_videoResults),
        _buildUsersList(_trendingUsers, showTrendingBadges: true),
      ],
    );
  }

  Widget _buildUsersList(List<dynamic> users, {bool showTrendingBadges = false}) {
    if (_isSearching || _isLoadingTrending) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _currentQuery.isNotEmpty
                  ? 'No users found for "$_currentQuery"'
                  : 'No users to display',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (_currentQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Try different keywords',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _currentQuery.isEmpty
          ? _loadTrendingUsers
          : () => _performSearch(_currentQuery),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final isTopUser = showTrendingBadges && index < 3;
          final avatarUrl = _getAvatarUrl(user['avatarUrl']);
          final userId = user['id'] as String?;

          if (userId == null) return const SizedBox.shrink();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF2A2A2A).withOpacity(0.8),
              border: Border.all(
                color: isTopUser
                    ? const Color(0xFFFF0050).withOpacity(0.3)
                    : Colors.grey[700]!.withOpacity(0.3),
                width: isTopUser ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isTopUser
                      ? const Color(0xFFFF0050).withOpacity(0.2)
                      : Colors.black.withOpacity(0.3),
                  blurRadius: isTopUser ? 20 : 15,
                  offset: Offset(0, isTopUser ? 8 : 5),
                ),
              ],
            ),
            child: ListTile(
              leading: Container(
                decoration: isTopUser
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF0050), Color(0xFF25F4EE)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF0050).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      )
                    : null,
                padding: isTopUser ? const EdgeInsets.all(3) : null,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF404040),
                      backgroundImage:
                          avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty
                          ? Text(
                              (user['username']?[0] ?? '?').toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    if (isTopUser)
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: index == 0
                                ? Colors.amber
                                : index == 1
                                    ? Colors.grey[400]
                                    : Colors.brown[300],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      user['displayName'] ?? user['username'] ?? 'Unknown User',
                      style: TextStyle(
                        fontWeight:
                            isTopUser ? FontWeight.bold : FontWeight.w600,
                        color: Colors.grey[200],
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (user['isVerified'] == true) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: const Color(0xFFFF0050),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${user['username'] ?? 'unknown'}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF25F4EE).withOpacity(0.3),
                              const Color(0xFF25F4EE).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people,
                                size: 12, color: Color(0xFF25F4EE)),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatCount(user['followersCount'] ?? 0)} followers',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (user['videosCount'] != null &&
                          user['videosCount'] > 0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF0050).withOpacity(0.3),
                                const Color(0xFFFF0050).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.video_library,
                                  size: 12, color: Color(0xFFFF0050)),
                              const SizedBox(width: 4),
                              Text(
                                '${user['videosCount']} videos',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isTopUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF0050).withOpacity(0.3),
                                const Color(0xFF25F4EE).withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Trending',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[200],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              trailing: SizedBox(
                width: 90,
                height: 36,
                child: FollowButtonWidget(
                  targetUserId: userId,
                  targetUsername: user['username'] ?? 'user',
                  initialIsFollowing: user['isFollowing'] == true,
                  initialFollowerCount: user['followersCount'] ?? 0,
                  style: FollowButtonStyle.compact,
                  onFollowChanged: _onFollowChanged,
                  fontSize: 11,
                ),
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('View profile: @${user['username']}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideosList(List<dynamic> videos) {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching videos...'),
          ],
        ),
      );
    }

    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No videos found for "$_currentQuery"',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching with different keywords',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        final videoUrl = _getVideoUrl(video['videoUrl']);
        final thumbnailUrl = _getVideoUrl(video['thumbnailUrl']);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF2A2A2A).withOpacity(0.8),
            border: Border.all(
              color: Colors.grey[700]!.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Play video: ${video['description'] ?? 'Untitled'}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        image: thumbnailUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(thumbnailUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          if (thumbnailUrl.isEmpty)
                            const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          const Center(
                            child: Icon(
                              Icons.play_circle_filled,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.play_arrow,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    _formatCount(video['viewsCount'] ?? 0),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video['description'] ?? 'No description',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: const Color(0xFFFF0050),
                              child: Text(
                                (video['user']?['username']?[0] ?? '?').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '@${video['user']?['username'] ?? 'unknown'}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[400],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.favorite, size: 12, color: Colors.red),
                            const SizedBox(width: 2),
                            Text(
                              _formatCount(video['likesCount'] ?? 0),
                              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.comment, size: 12, color: Colors.blue),
                            const SizedBox(width: 2),
                            Text(
                              _formatCount(video['commentsCount'] ?? 0),
                              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}