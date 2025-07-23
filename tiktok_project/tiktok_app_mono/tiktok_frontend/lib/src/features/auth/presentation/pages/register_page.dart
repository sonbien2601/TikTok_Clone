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

enum Gender { male, female, other }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dobController = TextEditingController();

  bool _isLoading = false;
  DateTime? _selectedDateOfBirth;
  bool _isOver18 = false;
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

  // 1. Thêm biến cho avatar
  PlatformFile? _selectedAvatarFile;
  String? _avatarFileName;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    super.dispose();
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

  // 2. Hàm chọn avatar
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn ảnh avatar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 3. Hàm upload avatar
  Future<void> _uploadAvatarImage() async {
    if (_selectedAvatarFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ảnh avatar để tải lên.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy file ảnh avatar hợp lệ để tải lên.')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar tải lên thành công!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server không trả về URL avatar'), backgroundColor: Colors.red),
          );
        }
      } else {
        String errorMessage = 'Tải avatar thất bại. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      String errorMessage = 'Lỗi tải avatar: $e';
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname')) {
        errorMessage = 'Không thể kết nối tới server. Vui lòng kiểm tra kết nối mạng.';
        NetworkConfig.clearCache();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  // 4. Widget preview avatar
  Widget _buildAvatarPreview() {
    if (_avatarUrl != null) {
      return ClipOval(
        child: Image.network(
          _avatarUrl!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const CircleAvatar(radius: 50, child: Icon(Icons.person)),
        ),
      );
    } else if (kIsWeb && _selectedAvatarFile?.bytes != null) {
      return ClipOval(
        child: Image.memory(
          _selectedAvatarFile!.bytes!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const CircleAvatar(radius: 50, child: Icon(Icons.person)),
        ),
      );
    } else if (!kIsWeb && _selectedAvatarFile?.path != null) {
      return ClipOval(
        child: Image.file(
          File(_selectedAvatarFile!.path!),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const CircleAvatar(radius: 50, child: Icon(Icons.person)),
        ),
      );
    } else {
      return const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50));
    }
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDateOfBirth == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ngày sinh của bạn')),
        );
      }
      return;
    }

    if (!_isOver18) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn phải xác nhận trên 18 tuổi để đăng ký')),
        );
      }
      return;
    }

    if (_selectedGender == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn giới tính của bạn')),
        );
      }
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
        _avatarUrl, // Gửi avatarUrl vào backend
        null, // Xóa tên ngân hàng
        null, // Xóa ảnh QR
        null,
      );

      if (mounted && registrationSuccess) {
        // Tự động đăng nhập luôn
        await Provider.of<AuthService>(context, listen: false)
            .login(_emailController.text.trim(), _passwordController.text);
        // Chuyển sang trang chính
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainTabPage()),
          (Route<dynamic> route) => false,
        );
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng ký thất bại: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Create Account', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Join our community!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 24),
                // Thêm UI chọn avatar
                Center(
                  child: Stack(
                    children: [
                      _buildAvatarPreview(),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.photo_camera, color: Colors.blue),
                              onPressed: _pickAvatarImage,
                              tooltip: 'Chọn ảnh avatar',
                            ),
                            if (_selectedAvatarFile != null)
                              IconButton(
                                icon: const Icon(Icons.cloud_upload, color: Colors.green),
                                onPressed: _isUploadingAvatar ? null : _uploadAvatarImage,
                                tooltip: 'Tải lên',
                              ),
                            if (_avatarUrl != null)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => setState(() { _avatarUrl = null; }),
                                tooltip: 'Xóa avatar',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Basic Information
                AuthTextField(controller: _usernameController, hintText: 'Username', prefixIcon: Icons.person_outline, validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a username';
                  return null;
                }),
                AuthTextField(controller: _emailController, hintText: 'Email', prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your email';
                  if (!value.contains('@') || !value.contains('.')) return 'Please enter a valid email';
                  return null;
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        hintText: 'Ngày sinh (dd/mm/yyyy)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                        filled: true,
                        fillColor: Colors.grey[200]?.withOpacity(0.7)),
                    onTap: () => _selectDate(context),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng chọn ngày sinh';
                      return null;
                    },
                  ),
                ),
                FormField<bool>(
                  initialValue: _isOver18,
                  validator: (value) {
                    if (value == null || !value) return 'Bạn phải xác nhận trên 18 tuổi';
                    return null;
                  },
                  builder: (formFieldState) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CheckboxListTile(
                        title: const Text("Tôi xác nhận mình trên 18 tuổi"),
                        value: _isOver18,
                        onChanged: (bool? newValue) {
                          setState(() {
                            _isOver18 = newValue ?? false;
                            formFieldState.didChange(_isOver18);
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: Theme.of(context).primaryColor,
                      ),
                      if (formFieldState.hasError)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Text(formFieldState.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                        ),
                    ]);
                  },
                ),
                const SizedBox(height: 8),
                Text("Giới tính:", style: Theme.of(context).textTheme.titleSmall),
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
                const SizedBox(height: 8),
                Text("Sở thích:", style: Theme.of(context).textTheme.titleSmall),
                Wrap(
                  spacing: 4.0,
                  runSpacing: 0.0,
                  children: _interests.keys.map((String key) {
                    return SizedBox(
                      width: MediaQuery.of(context).size.width / 2 - 30,
                      child: CheckboxListTile(
                        title: Text(key, style: const TextStyle(fontSize: 14)),
                        value: _interests[key],
                        onChanged: (bool? value) {
                          setState(() {
                            _interests[key] = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                    controller: _passwordController,
                    hintText: 'Password',
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter a password';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    }),
                AuthTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm Password',
                    obscureText: true,
                    prefixIcon: Icons.lock_reset_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please confirm your password';
                      if (value != _passwordController.text) return 'Passwords do not match';
                      return null;
                    }),
                const SizedBox(height: 24),

                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
                        onPressed: _register,
                        child: const Text('Sign Up'),
                      ),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Already have an account?"),
                  TextButton(
                      onPressed: () {
                        if (!_isLoading) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                      },
                      child: const Text('Login')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}