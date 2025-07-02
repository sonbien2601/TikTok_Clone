// tiktok_frontend/lib/src/features/share/presentation/widgets/share_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/share/domain/services/share_service.dart';
import 'package:tiktok_frontend/src/features/feed/domain/models/video_post_model.dart';

class ShareBottomSheet extends StatefulWidget {
  final VideoPost videoPost;
  final Function(int)? onSharesCountChanged;

  const ShareBottomSheet({
    super.key,
    required this.videoPost,
    this.onSharesCountChanged,
  });

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet>
    with SingleTickerProviderStateMixin {
  final ShareService _shareService = ShareService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  List<ShareMethod> _availableShareMethods = [];
  bool _isLoading = false;
  String? _customMessage;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _loadAvailableShareMethods();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableShareMethods() async {
    final methods = await _shareService.getAvailableShareMethods();
    setState(() {
      _availableShareMethods = methods;
    });
  }

  Future<void> _handleShare(ShareMethod method) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.id;

    try {
      ShareResponse response;

      switch (method) {
        case ShareMethod.whatsapp:
          response = await _shareService.shareToWhatsApp(
            videoId: widget.videoPost.id,
            videoTitle: widget.videoPost.description,
            username: widget.videoPost.user.username,
            userId: currentUserId,
            customMessage: _customMessage,
          );
          break;
        case ShareMethod.facebook:
          response = await _shareService.shareToFacebook(
            videoId: widget.videoPost.id,
            videoTitle: widget.videoPost.description,
            username: widget.videoPost.user.username,
            userId: currentUserId,
            customMessage: _customMessage,
          );
          break;
        case ShareMethod.twitter:
          response = await _shareService.shareToTwitter(
            videoId: widget.videoPost.id,
            videoTitle: widget.videoPost.description,
            username: widget.videoPost.user.username,
            userId: currentUserId,
            customMessage: _customMessage,
          );
          break;
        case ShareMethod.sms:
          response = await _shareService.shareToSMS(
            videoId: widget.videoPost.id,
            videoTitle: widget.videoPost.description,
            username: widget.videoPost.user.username,
            userId: currentUserId,
            customMessage: _customMessage,
          );
          break;
        case ShareMethod.email:
          response = await _shareService.shareToEmail(
            videoId: widget.videoPost.id,
            videoTitle: widget.videoPost.description,
            username: widget.videoPost.user.username,
            userId: currentUserId,
            customMessage: _customMessage,
          );
          break;
        case ShareMethod.copyLink:
          response = await _shareService.copyLink(
            videoId: widget.videoPost.id,
            userId: currentUserId,
          );
          break;
        case ShareMethod.native:
        default:
          response = await _shareService.shareNative(
            videoId: widget.videoPost.id,
            videoTitle: widget.videoPost.description,
            username: widget.videoPost.user.username,
            userId: currentUserId,
            customMessage: _customMessage,
          );
          break;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Update shares count if successful
        if (response.success && response.newSharesCount > 0) {
          widget.onSharesCountChanged?.call(response.newSharesCount);
        }

        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  response.success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(response.message)),
              ],
            ),
            backgroundColor: response.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );

        // Close sheet after successful share (except for copy link)
        if (response.success && method != ShareMethod.copyLink) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to share: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Share Video',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share this amazing video by @${widget.videoPost.user.username}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Video preview
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                // Video thumbnail placeholder
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.videoPost.description,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.videoPost.formattedViewsCount,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.favorite,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.videoPost.formattedLikesCount,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Custom message input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Add a custom message (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: 2,
              maxLength: 200,
              onChanged: (value) {
                setState(() {
                  _customMessage = value.isEmpty ? null : value;
                });
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Share options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share to',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Share method grid
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: _buildShareMethodsGrid(),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Bottom padding for safe area
          SizedBox(height: mediaQuery.padding.bottom),
        ],
      ),
    );
  }

  Widget _buildShareMethodsGrid() {
    if (_availableShareMethods.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _availableShareMethods.length,
      itemBuilder: (context, index) {
        final method = _availableShareMethods[index];
        return _buildShareMethodButton(method);
      },
    );
  }

  Widget _buildShareMethodButton(ShareMethod method) {
    return GestureDetector(
      onTap: _isLoading ? null : () => _handleShare(method),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _getMethodColor(method).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getMethodColor(method).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              _getMethodIcon(method),
              color: _getMethodColor(method),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            method.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _getMethodIcon(ShareMethod method) {
    switch (method) {
      case ShareMethod.whatsapp:
        return Icons.chat;
      case ShareMethod.facebook:
        return Icons.facebook;
      case ShareMethod.instagram:
        return Icons.camera_alt;
      case ShareMethod.twitter:
        return Icons.trending_up;
      case ShareMethod.copyLink:
        return Icons.link;
      case ShareMethod.sms:
        return Icons.sms;
      case ShareMethod.email:
        return Icons.email;
      case ShareMethod.native:
        return Icons.share;
      case ShareMethod.other:
        return Icons.more_horiz;
    }
  }

  Color _getMethodColor(ShareMethod method) {
    switch (method) {
      case ShareMethod.whatsapp:
        return const Color(0xFF25D366);
      case ShareMethod.facebook:
        return const Color(0xFF1877F2);
      case ShareMethod.instagram:
        return const Color(0xFFE4405F);
      case ShareMethod.twitter:
        return const Color(0xFF1DA1F2);
      case ShareMethod.copyLink:
        return Colors.orange;
      case ShareMethod.sms:
        return Colors.green;
      case ShareMethod.email:
        return Colors.red;
      case ShareMethod.native:
        return Colors.blue;
      case ShareMethod.other:
        return Colors.grey;
    }
  }
}