// tiktok_frontend/lib/src/features/search/presentation/pages/enhanced_search_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/search/domain/services/search_follow_sync_service.dart';
import 'package:tiktok_frontend/src/features/search/presentation/widgets/optimized_user_search_item.dart';
import 'package:tiktok_frontend/src/core/config/network_config.dart';

class EnhancedSearchPage extends StatefulWidget {
  const EnhancedSearchPage({super.key});

  @override
  State<EnhancedSearchPage> createState() => _EnhancedSearchPageState();
}

class _EnhancedSearchPageState extends State<EnhancedSearchPage> 
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  // Controllers and managers
  final TextEditingController _searchController = TextEditingController();
  final SearchFollowSyncService _syncService = SearchFollowSyncService();
  late TabController _tabController;
  
  // Search debounce
  Timer? _debounceTimer;
  
  // State variables
  bool _isSearching = false;
  bool _isLoadingTrending = false;
  List<Map<String, dynamic>> _userResults = [];
  List<Map<String, dynamic>> _videoResults = [];
  List<Map<String, dynamic>> _trendingUsers = [];
  String _currentQuery = '';
  String? _errorMessage;
  int _userCount = 0;
  int _videoCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Subscribe to follow state changes
    _syncService.subscribeToFollowStateChanges(_onFollowStateChanged);
    
    // Load trending users on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrendingUsers();
    });
  }

  @override
  void dispose() {
    _syncService.unsubscribeFromFollowStateChanges(_onFollowStateChanged);
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onFollowStateChanged() {
    if (mounted) {
      setState(() {
        // UI will update automatically as the data references are maintained
      });
    }
  }

  Future<void> _loadTrendingUsers() async {
    if (_isLoadingTrending) return;
    
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

      print('[EnhancedSearchPage] Loading trending users from: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final trendingUsers = List<Map<String, dynamic>>.from(
          (data['trendingUsers'] ?? []).map((user) => Map<String, dynamic>.from(user))
        );
        
        if (mounted) {
          setState(() {
            _trendingUsers = trendingUsers;
            _isLoadingTrending = false;
            _errorMessage = null;
          });
          
          // Sync follow states
          await _syncService.syncFollowStatesForUsers(_trendingUsers, currentUserId);
          
          if (mounted) {
            setState(() {}); // Refresh UI after sync
          }
        }
        print('[EnhancedSearchPage] ✅ Loaded ${_trendingUsers.length} trending users');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[EnhancedSearchPage] ❌ Error loading trending users: $e');
      await _loadFallbackUsers();
    }
  }

  Future<void> _loadFallbackUsers() async {
    try {
      // Use NetworkConfig for fallback URL too
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final uri = Uri.parse(baseUrl);
      
      print('[EnhancedSearchPage] Loading fallback users from: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(
          (data['users'] ?? data ?? []).map((user) => Map<String, dynamic>.from(user))
        );
        
        // Sort by followers count
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
          
          // Sync follow states
          final authService = Provider.of<AuthService>(context, listen: false);
          await _syncService.syncFollowStatesForUsers(_trendingUsers, authService.currentUser?.id);
          
          if (mounted) {
            setState(() {}); // Refresh UI after sync
          }
        }
        print('[EnhancedSearchPage] ✅ Loaded ${_trendingUsers.length} fallback users from DB');
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      print('[EnhancedSearchPage] ❌ Error loading fallback users: $e');
      if (mounted) {
        setState(() {
          _isLoadingTrending = false;
          _errorMessage = 'Unable to load users. Please check your connection and try again.';
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    
    if (value.trim().length < 2) {
      _performSearch('');
      return;
    }
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text == value && mounted) {
        _performSearch(value.trim());
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
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

    if (_isSearching) return;

    setState(() {
      _isSearching = true;
      _currentQuery = query;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;

      // Search both users and videos concurrently
      final futures = await Future.wait([
        _searchUsers(query, currentUserId),
        _searchVideos(query, currentUserId),
      ]);

      if (mounted) {
        final userResults = List<Map<String, dynamic>>.from(
          (futures[0]['users'] ?? []).map((user) => Map<String, dynamic>.from(user))
        );
        final videoResults = List<Map<String, dynamic>>.from(
          (futures[1]['videos'] ?? []).map((video) => Map<String, dynamic>.from(video))
        );

        setState(() {
          _userResults = userResults;
          _videoResults = videoResults;
          _userCount = userResults.length;
          _videoCount = videoResults.length;
          _isSearching = false;
          _errorMessage = null;
        });
        
        // Sync follow states for search results
        if (userResults.isNotEmpty) {
          await _syncService.syncFollowStatesForUsers(userResults, currentUserId);
          if (mounted) {
            setState(() {}); // Refresh UI after sync
          }
        }
      }
    } catch (e) {
      print('[EnhancedSearchPage] ❌ Error performing search: $e');
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

      print('[EnhancedSearchPage] Searching users: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[EnhancedSearchPage] ✅ Found ${(data['users'] as List?)?.length ?? 0} users for "$query"');
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[EnhancedSearchPage] ❌ Error searching users: $e');
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

      print('[EnhancedSearchPage] Searching videos: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[EnhancedSearchPage] ✅ Found ${(data['videos'] as List?)?.length ?? 0} videos for "$query"');
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[EnhancedSearchPage] ❌ Error searching videos: $e');
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

  String _getVideoUrl(String? videoUrl) {
    if (videoUrl == null || videoUrl.isEmpty) return '';
    if (videoUrl.startsWith('http')) return videoUrl;
    
    // Use NetworkConfig for file URLs
    final cachedUrl = NetworkConfig.getStatus()['cached_url'] ?? 'http://localhost:8080';
    return '$cachedUrl$videoUrl';
  }

  void _onFollowChanged() {
    // This callback is triggered when any follow button state changes
    print('[EnhancedSearchPage] Follow state changed - UI updated automatically');
  }

  void _onUserTap(Map<String, dynamic> user) {
    final username = user['username'] ?? 'unknown';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View profile: @$username'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Discover'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: _currentQuery.isNotEmpty ? PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey[600],
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
        ) : null,
      ),
      body: Column(
        children: [
          // Enhanced Search Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users, videos...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: _isSearching
                      ? Container(
                          width: 20,
                          height: 20,
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.search,
                          color: Colors.grey[600],
                        ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[600]),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: _performSearch,
              ),
            ),
          ),

          // Error Message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.orange[700], fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: Colors.orange[700],
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
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
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_up, 
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trending Users',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Discover popular creators',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingTrending)
                Container(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
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

  Widget _buildUsersList(List<Map<String, dynamic>> users, {bool showTrendingBadges = false}) {
    if (_isSearching || _isLoadingTrending) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'Searching...' : 'Loading trending users...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _currentQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _currentQuery.isNotEmpty 
                  ? 'No users found for "$_currentQuery"'
                  : 'No trending users available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_currentQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try different keywords or check your spelling',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _currentQuery.isEmpty ? _loadTrendingUsers : () => _performSearch(_currentQuery),
      color: Theme.of(context).primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          
          return OptimizedUserSearchItem(
            user: user,
            onTap: () => _onUserTap(user),
            showTrendingBadge: showTrendingBadges,
            trendingRank: showTrendingBadges ? index : null,
            showRecentActivity: showTrendingBadges,
            onFollowChanged: _onFollowChanged,
          );
        },
      ),
    );
  }

  Widget _buildVideosList(List<Map<String, dynamic>> videos) {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching videos...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No videos found for "$_currentQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        final thumbnailUrl = _getVideoUrl(video['thumbnailUrl']);

        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Play video: ${video['description'] ?? 'Untitled'}'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
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
                      color: Colors.grey[900],
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
                              color: Colors.white70,
                            ),
                          ),
                        
                        // Play overlay
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        
                        // Stats overlay
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
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
                                    fontWeight: FontWeight.w500,
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