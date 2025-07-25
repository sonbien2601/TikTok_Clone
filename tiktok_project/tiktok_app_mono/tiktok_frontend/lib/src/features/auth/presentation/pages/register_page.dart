import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/auth/presentation/pages/login_page.dart';
import 'package:tiktok_frontend/src/features/auth/presentation/widgets/auth_text_field.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:tiktok_frontend/src/core/navigation/main_tab_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum Gender { male, female, other }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  String? _verificationId;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isLoading = false;
  DateTime? _selectedDateOfBirth;
  bool _isOver18 = false;
  Gender? _selectedGender;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _textFieldController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  List<Animation<Offset>> _textFieldAnimations = [];

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

  // Avatar variables
  PlatformFile? _selectedAvatarFile;
  String? _avatarFileName;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  // Focus nodes for smooth transitions
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize focus nodes
    for (int i = 0; i < 6; i++) {
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
    for (int i = 0; i < 6; i++) {
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

    _fadeController.forward();
    _slideController.forward();
    
    // Delay text field animations
    Future.delayed(const Duration(milliseconds: 400), () {
      _textFieldController.forward();
    });
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
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
              surface: const Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
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
            color: const Color(0xFFFF0000).withValues(alpha: 0.2),
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
          colors: [const Color(0xFF404040), const Color(0xFF2A2A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.person, size: 60, color: Colors.grey),
    );
  }

  Future<void> _sendOtp() async {
    setState(() { _isSendingOtp = true; });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          setState(() { _otpVerified = true; });
        },
        verificationFailed: (FirebaseAuthException e) {
          _showSnackBar('Gửi OTP thất bại: ${e.message}', isError: true);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
          });
          _showSnackBar('Đã gửi mã OTP về điện thoại.', isError: false);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() { _verificationId = verificationId; });
        },
      );
    } finally {
      setState(() { _isSendingOtp = false; });
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;
    setState(() { _isVerifyingOtp = true; });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() { _otpVerified = true; });
      _showSnackBar('Xác thực OTP thành công!', isError: false);
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Xác thực OTP thất bại: ${e.message}', isError: true);
    } finally {
      setState(() { _isVerifyingOtp = false; });
    }
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDateOfBirth == null) {
      _showSnackBar('Vui lòng chọn ngày sinh của bạn', isError: true);
      return;
    }

    if (!_isOver18) {
      _showSnackBar('Bạn phải xác nhận trên 18 tuổi để đăng ký', isError: true);
      return;
    }

    if (_selectedGender == null) {
      _showSnackBar('Vui lòng chọn giới tính của bạn', isError: true);
      return;
    }

    if (!_otpVerified) {
      _showSnackBar('Vui lòng xác thực số điện thoại bằng OTP!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    List<String> selectedInterestsList = [];
    _interests.forEach((interest, isSelected) {
      if (isSelected) selectedInterestsList.add(interest);
    });

    try {
      bool registrationSuccess = await Provider.of<AuthService>(context, listen: false).registerWithBank(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _selectedDateOfBirth,
        _selectedGender?.toString().split('.').last,
        selectedInterestsList,
        _avatarUrl,
        null,
        null,
        null
      );

      if (mounted && registrationSuccess) {
        await Provider.of<AuthService>(context, listen: false)
            .login(_emailController.text.trim(), _passwordController.text);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainTabPage()),
          (Route<dynamic> route) => false,
        );
        return;
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Đăng ký thất bại: ${e.toString().replaceFirst("Exception: ", "")}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
  }) {
    return SlideTransition(
      position: _textFieldAnimations[index],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1F1F1F),
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
              color: Colors.black.withOpacity(0.3),
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
          onTap: onTap,
          style: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.w500, 
            color: Colors.white,
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
          BoxShadow(
            color: const Color(0xFFFF0000).withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 4),
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
          color: Colors.grey[700]!.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Header
                    Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                          ).createShader(bounds),
                          child: const Text(
                            'Tạo Tài Khoản',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tham gia cộng đồng của chúng tôi!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
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
                                  color: Colors.red,
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
                        if (value == null || value.isEmpty) return 'Vui lòng nhập tên người dùng';
                        return null;
                      },
                    ),
                    
                    _buildCustomTextField(
                      controller: _emailController,
                      hintText: 'Email',
                      icon: Icons.email_outlined,
                      index: 1,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Vui lòng nhập email';
                        if (!value.contains('@') || !value.contains('.')) return 'Vui lòng nhập email hợp lệ';
                        return null;
                      },
                    ),
                    
                    _buildCustomTextField(
                      controller: _phoneController,
                      hintText: 'Số điện thoại',
                      icon: Icons.phone,
                      index: 2,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Vui lòng nhập số điện thoại';
                        if (!RegExp(r'^\+?\d{9,15}$').hasMatch(value)) return 'Số điện thoại không hợp lệ';
                        return null;
                      },
                    ),
                    
                    // OTP Section
                    _buildGlassMorphicContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xác thực số điện thoại',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.grey[300],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFF1A1A1A),
                                    border: Border.all(color: Colors.grey[600]!),
                                  ),
                                  child: TextFormField(
                                    controller: _otpController,
                                    decoration: InputDecoration(
                                      hintText: 'Nhập mã OTP',
                                      hintStyle: TextStyle(color: Colors.grey[500]),
                                      prefixIcon: const Icon(Icons.sms, color: Color(0xFFFF0000)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      fillColor: Colors.transparent,
                                      filled: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    enabled: _otpSent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
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
                                child: ElevatedButton(
                                  onPressed: _isSendingOtp ? null : _sendOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  child: _isSendingOtp 
                                      ? const SizedBox(
                                          width: 16, 
                                          height: 16, 
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Gửi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
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
                                child: ElevatedButton(
                                  onPressed: (_otpSent && !_isVerifyingOtp) ? _verifyOtp : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  child: _isVerifyingOtp 
                                      ? const SizedBox(
                                          width: 16, 
                                          height: 16, 
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Xác thực', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          if (_otpVerified)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Số điện thoại đã xác thực!',
                                    style: TextStyle(
                                      color: Colors.green[400],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    _buildCustomTextField(
                      controller: _dobController,
                      hintText: 'Ngày sinh (dd/mm/yyyy)',
                      icon: Icons.calendar_today_outlined,
                      index: 3,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Vui lòng chọn ngày sinh';
                        return null;
                      },
                    ),
                    
                    // Age Confirmation
                    _buildGlassMorphicContainer(
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isOver18 ? const Color(0xFFFF0000) : Colors.grey[600]!,
                                width: 2,
                              ),
                              color: _isOver18 ? const Color(0xFFFF0000) : Colors.transparent,
                            ),
                            child: _isOver18
                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isOver18 = !_isOver18;
                                });
                              },
                              child: Text(
                                "Tôi xác nhận mình trên 18 tuổi",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[300],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                                        : const Color(0xFF1A1A1A),
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
                                    color: isSelected ? null : const Color(0xFF1A1A1A),
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
                                        color: Colors.black.withOpacity(0.2),
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
                    
                    // Password Fields
                    _buildCustomTextField(
                      controller: _passwordController,
                      hintText: 'Mật khẩu',
                      icon: Icons.lock_outline,
                      index: 4,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                        if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                        return null;
                      },
                    ),
                    
                    _buildCustomTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Xác nhận mật khẩu',
                      icon: Icons.lock_reset_outlined,
                      index: 5,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                        if (value != _passwordController.text) return 'Mật khẩu không khớp';
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Register Button
                    _buildGradientButton(
                      text: 'Đăng Ký',
                      onPressed: _isLoading ? null : _register,
                      isLoading: _isLoading,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Đã có tài khoản? ",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (!_isLoading) {
                              Navigator.pushReplacement(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
                                  transitionDuration: const Duration(milliseconds: 600),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    const begin = Offset(1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOutCubic;
                                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                    return SlideTransition(
                                      position: animation.drive(tween),
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          },
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                            ).createShader(bounds),
                            child: const Text(
                              'Đăng nhập',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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