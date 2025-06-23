// tiktok_frontend/lib/src/features/profile/presentation/pages/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/profile/domain/services/profile_service.dart';

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
    _loadUserProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
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
      final success = await _profileService.updateProfile(
        userId: authService.currentUser!.id,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        gender: _selectedGender?.toString().split('.').last,
        interests: selectedInterestsList,
      );

      if (mounted) {
        if (success) {
          // Refresh auth service to get updated user data
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