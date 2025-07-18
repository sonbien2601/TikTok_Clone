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
  
  // Upload variables for QR image
  PlatformFile? _selectedQrImageFile;
  String? _qrImageFileName;
  String? _bankQrImageUrl;
  bool _isUploadingQr = false;

  // Upload variables for bank image  
  PlatformFile? _selectedBankImageFile;
  String? _bankImageFileName;
  String? _bankImageUrl;
  bool _isUploadingBankImage = false;

  // Common upload URL
  String? _uploadUrl;
  String? _debugInfo;
  
  bool _isLoading = false;
  bool _isSaving = false;
  DateTime? _selectedDateOfBirth;
  Gender? _selectedGender;

  final int _maxFileSize = 5 * 1024 * 1024; // 5MB

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
        // FIX: Populate form fields với dữ liệu hiện có
        _usernameController.text = user.username;
        _emailController.text = user.email;
        _bankAccountController.text = user.bankAccountNumber ?? '';
        _bankNameController.text = user.bankName ?? '';
        
        // FIX: Load URLs của ảnh đã có
        _bankQrImageUrl = user.bankQrImageUrl;
        // _bankImageUrl = user.bankImageUrl; // FIX: The UserFrontend model does not have bankImageUrl, so comment or remove this line
        
        // FIX: Handle date of birth properly
        if (user.dateOfBirth != null && user.dateOfBirth!.isNotEmpty) {
          try {
            // Try parsing ISO format first
            _selectedDateOfBirth = DateTime.parse(user.dateOfBirth!);
            _dobController.text = DateFormat('dd/MM/yyyy').format(_selectedDateOfBirth!);
          } catch (e) {
            // If ISO parsing fails, try dd/MM/yyyy format
            try {
              _selectedDateOfBirth = DateFormat('dd/MM/yyyy').parse(user.dateOfBirth!);
              _dobController.text = user.dateOfBirth!;
            } catch (e2) {
              print('[EditProfilePage] Could not parse date: ${user.dateOfBirth}');
            }
          }
        }
        
        // FIX: Load gender properly
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
        
        // FIX: Load interests properly
        _interests.updateAll((key, value) => false); // Reset all to false first
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

  Future<void> _pickQrImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedQrImageFile = result.files.single;
          _qrImageFileName = _selectedQrImageFile!.name;
          print('[EditProfilePage] QR Image selected: $_qrImageFileName');
        });
      } else {
        print('[EditProfilePage] No QR image selected.');
        setState(() {
          _selectedQrImageFile = null;
          _qrImageFileName = null;
        });
      }
    } catch (e) {
      print('[EditProfilePage] Error picking QR image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting QR image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickBankImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedBankImageFile = result.files.single;
          _bankImageFileName = _selectedBankImageFile!.name;
          print('[EditProfilePage] Bank Image selected: $_bankImageFileName');
        });
      } else {
        print('[EditProfilePage] No bank image selected.');
        setState(() {
          _selectedBankImageFile = null;
          _bankImageFileName = null;
        });
      }
    } catch (e) {
      print('[EditProfilePage] Error picking bank image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting bank image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadQrImage() async {
    if (_selectedQrImageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ảnh QR để tải lên.')),
        );
      }
      return;
    }

    if (_uploadUrl == null) {
      await _initializeUploadUrl();
      if (_uploadUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không xác định được URL tải lên. Vui lòng thử lại.')),
          );
        }
        return;
      }
    }

    setState(() => _isUploadingQr = true);

    var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl!));
    
    if (_usernameController.text.isNotEmpty) {
      request.fields['userId'] = _usernameController.text.trim();
    }

    if (kIsWeb && _selectedQrImageFile!.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'imageFile', 
        _selectedQrImageFile!.bytes!,
        filename: _qrImageFileName ?? 'qr_image_from_web.png',
        contentType: MediaType('image', _qrImageFileName?.split('.').last ?? 'png'), 
      ));
    } else if (!kIsWeb && _selectedQrImageFile!.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          _selectedQrImageFile!.path!,
          filename: _qrImageFileName ?? _selectedQrImageFile!.path!.split(Platform.pathSeparator).last,
          contentType: MediaType('image', _selectedQrImageFile!.path!.split('.').lastOrNull ?? 'png'),
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy file ảnh QR hợp lệ để tải lên.')),
        );
      }
      setState(() => _isUploadingQr = false);
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
            _bankQrImageUrl = data['imageUrl'];
            _selectedQrImageFile = null;
            _qrImageFileName = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ảnh QR tải lên thành công!'), 
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Server không trả về URL ảnh QR'), 
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        String errorMessage = 'Tải ảnh QR thất bại. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {} 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('[EditProfilePage] Error uploading QR image: $e');
      if (mounted) {
        String errorMessage = 'Lỗi tải ảnh QR: $e';
        if (e.toString().contains('Connection refused') || 
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('No address associated with hostname')) {
          errorMessage = 'Không thể kết nối tới server. Vui lòng kiểm tra kết nối mạng.';
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

  Future<void> _uploadBankImage() async {
    if (_selectedBankImageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ảnh ngân hàng để tải lên.')),
        );
      }
      return;
    }

    if (_uploadUrl == null) {
      await _initializeUploadUrl();
      if (_uploadUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không xác định được URL tải lên. Vui lòng thử lại.')),
          );
        }
        return;
      }
    }

    setState(() => _isUploadingBankImage = true);

    var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl!));
    
    if (_usernameController.text.isNotEmpty) {
      request.fields['userId'] = _usernameController.text.trim();
    }

    if (kIsWeb && _selectedBankImageFile!.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'imageFile', 
        _selectedBankImageFile!.bytes!,
        filename: _bankImageFileName ?? 'bank_image_from_web.png',
        contentType: MediaType('image', _bankImageFileName?.split('.').last ?? 'png'), 
      ));
    } else if (!kIsWeb && _selectedBankImageFile!.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          _selectedBankImageFile!.path!,
          filename: _bankImageFileName ?? _selectedBankImageFile!.path!.split(Platform.pathSeparator).last,
          contentType: MediaType('image', _selectedBankImageFile!.path!.split('.').lastOrNull ?? 'png'),
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy file ảnh ngân hàng hợp lệ để tải lên.')),
        );
      }
      setState(() => _isUploadingBankImage = false);
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
            _bankImageUrl = data['imageUrl'];
            _selectedBankImageFile = null;
            _bankImageFileName = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ảnh ngân hàng tải lên thành công!'), 
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Server không trả về URL ảnh ngân hàng'), 
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        String errorMessage = 'Tải ảnh ngân hàng thất bại. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {} 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('[EditProfilePage] Error uploading bank image: $e');
      if (mounted) {
        String errorMessage = 'Lỗi tải ảnh ngân hàng: $e';
        if (e.toString().contains('Connection refused') || 
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('No address associated with hostname')) {
          errorMessage = 'Không thể kết nối tới server. Vui lòng kiểm tra kết nối mạng.';
          NetworkConfig.clearCache();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingBankImage = false);
      }
    }
  }

  Widget _buildQrImagePreview() {
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
    } else if (kIsWeb && _selectedQrImageFile?.bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _selectedQrImageFile!.bytes!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        ),
      );
    } else if (!kIsWeb && _selectedQrImageFile?.path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_selectedQrImageFile!.path!),
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
          Icons.qr_code_scanner,
          color: Colors.grey,
          size: 40,
        ),
      );
    }
  }

  Widget _buildBankImagePreview() {
    if (_bankImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _bankImageUrl!,
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
    } else if (kIsWeb && _selectedBankImageFile?.bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _selectedBankImageFile!.bytes!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        ),
      );
    } else if (!kIsWeb && _selectedBankImageFile?.path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_selectedBankImageFile!.path!),
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
          Icons.photo_camera,
          color: Colors.grey,
          size: 40,
        ),
      );
    }
  }

  void _clearQrImage() {
    setState(() {
      _selectedQrImageFile = null;
      _qrImageFileName = null;
      _bankQrImageUrl = null;
    });
  }

  void _clearBankImage() {
    setState(() {
      _selectedBankImageFile = null;
      _bankImageFileName = null;
      _bankImageUrl = null;
    });
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
        bankImageUrl: _bankImageUrl,
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
                          Text(
                            'Thông tin ngân hàng (tùy chọn)', 
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600
                            ),
                          ),
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _bankAccountController,
                            decoration: InputDecoration(
                              labelText: 'Số tài khoản ngân hàng',
                              prefixIcon: const Icon(Icons.credit_card),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) { return null; },
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.qr_code, color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Mã QR thanh toán',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _pickQrImage,
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Chọn ảnh QR'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    textStyle: const TextStyle(fontSize: 16)
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_selectedQrImageFile != null || _bankQrImageUrl != null)
                                  Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ảnh QR đã chọn:',
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildQrImagePreview(),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (_qrImageFileName != null) ...[
                                                      Row(
                                                        children: [
                                                          Icon(Icons.image, color: Theme.of(context).hintColor),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              _qrImageFileName!,
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
                                                            label: Text(_bankQrImageUrl != null ? 'Tải lại' : 'Tải lên'),
                                                            onPressed: (_selectedQrImageFile != null && !_isUploadingQr && _uploadUrl != null) ? _uploadQrImage : null,
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
                                                          onPressed: _clearQrImage,
                                                          tooltip: 'Xóa ảnh',
                                                        ),
                                                      ],
                                                    ),
                                                    if (_isUploadingQr) ...[
                                                      const SizedBox(height: 8),
                                                      const LinearProgressIndicator(),
                                                      const SizedBox(height: 4),
                                                      const Text('Đang tải ảnh lên...', style: TextStyle(fontSize: 12)),
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.photo_camera, color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ảnh ngân hàng',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ảnh thẻ ngân hàng hoặc ảnh chụp màn hình app',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _pickBankImage,
                                  icon: const Icon(Icons.add_a_photo),
                                  label: const Text('Chọn ảnh ngân hàng'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    textStyle: const TextStyle(fontSize: 16)
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_selectedBankImageFile != null || _bankImageUrl != null)
                                  Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ảnh ngân hàng đã chọn:',
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildBankImagePreview(),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (_bankImageFileName != null) ...[
                                                      Row(
                                                        children: [
                                                          Icon(Icons.image, color: Theme.of(context).hintColor),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              _bankImageFileName!,
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
                                                            label: Text(_bankImageUrl != null ? 'Tải lại' : 'Tải lên'),
                                                            onPressed: (_selectedBankImageFile != null && !_isUploadingBankImage && _uploadUrl != null) ? _uploadBankImage : null,
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.green.shade600,
                                                              foregroundColor: Colors.white,
                                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        IconButton(
                                                          icon: const Icon(Icons.close, size: 18),
                                                          onPressed: _clearBankImage,
                                                          tooltip: 'Xóa ảnh',
                                                        ),
                                                      ],
                                                    ),
                                                    if (_isUploadingBankImage) ...[
                                                      const SizedBox(height: 8),
                                                      const LinearProgressIndicator(),
                                                      const SizedBox(height: 4),
                                                      const Text('Đang tải ảnh lên...', style: TextStyle(fontSize: 12)),
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hỗ trợ: JPG, JPEG, PNG, GIF, WEBP\nKích thước tối đa: 5MB',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
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