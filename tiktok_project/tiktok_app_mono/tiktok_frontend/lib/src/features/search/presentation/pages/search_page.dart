// tiktok_frontend/lib/src/features/search/presentation/pages/search_page.dart
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

    // Listen to follow state changes
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
        // Update UI when follow states change
        _updateUserFollowStates();
      });
    }
  }

  void _updateUserFollowStates() {
    // Update user results
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

    // Update trending users
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

      // Use NetworkConfig to get proper URL
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

          // Initialize follow states
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
      // Use NetworkConfig for fallback URL too
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

          // Initialize follow states
          _initializeFollowStates(_trendingUsers);
        }
        print(
            '[SearchPage] ✅ Loaded ${_trendingUsers.length} real users from DB');
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      print('[SearchPage] ❌ Error loading real users: $e');
      if (mounted) {
        setState(() {
          _isLoadingTrending = false;
          _errorMessage =
              'Failed to load users. Please check your backend connection.';
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

      // Search both users and videos concurrently
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

        // Initialize follow states for search results
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

  Future<Map<String, dynamic>> _searchUsers(
      String query, String? currentUserId) async {
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
        print(
            '[SearchPage] ✅ Found ${(data['users'] as List?)?.length ?? 0} users for "$query"');
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[SearchPage] ❌ Error searching users: $e');
      return {'users': []};
    }
  }

  Future<Map<String, dynamic>> _searchVideos(
      String query, String? currentUserId) async {
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
        print(
            '[SearchPage] ✅ Found ${(data['videos'] as List?)?.length ?? 0} videos for "$query"');
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

    // Use NetworkConfig for file URLs too
    return '${NetworkConfig.getStatus()['cached_url'] ?? 'http://localhost:8080'}$avatarUrl';
  }

  String _getVideoUrl(String? videoUrl) {
    if (videoUrl == null || videoUrl.isEmpty) return '';
    if (videoUrl.startsWith('http')) return videoUrl;

    // Use NetworkConfig for file URLs too
    return '${NetworkConfig.getStatus()['cached_url'] ?? 'http://localhost:8080'}$videoUrl';
  }

  void _onFollowChanged() {
    // This will be called when follow state changes
    // The FollowStateManager will handle the UI updates automatically
    print('[SearchPage] Follow state changed - UI will update automatically');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Discover'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        bottom: _currentQuery.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: TabBar(
                  controller: _tabController,
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
              )
            : null,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users, videos...',
                prefixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: (value) {
                // Debounce search - chỉ search khi dừng gõ 500ms
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == value && value.length >= 2) {
                    _performSearch(value);
                  } else if (value.length < 2) {
                    _performSearch(
                        ''); // Clear results if less than 2 characters
                  }
                });
              },
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.orange[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Content
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
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.trending_up, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                'Trending Users',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              if (_isLoadingTrending)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),

        // Trending Users List
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

  Widget _buildUsersList(List<dynamic> users,
      {bool showTrendingBadges = false}) {
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

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: isTopUser ? 4 : 1,
            child: ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).primaryColor,
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            (user['username']?[0] ?? '?').toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
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
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      user['displayName'] ?? user['username'] ?? 'Unknown User',
                      style: TextStyle(
                        fontWeight:
                            isTopUser ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (user['isVerified'] == true) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${user['username'] ?? 'unknown'}'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatCount(user['followersCount'] ?? 0)} followers',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight:
                              isTopUser ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      if (user['videosCount'] != null &&
                          user['videosCount'] > 0) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.video_library,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${user['videosCount']} videos',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                      if (isTopUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Trending',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).primaryColor,
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

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Play video: ${video['description'] ?? 'Untitled'}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video thumbnail
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

                        // Play overlay
                        const Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),

                        // Stats overlay
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

                // Video info
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
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              (video['user']?['username']?[0] ?? '?')
                                  .toUpperCase(),
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
                                color: Colors.grey[600],
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
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.comment, size: 12, color: Colors.blue),
                          const SizedBox(width: 2),
                          Text(
                            _formatCount(video['commentsCount'] ?? 0),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
