// tiktok_frontend/lib/src/features/feed/domain/models/video_post_model.dart

class VideoUser {
  final String username;
  final String? avatarUrl; 

  VideoUser({required this.username, this.avatarUrl});

  factory VideoUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      // Trả về một giá trị mặc định an toàn nếu user data là null
      return VideoUser(username: 'Unknown User', avatarUrl: null);
    }
    return VideoUser(
      username: json['username'] as String? ?? 'Unknown User',
      avatarUrl: json['avatarUrl'] as String?,
    );
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

  // Sửa tên tham số từ currentActiveUserId thành currentUserId
  factory VideoPost.fromJson(Map<String, dynamic> json, String backendBaseFileUrl, {String? currentUserId}) {
    String relativeVideoUrl = json['videoUrl'] as String? ?? '';
    String fullVideoUrl = relativeVideoUrl;

    if (relativeVideoUrl.isNotEmpty && 
        relativeVideoUrl.startsWith('/') && 
        backendBaseFileUrl.isNotEmpty) {
      fullVideoUrl = backendBaseFileUrl + relativeVideoUrl;
    } else if (relativeVideoUrl.isNotEmpty && !relativeVideoUrl.startsWith('http')) {
      print("Warning: Relative videoUrl ('$relativeVideoUrl') does not start with '/' or 'http'. It might not be a valid URL for playback.");
    }
    
    String defaultAudioName = 'Original Sound';
    final userMapFromJson = json['user'] as Map<String, dynamic>?;
    if (userMapFromJson != null && userMapFromJson['username'] != null) {
        defaultAudioName = 'Original Sound - ${userMapFromJson['username']}';
    }

    List<String> likesList = List<String>.from(json['likes'] as List? ?? []);
    bool likedByCurrentUser = false;
    if (currentUserId != null && currentUserId.isNotEmpty) { // SỬA Ở ĐÂY
        likedByCurrentUser = likesList.contains(currentUserId); // SỬA Ở ĐÂY
    }

    List<String> savesList = List<String>.from(json['saves'] as List? ?? []);
    bool savedByCurrentUser = false;
    if (currentUserId != null && currentUserId.isNotEmpty) { // SỬA Ở ĐÂY
        savedByCurrentUser = savesList.contains(currentUserId); // SỬA Ở ĐÂY
    }


    return VideoPost(
      id: json['_id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: json['userId'] as String? ?? '',
      user: VideoUser.fromJson(userMapFromJson),
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
  }
}
