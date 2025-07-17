// tiktok_frontend/lib/src/features/profile/presentation/pages/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/profile/domain/services/profile_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';

enum Gender { male, female, other }

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ProfileService _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankNameController = TextEditingController();
  
  // Synchronized upload variables (matching upload_video_page.dart pattern)
  PlatformFile? _selectedImageFile;
  String? _imageFileName;
  String? _uploadUrl;
  String? _bankQrImageUrl;
  String? _debugInfo;
  bool _isUploadingQr = false;
  bool _isLoading = false;
  bool _isSaving = false;
  DateTime? _selectedDateOfBirth;
  Gender? _selectedGender;

  final Map<String, bool> _interests = {
    'Âm nhạc': false,
    'Thể thao': false, 
    'Du lịch': false,
    'Game': false,
    'Ẩm thực': false,
    'Công nghệ': false,
    'Thời trang': false,
    'Phim ảnh': false,
  };

  @override
  void initState() {
    super.initState();
    _initializeUploadUrl();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _bankAccountController.dispose();
    _bankNameController.dispose();
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
      
      print('[EditProfilePage] Initialized upload URL: $_uploadUrl');
    } catch (e) {
      print('[EditProfilePage] Error initializing upload URL: $e');
      setState(() {
        _debugInfo = 'Error: Could not initialize upload URL\n$e';
      });
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

  Future<void> _loadUserProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = authService.currentUser!;
      
      setState(() {
        _usernameController.text = user.username;
        _emailController.text = user.email;
        
        // Parse date of birth
        if (user.dateOfBirth != null && user.dateOfBirth!.isNotEmpty) {
          _selectedDateOfBirth = DateTime.tryParse(user.dateOfBirth!);
          if (_selectedDateOfBirth != null) {
            _dobController.text = DateFormat('dd/MM/yyyy').format(_selectedDateOfBirth!);
          }
        }
        
        // Parse gender
        if (user.gender != null) {
          switch (user.gender!.toLowerCase()) {
            case 'male':
              _selectedGender = Gender.male;
              break;
            case 'female':
              _selectedGender = Gender.female;
              break;
            case 'other':
              _selectedGender = Gender.other;
              break;
          }
        }
        
        // Parse interests
        for (String interest in user.interests) {
          if (_interests.containsKey(interest)) {
            _interests[interest] = true;
          }
        }
        
        _isLoading = false;
      });
    } catch (e) {
      print('[EditProfilePage] Error loading profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải thông tin: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(DateTime.now().year - 18),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày sinh của bạn',
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // Pick image file (synchronized with upload_video_page.dart pattern)
  Future<void> _pickQrImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedImageFile = result.files.single;
          _imageFileName = _selectedImageFile!.name;
          print('[EditProfilePage] Image selected: $_imageFileName');
          if (!kIsWeb && _selectedImageFile!.path != null) {
             print('[EditProfilePage] Image path (mobile/desktop): ${_selectedImageFile!.path}');
          } else if (kIsWeb && _selectedImageFile!.bytes != null) {
             print('[EditProfilePage] Image bytes selected (web): ${_selectedImageFile!.bytes!.length}');
          }
        });
      } else {
        print('[EditProfilePage] No image selected.');
        setState(() {
          _selectedImageFile = null;
          _imageFileName = null;
        });
      }
    } catch (e) {
      print('[EditProfilePage] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  // Upload image (synchronized with upload_video_page.dart pattern)
  Future<void> _uploadQrImage() async {
    if (_selectedImageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an image to upload.')),
        );
      }
      return;
    }

    // Ensure upload URL is available
    if (_uploadUrl == null) {
      await _initializeUploadUrl();
      if (_uploadUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not determine upload URL. Please try again.')),
          );
        }
        return;
      }
    }

    setState(() => _isUploadingQr = true);

    var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl!));
    
    // Add userId if available
    if (_usernameController.text.isNotEmpty) {
      request.fields['userId'] = _usernameController.text.trim();
    }

    print('[EditProfilePage] Upload URL: $_uploadUrl');
    print('[EditProfilePage] Platform: ${_getPlatformName()}');
    print('[EditProfilePage] Fields: ${request.fields}');

    // Add file based on platform (same logic as upload_video_page.dart)
    if (kIsWeb && _selectedImageFile!.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'imageFile', 
        _selectedImageFile!.bytes!,
        filename: _imageFileName ?? 'image_from_web.png',
        contentType: MediaType('image', _imageFileName?.split('.').last ?? 'png'), 
      ));
      print('[EditProfilePage] Added file from bytes (web)');
    } else if (!kIsWeb && _selectedImageFile!.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          _selectedImageFile!.path!,
          filename: _imageFileName ?? _selectedImageFile!.path!.split(Platform.pathSeparator).last,
          contentType: MediaType('image', _selectedImageFile!.path!.split('.').lastOrNull ?? 'png'),
        ),
      );
      print('[EditProfilePage] Added file from path (mobile/desktop)');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find valid image file to upload.')),
        );
      }
      setState(() => _isUploadingQr = false);
      return;
    }
    
    try {
      print('[EditProfilePage] Sending upload request to $_uploadUrl');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      print('[EditProfilePage] Upload Response status: ${response.statusCode}');
      print('[EditProfilePage] Upload Response body: ${response.body}');

      if (!mounted) return; 

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['imageUrl'] != null) {
          setState(() {
            _bankQrImageUrl = data['imageUrl'];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'), 
              backgroundColor: Colors.green
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Server did not return image URL'), 
              backgroundColor: Colors.red
            ),
          );
        }
      } else {
        String errorMessage = 'Image upload failed. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {} 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('[EditProfilePage] Error uploading image: $e');
      if (mounted) {
        String errorMessage = 'Error uploading image: $e';
        if (e.toString().contains('Connection refused') || 
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('No address associated with hostname')) {
          errorMessage = 'Cannot connect to server. Please check your network connection.';
          // Clear cache and try to refresh URL for next attempt
          NetworkConfig.clearCache();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingQr = false);
      }
    }
  }

  Future<void> _refreshConnection() async {
    setState(() {
      _debugInfo = 'Refreshing connection...';
    });
    
    NetworkConfig.clearCache();
    await _initializeUploadUrl();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connection refreshed'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Build image preview widget
  Widget _buildImagePreview() {
    if (_bankQrImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _bankQrImageUrl!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 80,
              height: 80,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80,
              height: 80,
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
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        ),
      );
    } else if (!kIsWeb && _selectedImageFile?.path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_selectedImageFile!.path!),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Icon(
          Icons.image_outlined,
          color: Colors.grey,
          size: 40,
        ),
      );
    }
  }

  // Clear selected image
  void _clearSelectedImage() {
    setState(() {
      _selectedImageFile = null;
      _imageFileName = null;
      _bankQrImageUrl = null;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    List<String> selectedInterestsList = [];
    _interests.forEach((interest, isSelected) {
      if (isSelected) selectedInterestsList.add(interest);
    });
    try {
      final success = await _profileService.updateProfileWithBank(
        userId: authService.currentUser!.id,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        gender: _selectedGender?.toString().split('.').last,
        interests: selectedInterestsList,
        bankAccountNumber: _bankAccountController.text.trim().isEmpty ? null : _bankAccountController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
        bankQrImageUrl: _bankQrImageUrl,
      );
      if (mounted) {
        if (success) {
          await authService.refreshUserData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hồ sơ đã được cập nhật thành công!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật hồ sơ thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('[EditProfilePage] Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Lưu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Connection Status Card (similar to upload_video_page.dart)
                    Card(
                      color: _uploadUrl != null ? Colors.green.shade50 : Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _uploadUrl != null ? Icons.check_circle : Icons.warning,
                                  color: _uploadUrl != null ? Colors.green : Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Connection Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _uploadUrl != null ? Colors.green.shade700 : Colors.orange.shade700,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  onPressed: _refreshConnection,
                                  tooltip: 'Refresh Connection',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (_debugInfo != null)
                              Text(
                                _debugInfo!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _uploadUrl != null ? Colors.green.shade600 : Colors.orange.shade600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Avatar section
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).primaryColor.withOpacity(0.3),
                                width: 3,
                              ),
                            ),
                            child: const CircleAvatar(
                              radius: 47,
                              child: Icon(Icons.person, size: 50),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: () {
                                  // TODO: Implement avatar change
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Chức năng đổi avatar sẽ được thêm sau'),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Username field
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Tên người dùng',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên người dùng';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Email field (read-only for now)
                    TextFormField(
                      controller: _emailController,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        helperText: 'Email không thể thay đổi',
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Date of birth field
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Ngày sinh',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onTap: () => _selectDate(context),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Gender selection
                    Text(
                      'Giới tính:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: Gender.values.map((gender) {
                        String genderText = '';
                        switch (gender) {
                          case Gender.male:
                            genderText = 'Nam';
                            break;
                          case Gender.female:
                            genderText = 'Nữ';
                            break;
                          case Gender.other:
                            genderText = 'Khác';
                            break;
                        }
                        
                        return RadioListTile<Gender>(
                          title: Text(genderText),
                          value: gender,
                          groupValue: _selectedGender,
                          onChanged: (Gender? value) {
                            setState(() {
                              _selectedGender = value;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Interests section
                    Text(
                      'Sở thích:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: _interests.keys.map((String key) {
                        return FilterChip(
                          label: Text(key),
                          selected: _interests[key]!,
                          onSelected: (bool selected) {
                            setState(() {
                              _interests[key] = selected;
                            });
                          },
                          selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                          checkmarkColor: Theme.of(context).primaryColor,
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Bank information section - synchronized upload
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Thông tin ngân hàng (tùy chọn)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          
                          TextFormField(
                            controller: _bankAccountController,
                            decoration: InputDecoration(
                              labelText: 'Số tài khoản ngân hàng',
                              prefixIcon: const Icon(Icons.account_balance),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) { return null; },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _bankNameController,
                            decoration: InputDecoration(
                              labelText: 'Tên ngân hàng',
                              prefixIcon: const Icon(Icons.account_balance_wallet),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) { return null; },
                          ),
                          const SizedBox(height: 16),
                          
                          // QR Image selection
                          ElevatedButton.icon(
                            onPressed: _pickQrImage,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Select QR Image'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontSize: 16)
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Selected Image Display
                          if (_selectedImageFile != null || _bankQrImageUrl != null)
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected QR Image:',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildImagePreview(),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (_imageFileName != null) ...[
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.image, 
                                                      color: Theme.of(context).hintColor
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        _imageFileName!,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w500, 
                                                          fontSize: 15
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                              
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      icon: const Icon(Icons.cloud_upload, size: 18),
                                                      label: Text(_bankQrImageUrl != null ? 'Re-upload' : 'Upload'),
                                                      onPressed: (_selectedImageFile != null && !_isUploadingQr && _uploadUrl != null) ? _uploadQrImage : null,
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Theme.of(context).primaryColor,
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: const Icon(Icons.close, size: 18),
                                                    onPressed: _clearSelectedImage,
                                                    tooltip: 'Clear Image',
                                                  ),
                                                ],
                                              ),
                                              
                                              if (_isUploadingQr) ...[
                                                const SizedBox(height: 8),
                                                const LinearProgressIndicator(),
                                                const SizedBox(height: 4),
                                                const Text('Uploading image...', style: TextStyle(fontSize: 12)),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                          const SizedBox(height: 8),
                          Text(
                            'Supported formats: JPG, JPEG, PNG, GIF, WEBP\nMax size: 5MB',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save button
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Lưu thay đổi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Cancel button
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}