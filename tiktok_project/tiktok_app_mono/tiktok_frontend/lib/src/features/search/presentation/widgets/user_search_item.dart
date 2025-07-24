// tiktok_frontend/lib/src/features/search/presentation/widgets/user_search_item.dart
import 'package:flutter/material.dart';
import 'package:tiktok_frontend/src/features/search/domain/models/search_model.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';

class UserSearchItem extends StatefulWidget {
  final SearchUser user;
  final VoidCallback? onTap;
  final VoidCallback? onFollowTap;
  final bool showTrendingBadge;
  final int? trendingRank;
  final bool showRecentActivity;

  const UserSearchItem({
    super.key,
    required this.user,
    this.onTap,
    this.onFollowTap,
    this.showTrendingBadge = false,
    this.trendingRank,
    this.showRecentActivity = false,
  });

  @override
  State<UserSearchItem> createState() => _UserSearchItemState();
}

class _UserSearchItemState extends State<UserSearchItem> {
  bool _isFollowLoading = false;

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildTrendingBadge() {
    if (!widget.showTrendingBadge || widget.trendingRank == null) {
      return const SizedBox.shrink();
    }

    Color badgeColor;
    IconData badgeIcon;
    
    switch (widget.trendingRank!) {
      case 1:
        badgeColor = Colors.amber;
        badgeIcon = Icons.emoji_events;
        break;
      case 2:
        badgeColor = Colors.grey[400]!;
        badgeIcon = Icons.emoji_events;
        break;
      case 3:
        badgeColor = Colors.brown[300]!;
        badgeIcon = Icons.emoji_events;
        break;
      default:
        badgeColor = Theme.of(context).primaryColor;
        badgeIcon = Icons.trending_up;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            '#${widget.trendingRank}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (!widget.showRecentActivity || widget.user.recentActivity == null) {
      return const SizedBox.shrink();
    }

    final activity = widget.user.recentActivity!;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.whatshot,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${activity.recentVideos} videos, ${_formatCount(activity.recentViews)} views this ${activity.timeframe}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // User Avatar with trending badge overlay
                  Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.showTrendingBadge 
                                ? Theme.of(context).primaryColor.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: widget.user.avatarUrl != null
                              ? Image.network(
                                  widget.user.avatarUrl!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.grey[600],
                                  ),
                                ),
                        ),
                      ),
                      
                      // Trending score badge
                      if (widget.user.trendingScore != null && widget.user.trendingScore! > 0)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.local_fire_department,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.user.displayName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.user.isVerified)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.verified,
                                  size: 18,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '@${widget.user.username}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        
                        if (widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.user.bio!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        
                        const SizedBox(height: 8),
                        
                        // Stats row
                        Row(
                          children: [
                            _buildStatItem(
                              icon: Icons.people,
                              count: widget.user.followersCount,
                              label: 'Followers',
                            ),
                            const SizedBox(width: 16),
                            _buildStatItem(
                              icon: Icons.video_library,
                              count: widget.user.videosCount,
                              label: 'Videos',
                            ),
                            const Spacer(),
                            _buildTrendingBadge(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Follow Button
                  if (widget.onFollowTap != null)
                    SizedBox(
                      width: 80,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: _isFollowLoading ? null : () async {
                          setState(() {
                            _isFollowLoading = true;
                          });
                          
                          try {
                            widget.onFollowTap?.call();
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isFollowLoading = false;
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.user.isFollowing == true
                              ? Colors.grey[300]
                              : Theme.of(context).primaryColor,
                          foregroundColor: widget.user.isFollowing == true
                              ? Colors.grey[700]
                              : Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isFollowLoading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    widget.user.isFollowing == true
                                        ? Colors.grey[700]!
                                        : Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                widget.user.isFollowing == true ? 'Following' : 'Follow',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.volunteer_activism),
                    label: const Text('Donate'),
                    onPressed: () => _showDonateDialog(context),
                  ),
                ],
              ),
              
              // Recent Activity (if enabled)
              _buildRecentActivity(),
            ],
          ),
        ),
      ),
    );
  }

  void _showDonateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _DonateDialog(toUser: widget.user),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

class _DonateDialog extends StatefulWidget {
  final SearchUser toUser;
  const _DonateDialog({Key? key, required this.toUser}) : super(key: key);
  @override
  State<_DonateDialog> createState() => _DonateDialogState();
}

class _DonateDialogState extends State<_DonateDialog> {
  final _amountController = TextEditingController();
  
  // Synchronized upload variables (matching upload_video_page.dart pattern)
  PlatformFile? _selectedImageFile;
  String? _imageFileName;
  String? _uploadUrl;
  String? _proofImageUrl;
  String? _debugInfo;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeUploadUrl();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // Initialize upload URL (same pattern as upload_video_page.dart)
  Future<void> _initializeUploadUrl() async {
    try {
      _uploadUrl = await NetworkConfig.getBaseUrl('/api/users/upload-image');
      final status = NetworkConfig.getStatus();
      
      setState(() {
        _debugInfo = 'Platform: ${_getPlatformName()}\n'
                   'Upload URL: $_uploadUrl\n'
                   'Cached URL: ${status['cached_url']}\n'
                   'Cache Valid: ${status['cache_valid']}';
      });
      
    } catch (e) {
    }
  }

  String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) return 'Android';
        if (Platform.isIOS) return 'iOS';
        return Platform.operatingSystem;
      } catch (e) {
        return 'Unknown';
      }
    }
    return 'Unknown';
  }

  // Pick image file (synchronized with upload_video_page.dart pattern)
  Future<void> _pickProofImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedImageFile = result.files.single;
          _imageFileName = _selectedImageFile!.name;
          if (!kIsWeb && _selectedImageFile!.path != null) {
          } else if (kIsWeb && _selectedImageFile!.bytes != null) {
          }
        });
        
        // Auto-upload after selection
        await _uploadProofImage();
      } else {
        setState(() {
          _selectedImageFile = null;
          _imageFileName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  // Upload image (synchronized with upload_video_page.dart pattern)
  Future<void> _uploadProofImage() async {
    if (_selectedImageFile == null) {
      return;
    }

    // Ensure upload URL is available
    if (_uploadUrl == null) {
      await _initializeUploadUrl();
      if (_uploadUrl == null) {
        if (mounted) {
          setState(() {
            _error = 'Could not determine upload URL. Please try again.';
          });
        }
        return;
      }
    }

    setState(() => _isUploading = true);

    var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl!));
    
    // Add userId if available
    final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
    if (currentUserId != null) {
      request.fields['userId'] = currentUserId;
    }

    // Add file based on platform (same logic as upload_video_page.dart)
    if (kIsWeb && _selectedImageFile!.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'imageFile', 
        _selectedImageFile!.bytes!,
        filename: _imageFileName ?? 'image_from_web.png',
        contentType: MediaType('image', _imageFileName?.split('.').last ?? 'png'), 
      ));
    } else if (!kIsWeb && _selectedImageFile!.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          _selectedImageFile!.path!,
          filename: _imageFileName ?? _selectedImageFile!.path!.split(Platform.pathSeparator).last,
          contentType: MediaType('image', _selectedImageFile!.path!.split('.').lastOrNull ?? 'png'),
        ),
      );
    } else {
      if (mounted) {
        setState(() {
          _error = 'Could not find valid image file to upload.';
        });
      }
      setState(() => _isUploading = false);
      return;
    }
    
    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return; 

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['imageUrl'] != null) {
          setState(() {
            _proofImageUrl = data['imageUrl'];
            _error = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'), 
              backgroundColor: Colors.green
            ),
          );
        } else {
          setState(() {
            _error = 'Server did not return image URL';
          });
        }
      } else {
        String errorMessage = 'Image upload failed. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {} 
        setState(() {
          _error = errorMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error uploading image: $e';
        if (e.toString().contains('Connection refused') || 
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('No address associated with hostname')) {
          errorMessage = 'Cannot connect to server. Please check your network connection.';
          // Clear cache and try to refresh URL for next attempt
          NetworkConfig.clearCache();
        }
        setState(() {
          _error = errorMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // Build image preview widget
  Widget _buildImagePreview() {
    if (_proofImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _proofImageUrl!,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 60,
              height: 60,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 60,
              height: 60,
              color: Colors.grey[200],
              child: const Icon(Icons.error, color: Colors.red),
            );
          },
        ),
      );
    } else if (kIsWeb && _selectedImageFile?.bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _selectedImageFile!.bytes!,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        ),
      );
    } else if (!kIsWeb && _selectedImageFile?.path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_selectedImageFile!.path!),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Icon(
          Icons.image_outlined,
          color: Colors.grey,
          size: 30,
        ),
      );
    }
  }

  Future<void> _submitDonate() async {
    setState(() { _error = null; });
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() { _error = 'Vui lòng nhập số tiền hợp lệ'; });
      return;
    }
    if (_proofImageUrl == null) {
      setState(() { _error = 'Vui lòng upload ảnh xác nhận'; });
      return;
    }
    setState(() { _isUploading = true; });
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/donate');
      final fromUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
      if (fromUserId == null) {
        setState(() { _error = 'Không xác định được tài khoản của bạn'; });
        return;
      }
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromUserId': fromUserId,
          'toUserId': widget.toUser.id,
          'amount': amount,
          'donateProofImageUrl': _proofImageUrl,
        }),
      );
      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donate thành công!'), backgroundColor: Colors.green));
      } else {
        setState(() { _error = 'Donate thất bại'; });
      }
    } catch (e) {
      setState(() { _error = 'Lỗi: $e'; });
    } finally {
      setState(() { _isUploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Donate cho ${widget.toUser.username}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.toUser.bankAccountNumber != null || widget.toUser.bankName != null || widget.toUser.bankQrImageUrl != null) ...[
              const Text('Thông tin ngân hàng:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (widget.toUser.bankAccountNumber != null)
                Text('Số tài khoản: ${widget.toUser.bankAccountNumber}'),
              if (widget.toUser.bankName != null)
                Text('Ngân hàng: ${widget.toUser.bankName}'),
              if (widget.toUser.bankQrImageUrl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.network(
                    widget.toUser.bankQrImageUrl!,
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text('Không hiển thị được ảnh QR'),
                  ),
                ),
              const Divider(),
            ],
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số tiền'),
            ),
            const SizedBox(height: 8),
            
            // Proof image upload section with synchronized upload logic
            const Text('Ảnh xác nhận chuyển khoản:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            Row(
              children: [
                _buildImagePreview(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_imageFileName != null) ...[
                        Text(
                          'Đã chọn: $_imageFileName',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                      ],
                      
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: Text(_proofImageUrl != null ? 'Đổi ảnh' : 'Chọn ảnh'),
                        onPressed: _isUploading ? null : _pickProofImage,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      
                      if (_isUploading) ...[
                        const SizedBox(height: 4),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 2),
                        const Text('Đang upload...', style: TextStyle(fontSize: 10)),
                      ],
                      
                      if (_proofImageUrl != null) ...[
                        const SizedBox(height: 4),
                        const Text('✓ Uploaded successfully', style: TextStyle(fontSize: 10, color: Colors.green)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            Text(
              'Định dạng hỗ trợ: JPG, JPEG, PNG, GIF, WEBP\nKích thước tối đa: 5MB',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: _isUploading ? null : _submitDonate,
          child: _isUploading 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Xác nhận'),
        ),
      ],
    );
  }
}