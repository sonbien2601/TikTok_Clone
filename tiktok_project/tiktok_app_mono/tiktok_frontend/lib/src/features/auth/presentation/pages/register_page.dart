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
  final _bankAccountController = TextEditingController();
  final _bankNameController = TextEditingController();

  // Upload variables for QR image
  PlatformFile? _selectedQrImageFile;
  String? _qrImageFileName;
  String? _uploadUrl;
  String? _bankQrImageUrl;
  String? _debugInfo;
  bool _isUploadingQr = false;

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

  @override
  void initState() {
    super.initState();
    _initializeUploadUrl();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

      print('[RegisterPage] Initialized upload URL: $_uploadUrl');
    } catch (e) {
      print('[RegisterPage] Error initializing upload URL: $e');
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
          print('[RegisterPage] QR Image selected: $_qrImageFileName');
        });
      } else {
        print('[RegisterPage] No QR image selected.');
        setState(() {
          _selectedQrImageFile = null;
          _qrImageFileName = null;
        });
      }
    } catch (e) {
      print('[RegisterPage] Error picking QR image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting QR image: $e')),
        );
      }
    }
  }

  Future<void> _uploadQrImage() async {
    if (_selectedQrImageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a QR image to upload.')),
        );
      }
      return;
    }

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
          const SnackBar(content: Text('Could not find valid QR image file to upload.')),
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
              content: Text('QR Image uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Server did not return QR image URL'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        String errorMessage = 'QR Image upload failed. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('[RegisterPage] Error uploading QR image: $e');
      if (mounted) {
        String errorMessage = 'Error uploading QR image: $e';
        if (e.toString().contains('Connection refused') ||
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('No address associated with hostname')) {
          errorMessage = 'Cannot connect to server. Please check your network connection.';
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

  void _clearQrImage() {
    setState(() {
      _selectedQrImageFile = null;
      _qrImageFileName = null;
      _bankQrImageUrl = null;
    });
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
        _bankAccountController.text.trim().isEmpty ? null : _bankAccountController.text.trim(),
        _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
        _bankQrImageUrl,
        null,
      );

      if (mounted && registrationSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thành công! Vui lòng đăng nhập.'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
        }
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

                // Connection Status Card
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

                // Bank information section
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
                      AuthTextField(
                          controller: _bankAccountController,
                          hintText: 'Số tài khoản ngân hàng',
                          prefixIcon: Icons.account_balance,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            return null;
                          }),
                      AuthTextField(
                          controller: _bankNameController,
                          hintText: 'Tên ngân hàng',
                          prefixIcon: Icons.account_balance_wallet,
                          validator: (value) {
                            return null;
                          }),
                      const SizedBox(height: 16),

                      // QR Image section
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
                                textStyle: const TextStyle(fontSize: 16),
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
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
                                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
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

                      const SizedBox(height: 8),
                      Text(
                        'Supported formats: JPG, JPEG, PNG, GIF, WEBP\nMax size: 5MB',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

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