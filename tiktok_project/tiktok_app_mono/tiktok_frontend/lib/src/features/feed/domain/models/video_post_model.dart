// tiktok_frontend/lib/src/features/feed/domain/models/video_post_model.dart

class VideoUser {
  final String username;
  final String? avatarUrl; 

  VideoUser({required this.username, this.avatarUrl});

  factory VideoUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      print('[VideoUser] JSON is null, using default values');
      return VideoUser(username: 'Unknown User', avatarUrl: null);
    }
    
    print('[VideoUser] Parsing JSON: $json');
    final username = json['username'] as String? ?? 'Unknown User';
    final avatarUrl = json['avatarUrl'] as String?;
    
    print('[VideoUser] Parsed: username="$username", avatarUrl="$avatarUrl"');
    
    return VideoUser(
      username: username,
      avatarUrl: avatarUrl,
    );
  }

  @override
  String toString() {
    return 'VideoUser(username: $username, avatarUrl: $avatarUrl)';
  }
}

class VideoPost {
  final String id;
  final String userId;
  final VideoUser user; // Thông tin người đăng (đã được parse)
  final String description;
  final String videoUrl; // URL đầy đủ để truy cập video
  final String? audioName; 
  int likesCount; // Sẽ cập nhật được
  final int commentsCount;
  final int sharesCount;
  final List<String> hashtags;
  final DateTime createdAt;
  List<String> likes; // Danh sách userId (dưới dạng String) đã like video này
  bool isLikedByCurrentUser; // User hiện tại có like video này không
  List<String> saves; // Danh sách userId (dưới dạng String) đã save video này
  bool isSavedByCurrentUser; // User hiện tại có save video này không

  VideoPost({
    required this.id,
    required this.userId,
    required this.user,
    required this.description,
    required this.videoUrl,
    this.audioName,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.hashtags,
    required this.createdAt,
    this.likes = const [],
    this.isLikedByCurrentUser = false,
    this.saves = const [],
    this.isSavedByCurrentUser = false,
  });

  factory VideoPost.fromJson(Map<String, dynamic> json, String backendBaseFileUrl, {String? currentUserId}) {
    print('[VideoPost] === Parsing video JSON ===');
    print('[VideoPost] JSON keys: ${json.keys.toList()}');
    print('[VideoPost] Raw JSON: $json');
    
    String relativeVideoUrl = json['videoUrl'] as String? ?? '';
    String fullVideoUrl = relativeVideoUrl;

    if (relativeVideoUrl.isNotEmpty && 
        relativeVideoUrl.startsWith('/') && 
        backendBaseFileUrl.isNotEmpty) {
      fullVideoUrl = backendBaseFileUrl + relativeVideoUrl;
    } else if (relativeVideoUrl.isNotEmpty && !relativeVideoUrl.startsWith('http')) {
      print("[VideoPost] Warning: Relative videoUrl ('$relativeVideoUrl') does not start with '/' or 'http'");
    }
    
    // FIXED: Parse user info - Ưu tiên 'user' field trước
    VideoUser userInfo;
    if (json.containsKey('user') && json['user'] != null) {
      // NEW FORMAT: có field 'user'
      print('[VideoPost] Found user field in JSON: ${json['user']}');
      userInfo = VideoUser.fromJson(json['user'] as Map<String, dynamic>?);
    } else {
      // OLD FORMAT: thông tin user ở level root (fallback)
      print('[VideoPost] No user field, checking root level fields');
      print('[VideoPost] Root username: "${json['username']}"');
      print('[VideoPost] Root userAvatarUrl: "${json['userAvatarUrl']}"');
      
      final Map<String, dynamic> userFromRoot = {
        'username': json['username'],
        'avatarUrl': json['userAvatarUrl'],
      };
      print('[VideoPost] User data from root: $userFromRoot');
      userInfo = VideoUser.fromJson(userFromRoot);
    }

    print('[VideoPost] Final parsed user info: $userInfo');
    
    // Generate default audio name
    String defaultAudioName = 'Original Sound';
    if (userInfo.username.isNotEmpty && userInfo.username != 'Unknown User') {
      defaultAudioName = 'Original Sound - ${userInfo.username}';
    }

    // Parse likes and saves
    List<String> likesList = [];
    if (json['likes'] != null && json['likes'] is List) {
      likesList = List<String>.from(json['likes'] as List);
    }
    
    List<String> savesList = [];
    if (json['saves'] != null && json['saves'] is List) {
      savesList = List<String>.from(json['saves'] as List);
    }

    // Check if current user liked/saved
    bool likedByCurrentUser = false;
    bool savedByCurrentUser = false;
    if (currentUserId != null && currentUserId.isNotEmpty) {
        likedByCurrentUser = likesList.contains(currentUserId);
        savedByCurrentUser = savesList.contains(currentUserId);
    }

    // Parse other fields safely
    final videoPost = VideoPost(
      id: json['_id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: json['userId'] as String? ?? '',
      user: userInfo,
      description: json['description'] as String? ?? '',
      videoUrl: fullVideoUrl,
      audioName: json['audioName'] as String? ?? defaultAudioName,
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      sharesCount: json['sharesCount'] as int? ?? 0,
      hashtags: List<String>.from(json['hashtags'] as List? ?? []),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      likes: likesList,
      isLikedByCurrentUser: likedByCurrentUser,
      saves: savesList,
      isSavedByCurrentUser: savedByCurrentUser,
    );

    print('[VideoPost] ✅ Created VideoPost:');
    print('[VideoPost] - ID: ${videoPost.id}');
    print('[VideoPost] - User: ${videoPost.user.username}');
    print('[VideoPost] - Description: ${videoPost.description}');
    print('[VideoPost] - VideoURL: ${videoPost.videoUrl}');
    print('[VideoPost] ========================');
    
    return videoPost;
  }

  @override
  String toString() {
    return 'VideoPost(id: $id, user: $user, description: ${description.length > 20 ? description.substring(0, 20) + "..." : description})';
  }
}