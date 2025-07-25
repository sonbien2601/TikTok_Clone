import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/profile/domain/services/profile_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

enum Gender { male, female, other }

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> with TickerProviderStateMixin {
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

  // Avatar upload variables
  PlatformFile? _selectedAvatarFile;
  String? _avatarFileName;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  // Common upload URL
  String? _uploadUrl;
  
  bool _isLoading = false;
  bool _isSaving = false;
  DateTime? _selectedDateOfBirth;
  Gender? _selectedGender;

  final int _maxFileSize = 5 * 1024 * 1024; // 5MB

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _textFieldController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  List<Animation<Offset>> _textFieldAnimations = [];

  // Focus nodes for smooth transitions
  final List<FocusNode> _focusNodes = [];

  final Map<String, bool> _interests = {
    '🎵 Âm nhạc': false,
    '⚽ Thể thao': false, 
    '✈️ Du lịch': false,
    '🎮 Game': false,
    '🍔 Ẩm thực': false,
    '💻 Công nghệ': false,
    '👗 Thời trang': false,
    '🎬 Phim ảnh': false,
  };

  @override
  void initState() {
    super.initState();
    
    // Initialize focus nodes
    for (int i = 0; i < 4; i++) {
      _focusNodes.add(FocusNode());
    }
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _textFieldController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    // Create staggered animations for text fields
    for (int i = 0; i < 4; i++) {
      _textFieldAnimations.add(
        Tween<Offset>(
          begin: const Offset(-1.0, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _textFieldController,
            curve: Interval(i * 0.1, 0.8 + (i * 0.05), curve: Curves.easeOutBack),
          ),
        ),
      );
    }

    _initializeUploadUrl();
    _loadUserProfile();
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    
    // Delay text field animations
    Future.delayed(const Duration(milliseconds: 400), () {
      _textFieldController.forward();
    });
    
    final authService = Provider.of<AuthService>(context, listen: false);
    _avatarUrl = authService.currentUser?.avatarUrl;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _textFieldController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
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
    } catch (e) {
      _showSnackBar('Lỗi kết nối: $e', isError: true);
    }
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
        _bankAccountController.text = user.bankAccountNumber ?? '';
        _bankNameController.text = user.bankName ?? '';
        
        _bankQrImageUrl = user.bankQrImageUrl;
        
        if (user.dateOfBirth != null && user.dateOfBirth!.isNotEmpty) {
          try {
            _selectedDateOfBirth = DateTime.parse(user.dateOfBirth!);
            _dobController.text = DateFormat('dd/MM/yyyy').format(_selectedDateOfBirth!);
          } catch (e) {
            try {
              _selectedDateOfBirth = DateFormat('dd/MM/yyyy').parse(user.dateOfBirth!);
              _dobController.text = user.dateOfBirth!;
            } catch (e2) {
            }
          }
        }
        
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
        
        // Reset interests và load từ user
        _interests.updateAll((key, value) => false);
        for (String interest in user.interests) {
          // Kiểm tra với emoji hoặc không có emoji
          String keyWithEmoji = _interests.keys.firstWhere(
            (k) => k.contains(interest) || interest.contains(k.split(' ').last), 
            orElse: () => '',
          );
          if (keyWithEmoji.isNotEmpty) {
            _interests[keyWithEmoji] = true;
          }
        }
        
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _showSnackBar('Lỗi khi tải thông tin: ${e.toString()}', isError: true);
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFFFF0000),
              surface: const Color(0xFF1F1F1F),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1F1F1F),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  bool _isValidQrImageFile(PlatformFile file) {
    final String fileName = file.name.toLowerCase();
    final List<String> validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    bool hasValidExtension = validExtensions.any((ext) => fileName.endsWith('.$ext'));
    if (!hasValidExtension) {
      _showSnackBar('Chỉ hỗ trợ file ảnh: ${validExtensions.join(', ')}', isError: true);
      return false;
    }
    int fileSize = kIsWeb ? (file.bytes?.length ?? 0) : (file.size);
    if (fileSize > _maxFileSize) {
      _showSnackBar('File quá lớn. Giới hạn: ${_maxFileSize ~/ (1024 * 1024)}MB', isError: true);
      return false;
    }
    if (fileSize == 0) {
      _showSnackBar('File rỗng hoặc không hợp lệ', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _pickQrImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        allowMultiple: false,
      );
      if (result != null) {
        final file = result.files.single;
        if (!_isValidQrImageFile(file)) {
          return;
        }
        setState(() {
          _selectedQrImageFile = file;
          _qrImageFileName = file.name;
        });
      } else {
        setState(() {
          _selectedQrImageFile = null;
          _qrImageFileName = null;
        });
      }
    } catch (e) {
      _showSnackBar('Lỗi khi chọn ảnh: $e', isError: true);
    }
  }

  Future<void> _uploadQrImage() async {
    if (_selectedQrImageFile == null) {
      _showSnackBar('Vui lòng chọn ảnh QR để tải lên.', isError: true);
      return;
    }
    if (_uploadUrl == null) {
      await _initializeUploadUrl();
      if (_uploadUrl == null) {
        _showSnackBar('Không xác định được URL tải lên. Vui lòng thử lại.', isError: true);
        return;
      }
    }
    setState(() => _isUploadingQr = true);
    var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl!));
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.id;
    if (userId != null) {
      request.fields['userId'] = userId;
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
          contentType: MediaType('image', _selectedQrImageFile!.path!.split('.').last),
        ),
      );
    } else {
      _showSnackBar('Không tìm thấy file ảnh QR hợp lệ để tải lên.', isError: true);
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
          _showSnackBar('Ảnh QR tải lên thành công!', isError: false);
        } else {
          _showSnackBar('Server không trả về URL ảnh QR', isError: true);
        }
      } else {
        String errorMessage = 'Tải ảnh QR thất bại. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {}
        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e) {
      String errorMessage = 'Lỗi tải ảnh QR: $e';
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname')) {
        errorMessage = 'Không thể kết nối tới server. Vui lòng kiểm tra kết nối mạng.';
        NetworkConfig.clearCache();
      }
      _showSnackBar(errorMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingQr = false);
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
              color: const Color(0xFF1F1F1F),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF0000))),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorPreview();
          },
        ),
      );
    } else if (kIsWeb && _selectedQrImageFile?.bytes != null) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _selectedQrImageFile!.bytes!,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorPreview();
            },
          ),
        );
      } catch (e) {
        return _buildErrorPreview();
      }
    } else if (!kIsWeb && _selectedQrImageFile?.path != null) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(_selectedQrImageFile!.path!),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorPreview();
            },
          ),
        );
      } catch (e) {
        return _buildErrorPreview();
      }
    } else {
      return _buildErrorPreview();
    }
  }

  Widget _buildErrorPreview() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, color: Colors.red, size: 24),
          SizedBox(height: 4),
          Text('Lỗi ảnh', style: TextStyle(fontSize: 10, color: Colors.red)),
        ],
      ),
    );
  }

  void _clearQrImage() {
    setState(() {
      _selectedQrImageFile = null;
      _qrImageFileName = null;
      _bankQrImageUrl = null;
    });
  }

  Future<void> _pickAvatarImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        allowMultiple: false,
      );
      if (result != null) {
        final file = result.files.single;
        setState(() {
          _selectedAvatarFile = file;
          _avatarFileName = file.name;
        });
      } else {
        setState(() {
          _selectedAvatarFile = null;
          _avatarFileName = null;
        });
      }
    } catch (e) {
      _showSnackBar('Lỗi khi chọn ảnh avatar: $e', isError: true);
    }
  }

  Future<void> _uploadAvatarImage() async {
    if (_selectedAvatarFile == null) {
      _showSnackBar('Vui lòng chọn ảnh avatar để tải lên.', isError: true);
      return;
    }
    
    final uploadUrl = await NetworkConfig.getBaseUrl('/api/users/upload-image');
    setState(() => _isUploadingAvatar = true);
    
    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    
    if (kIsWeb && _selectedAvatarFile!.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'imageFile',
        _selectedAvatarFile!.bytes!,
        filename: _avatarFileName ?? 'avatar_from_web.png',
        contentType: MediaType('image', _avatarFileName?.split('.').last ?? 'png'),
      ));
    } else if (!kIsWeb && _selectedAvatarFile!.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          _selectedAvatarFile!.path!,
          filename: _avatarFileName ?? _selectedAvatarFile!.path!.split(Platform.pathSeparator).last,
          contentType: MediaType('image', _selectedAvatarFile!.path!.split('.').last),
        ),
      );
    } else {
      _showSnackBar('Không tìm thấy file ảnh avatar hợp lệ để tải lên.', isError: true);
      setState(() => _isUploadingAvatar = false);
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
            _avatarUrl = data['imageUrl'];
            _selectedAvatarFile = null;
            _avatarFileName = null;
          });
          _showSnackBar('Avatar tải lên thành công!', isError: false);
        } else {
          _showSnackBar('Server không trả về URL avatar', isError: true);
        }
      } else {
        String errorMessage = 'Tải avatar thất bại. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {}
        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e) {
      String errorMessage = 'Lỗi tải avatar: $e';
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname')) {
        errorMessage = 'Không thể kết nối tới server. Vui lòng kiểm tra kết nối mạng.';
        NetworkConfig.clearCache();
      }
      _showSnackBar(errorMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Widget _buildAvatarPreview() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF0000).withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFCC0000).withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        width: 120,
        height: 120,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF1F1F1F),
        ),
        child: ClipOval(
          child: _getAvatarWidget(),
        ),
      ),
    );
  }

  Widget _getAvatarWidget() {
    if (_avatarUrl != null) {
      return Image.network(
        _avatarUrl!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _defaultAvatar(),
      );
    } else if (kIsWeb && _selectedAvatarFile?.bytes != null) {
      return Image.memory(
        _selectedAvatarFile!.bytes!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _defaultAvatar(),
      );
    } else if (!kIsWeb && _selectedAvatarFile?.path != null) {
      return Image.file(
        File(_selectedAvatarFile!.path!),
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _defaultAvatar(),
      );
    } else {
      return _defaultAvatar();
    }
  }

  Widget _defaultAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.grey[700]!, Colors.grey[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.person, size: 60, color: Colors.grey),
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
      final success = await _profileService.updateProfileWithBankAndImage(
        userId: authService.currentUser!.id,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        gender: _selectedGender?.name,
        interests: _interests.entries.where((e) => e.value).map((e) => e.key).toList(),
        bankAccountNumber: _bankAccountController.text.trim().isEmpty ? null : _bankAccountController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
        bankQrImageUrl: _bankQrImageUrl,
        bankImageUrl: null,
        avatarUrl: _avatarUrl,
      );
      if (mounted) {
        if (success) {
          await authService.refreshUserData();
          _showSnackBar('Hồ sơ đã được cập nhật thành công!', isError: false);
          Navigator.pop(context, authService.currentUser?.avatarUrl);
        } else {
          _showSnackBar('Cập nhật hồ sơ thất bại', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi khi lưu: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? const Color(0xFFFF0000) : const Color(0xFF00C851),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required int index,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return SlideTransition(
      position: _textFieldAnimations[index],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: enabled ? const Color(0xFF1F1F1F) : const Color(0xFF151515),
          border: Border.all(
            color: _focusNodes[index].hasFocus 
                ? const Color(0xFFFF0000) 
                : Colors.grey[700]!,
            width: _focusNodes[index].hasFocus ? 2 : 1,
          ),
          boxShadow: [
            if (_focusNodes[index].hasFocus)
              BoxShadow(
                color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          focusNode: _focusNodes[index],
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          enabled: enabled,
          onTap: onTap,
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.w500, 
            color: enabled ? Colors.white : Colors.grey[500],
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey[500], 
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon, 
                color: _focusNodes[index].hasFocus 
                    ? const Color(0xFFFF0000) 
                    : Colors.grey[500],
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            fillColor: Colors.transparent,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(29),
        gradient: onPressed != null 
            ? const LinearGradient(
                colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : LinearGradient(
                colors: [Colors.grey[600]!, Colors.grey[500]!],
              ),
        boxShadow: onPressed != null ? [
          BoxShadow(
            color: const Color(0xFFFF0000).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ] : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 26,
                width: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildGlassMorphicContainer({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 20),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1F1F1F).withValues(alpha: 0.8),
        border: Border.all(
          color: Colors.grey[700]!.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
          ).createShader(bounds),
          child: const Text(
            'Chỉnh Sửa Hồ Sơ',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF0000),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          
                          // Avatar Section
                          Center(
                            child: Stack(
                              children: [
                                _buildAvatarPreview(),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                                      onPressed: _pickAvatarImage,
                                    ),
                                  ),
                                ),
                                if (_selectedAvatarFile != null)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 8,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.cloud_upload, color: Colors.white, size: 20),
                                        onPressed: _isUploadingAvatar ? null : _uploadAvatarImage,
                                      ),
                                    ),
                                  ),
                                if (_avatarUrl != null)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF0000),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 8,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                        onPressed: () => setState(() { _avatarUrl = null; }),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Form Fields
                          _buildCustomTextField(
                            controller: _usernameController,
                            hintText: 'Tên người dùng',
                            icon: Icons.person_outline,
                            index: 0,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập tên người dùng';
                              }
                              return null;
                            },
                          ),
                          
                          _buildCustomTextField(
                            controller: _emailController,
                            hintText: 'Email (không thể thay đổi)',
                            icon: Icons.email_outlined,
                            index: 1,
                            keyboardType: TextInputType.emailAddress,
                            enabled: false,
                          ),
                          
                          _buildCustomTextField(
                            controller: _dobController,
                            hintText: 'Ngày sinh (dd/mm/yyyy)',
                            icon: Icons.calendar_today_outlined,
                            index: 2,
                            readOnly: true,
                            onTap: () => _selectDate(context),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Vui lòng chọn ngày sinh';
                              return null;
                            },
                          ),
                          
                          // Gender Selection
                          _buildGlassMorphicContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Giới tính",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.grey[300],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: Gender.values.map((gender) {
                                    String genderText = '';
                                    IconData genderIcon = Icons.person;
                                    switch (gender) {
                                      case Gender.male:
                                        genderText = 'Nam';
                                        genderIcon = Icons.male;
                                        break;
                                      case Gender.female:
                                        genderText = 'Nữ';
                                        genderIcon = Icons.female;
                                        break;
                                      case Gender.other:
                                        genderText = 'Khác';
                                        genderIcon = Icons.transgender;
                                        break;
                                    }
                                    return Expanded(
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          color: _selectedGender == gender 
                                              ? const Color(0xFFFF0000) 
                                              : const Color(0xFF151515),
                                          border: Border.all(
                                            color: _selectedGender == gender 
                                                ? const Color(0xFFFF0000) 
                                                : Colors.grey[600]!,
                                            width: _selectedGender == gender ? 2 : 1,
                                          ),
                                          boxShadow: _selectedGender == gender ? [
                                            BoxShadow(
                                              color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ] : null,
                                        ),
                                        child: InkWell(
                                          onTap: () => setState(() => _selectedGender = gender),
                                          borderRadius: BorderRadius.circular(16),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  genderIcon,
                                                  color: _selectedGender == gender 
                                                      ? Colors.white 
                                                      : Colors.grey[500],
                                                  size: 28,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  genderText,
                                                  style: TextStyle(
                                                    color: _selectedGender == gender 
                                                        ? Colors.white 
                                                        : Colors.grey[400],
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          
                          // Interests Section
                          _buildGlassMorphicContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Sở thích của bạn",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.grey[300],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 2.5,
                                  children: _interests.keys.map((String key) {
                                    bool isSelected = _interests[key]!;
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          _interests[key] = !isSelected;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(25),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(25),
                                          gradient: isSelected ? const LinearGradient(
                                            colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ) : null,
                                          color: isSelected ? null : const Color(0xFF151515),
                                          border: Border.all(
                                            color: isSelected 
                                                ? Colors.transparent 
                                                : Colors.grey[600]!,
                                            width: 1,
                                          ),
                                          boxShadow: isSelected ? [
                                            BoxShadow(
                                              color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                              offset: const Offset(0, 4),
                                            ),
                                          ] : [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              blurRadius: 5,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            key,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : Colors.grey[400],
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          
                          // Bank Information Section
                          _buildGlassMorphicContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thông tin ngân hàng (tùy chọn)', 
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.grey[300],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Bank Name Field
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: const Color(0xFF151515),
                                    border: Border.all(color: Colors.grey[700]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextFormField(
                                    controller: _bankNameController,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                    decoration: InputDecoration(
                                      hintText: 'Tên ngân hàng',
                                      hintStyle: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w400),
                                      prefixIcon: const Icon(Icons.account_balance, color: Color(0xFFFF0000)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      fillColor: Colors.transparent,
                                      filled: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    ),
                                  ),
                                ),
                                
                                // Bank Account Field
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: const Color(0xFF151515),
                                    border: Border.all(color: Colors.grey[700]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextFormField(
                                    controller: _bankAccountController,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                    decoration: InputDecoration(
                                      hintText: 'Số tài khoản ngân hàng',
                                      hintStyle: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w400),
                                      prefixIcon: const Icon(Icons.credit_card, color: Color(0xFFFF0000)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      fillColor: Colors.transparent,
                                      filled: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    ),
                                  ),
                                ),
                                
                                // QR Code Section
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF151515),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFFF0000).withValues(alpha: 0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF0000).withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.qr_code, color: Colors.white, size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Mã QR thanh toán',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[300],
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Pick QR Button
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: _pickQrImage,
                                          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                                          label: const Text('Chọn ảnh QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      // QR Preview and Upload
                                      if (_selectedQrImageFile != null || _bankQrImageUrl != null)
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1F1F1F),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey[700]!),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Ảnh QR đã chọn:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[300],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
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
                                                              const Icon(Icons.image, color: Color(0xFFFF0000), size: 16),
                                                              const SizedBox(width: 8),
                                                              Expanded(
                                                                child: Text(
                                                                  _qrImageFileName!,
                                                                  style: TextStyle(
                                                                    fontWeight: FontWeight.w500, 
                                                                    fontSize: 14,
                                                                    color: Colors.grey[300],
                                                                  ),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 12),
                                                        ],
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Container(
                                                                decoration: BoxDecoration(
                                                                  borderRadius: BorderRadius.circular(8),
                                                                  gradient: const LinearGradient(
                                                                    colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                                                                  ),
                                                                ),
                                                                child: ElevatedButton.icon(
                                                                  icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                                                                  label: const Text('Tải lên', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                                  onPressed: (_selectedQrImageFile != null && !_isUploadingQr && _uploadUrl != null) ? _uploadQrImage : null,
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor: Colors.transparent,
                                                                    shadowColor: Colors.transparent,
                                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Container(
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFF0000).withValues(alpha: 0.8),
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                              child: IconButton(
                                                                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                                                onPressed: _clearQrImage,
                                                                tooltip: 'Xóa ảnh',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        if (_isUploadingQr) ...[
                                                          const SizedBox(height: 12),
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(4),
                                                              color: const Color(0xFF151515),
                                                            ),
                                                            child: const LinearProgressIndicator(
                                                              backgroundColor: Color(0xFF151515),
                                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            'Đang tải ảnh lên...',
                                                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      
                                      const SizedBox(height: 12),
                                      Text(
                                        'Hỗ trợ: JPG, JPEG, PNG, GIF, WEBP\nKích thước tối đa: 5MB',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Save Button
                          _buildGradientButton(
                            text: 'Lưu Thay Đổi',
                            onPressed: _isSaving ? null : _saveProfile,
                            isLoading: _isSaving,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Cancel Button
                          Container(
                            height: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(29),
                              border: Border.all(color: Colors.grey[600]!, width: 2),
                            ),
                            child: TextButton(
                              onPressed: _isSaving ? null : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
                              ),
                              child: Text(
                                'Hủy',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
