// tiktok_frontend/lib/src/features/follow/presentation/widgets/follow_button_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/follow/domain/services/follow_service.dart';

enum FollowButtonStyle {
  primary,    // Blue background, white text
  outline,    // Transparent background, blue border
  compact,    // Smaller size
  minimal,    // Icon only
}

class FollowButtonWidget extends StatefulWidget {
  final String targetUserId;
  final String targetUsername;
  final bool initialIsFollowing;
  final int initialFollowerCount;
  final FollowButtonStyle style;
  final VoidCallback? onFollowChanged;
  final EdgeInsets? padding;
  final double? fontSize;
  final double? iconSize;

  const FollowButtonWidget({
    super.key,
    required this.targetUserId,
    required this.targetUsername,
    required this.initialIsFollowing,
    required this.initialFollowerCount,
    this.style = FollowButtonStyle.primary,
    this.onFollowChanged,
    this.padding,
    this.fontSize,
    this.iconSize,
  });

  @override
  State<FollowButtonWidget> createState() => _FollowButtonWidgetState();
}

class _FollowButtonWidgetState extends State<FollowButtonWidget> 
    with SingleTickerProviderStateMixin {
  final FollowService _followService = FollowService();
  
  late bool _isFollowing;
  late int _followerCount;
  bool _isLoading = false;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialIsFollowing;
    _followerCount = widget.initialFollowerCount;

    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Load actual follow status
    _loadFollowStatus();
  }

  Future<void> _loadFollowStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    try {
      final status = await _followService.checkFollowStatus(
        authService.currentUser!.id,
        widget.targetUserId,
      );
      
      if (mounted) {
        setState(() {
          _isFollowing = status.isFollowing;
          _followerCount = status.targetUser.followersCount;
        });
      }
    } catch (e) {
      print('[FollowButtonWidget] Error loading follow status: $e');
      // Keep using initial values if API fails
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FollowButtonWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsFollowing != widget.initialIsFollowing) {
      setState(() {
        _isFollowing = widget.initialIsFollowing;
      });
    }
    if (oldWidget.initialFollowerCount != widget.initialFollowerCount) {
      setState(() {
        _followerCount = widget.initialFollowerCount;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (!authService.isAuthenticated || authService.currentUser == null) {
      _showLoginRequiredDialog();
      return;
    }

    // Prevent self-follow
    if (authService.currentUser!.id == widget.targetUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không thể theo dõi chính mình!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isLoading) return;

    // Animate button press
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    setState(() {
      _isLoading = true;
    });

    // Optimistic update
    final originalIsFollowing = _isFollowing;
    final originalFollowerCount = _followerCount;
    
    setState(() {
      _isFollowing = !_isFollowing;
      _followerCount += _isFollowing ? 1 : -1;
    });

    try {
      if (originalIsFollowing) {
        // Unfollow
        final result = await _followService.unfollowUser(
          authService.currentUser!.id,
          widget.targetUserId,
        );
        
        setState(() {
          _isFollowing = result.isFollowing;
          _followerCount = result.followerCount;
        });

        _showSuccessMessage('Đã bỏ theo dõi @${widget.targetUsername}');
      } else {
        // Follow
        final result = await _followService.followUser(
          authService.currentUser!.id,
          widget.targetUserId,
        );
        
        setState(() {
          _isFollowing = result.isFollowing;
          _followerCount = result.followerCount;
        });

        _showSuccessMessage('Đã theo dõi @${widget.targetUsername}');
      }

      // Notify parent widget
      widget.onFollowChanged?.call();

    } catch (e) {
      print('[FollowButtonWidget] Error toggling follow: $e');
      
      // Revert optimistic update
      setState(() {
        _isFollowing = originalIsFollowing;
        _followerCount = originalFollowerCount;
      });

      _showErrorMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Đăng nhập yêu cầu'),
          content: const Text('Bạn cần đăng nhập để theo dõi người dùng khác.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Navigate to login page
              },
              child: const Text('Đăng nhập'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Lỗi: $error')),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Thử lại',
          textColor: Colors.white,
          onPressed: _toggleFollow,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: _buildButton(),
        );
      },
    );
  }

  Widget _buildButton() {
    switch (widget.style) {
      case FollowButtonStyle.primary:
        return _buildPrimaryButton();
      case FollowButtonStyle.outline:
        return _buildOutlineButton();
      case FollowButtonStyle.compact:
        return _buildCompactButton();
      case FollowButtonStyle.minimal:
        return _buildMinimalButton();
    }
  }

  Widget _buildPrimaryButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _toggleFollow,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFollowing ? Colors.grey.shade600 : Colors.blue.shade600,
        foregroundColor: Colors.white,
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 2,
      ),
      icon: _isLoading
          ? SizedBox(
              width: widget.iconSize ?? 16,
              height: widget.iconSize ?? 16,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(
              _isFollowing ? Icons.person_remove : Icons.person_add,
              size: widget.iconSize ?? 16,
            ),
      label: Text(
        _isFollowing ? 'Bỏ theo dõi' : 'Theo dõi',
        style: TextStyle(
          fontSize: widget.fontSize ?? 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOutlineButton() {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _toggleFollow,
      style: OutlinedButton.styleFrom(
        foregroundColor: _isFollowing ? Colors.grey.shade600 : Colors.blue.shade600,
        side: BorderSide(
          color: _isFollowing ? Colors.grey.shade600 : Colors.blue.shade600,
          width: 1.5,
        ),
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      icon: _isLoading
          ? SizedBox(
              width: widget.iconSize ?? 16,
              height: widget.iconSize ?? 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isFollowing ? Colors.grey.shade600 : Colors.blue.shade600,
                ),
              ),
            )
          : Icon(
              _isFollowing ? Icons.person_remove : Icons.person_add,
              size: widget.iconSize ?? 16,
            ),
      label: Text(
        _isFollowing ? 'Bỏ theo dõi' : 'Theo dõi',
        style: TextStyle(
          fontSize: widget.fontSize ?? 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCompactButton() {
    return Container(
      height: 28,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing ? Colors.grey.shade600 : Colors.blue.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 1,
          minimumSize: const Size(0, 28),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildMinimalButton() {
    return IconButton(
      onPressed: _isLoading ? null : _toggleFollow,
      icon: _isLoading
          ? SizedBox(
              width: widget.iconSize ?? 24,
              height: widget.iconSize ?? 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isFollowing ? Colors.grey.shade600 : Colors.blue.shade600,
                ),
              ),
            )
          : Icon(
              _isFollowing ? Icons.person_remove : Icons.person_add,
              size: widget.iconSize ?? 24,
              color: _isFollowing ? Colors.grey.shade600 : Colors.blue.shade600,
            ),
      tooltip: _isFollowing ? 'Bỏ theo dõi' : 'Theo dõi',
      splashRadius: 20,
    );
  }

  // Utility method to format follower count
  String _formatFollowerCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
  }
}