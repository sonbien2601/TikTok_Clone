// tiktok_frontend/lib/src/features/auth/presentation/pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/auth/presentation/pages/login_page.dart';
import 'package:tiktok_frontend/src/features/auth/presentation/widgets/auth_text_field.dart';

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
    'Âm nhạc': false, 'Thể thao': false, 'Du lịch': false,
    'Game': false, 'Ẩm thực': false,
  };

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

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Các kiểm tra _selectedDateOfBirth, _isOver18 (ở UI), _selectedGender giữ nguyên
    if (_selectedDateOfBirth == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ngày sinh của bạn')));
      return;
    }
    // Validator của FormField<bool> cho _isOver18 sẽ xử lý việc này, nhưng kiểm tra lại ở đây cũng tốt
    if (!_isOver18) { 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn phải xác nhận trên 18 tuổi để đăng ký')));
      return;
    }

    if (_selectedGender == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn giới tính của bạn')));
      return;
    }

    setState(() => _isLoading = true);

    List<String> selectedInterestsList = [];
    _interests.forEach((interest, isSelected) {
      if (isSelected) selectedInterestsList.add(interest);
    });

    try {
      // SỬA LỜI GỌI HÀM Ở ĐÂY cho đúng 6 tham số
      bool registrationSuccess = await Provider.of<AuthService>(context, listen: false).register(
        _usernameController.text.trim(),               // 1. username
        _emailController.text.trim(),                  // 2. email
        _passwordController.text,                      // 3. password
        _selectedDateOfBirth,                          // 4. dateOfBirth
        _selectedGender?.toString().split('.').last, // 5. gender (String?)
        selectedInterestsList,                         // 6. interests (List<String>)
        // Không còn tham số isOver18 ở đây
      );

      if (mounted && registrationSuccess) { 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thành công! Vui lòng đăng nhập.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1500)); 
        if (mounted) {
            // Chuyển sang LoginPage và xóa tất cả các route trước đó khỏi stack
            // để người dùng không thể back lại RegisterPage sau khi đăng ký thành công
            Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (Route<dynamic> route) => false, // Xóa tất cả các route trước đó
            );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng ký thất bại: ${e.toString().replaceFirst("Exception: ", "")}')),
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
    // UI của build method giữ nguyên như Response #123
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
                AuthTextField(controller: _usernameController, hintText: 'Username', prefixIcon: Icons.person_outline, validator: (value) { if (value == null || value.isEmpty) return 'Please enter a username'; return null; }),
                AuthTextField(controller: _emailController, hintText: 'Email', prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (value) { if (value == null || value.isEmpty) return 'Please enter your email'; if (!value.contains('@') || !value.contains('.')) return 'Please enter a valid email'; return null; }),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextFormField(
                    controller: _dobController, readOnly: true, 
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.calendar_today_outlined), hintText: 'Ngày sinh (dd/mm/yyyy)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)), filled: true, fillColor: Colors.grey[200]?.withOpacity(0.7)),
                    onTap: () => _selectDate(context),
                    validator: (value) { if (value == null || value.isEmpty) return 'Vui lòng chọn ngày sinh'; return null; },
                  ),
                ),
                FormField<bool>(
                  initialValue: _isOver18,
                  validator: (value) { if (value == null || !value) return 'Bạn phải xác nhận trên 18 tuổi'; return null; },
                  builder: (formFieldState) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CheckboxListTile(
                          title: const Text("Tôi xác nhận mình trên 18 tuổi"), value: _isOver18,
                          onChanged: (bool? newValue) { setState(() { _isOver18 = newValue ?? false; formFieldState.didChange(_isOver18); }); },
                          controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, dense: true, activeColor: Theme.of(context).primaryColor,
                        ),
                        if (formFieldState.hasError) Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Text(formFieldState.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                          ),
                      ],);},
                ),
                const SizedBox(height: 8),
                Text("Giới tính:", style: Theme.of(context).textTheme.titleSmall),
                Column(
                  children: Gender.values.map((gender) {
                    return RadioListTile<Gender>(
                      title: Text(gender.toString().split('.').last[0].toUpperCase() + gender.toString().split('.').last.substring(1)),
                      value: gender, groupValue: _selectedGender,
                      onChanged: (Gender? value) { setState(() { _selectedGender = value; }); },
                      dense: true, contentPadding: EdgeInsets.zero,
                    );}).toList(),
                ),
                const SizedBox(height: 8),
                Text("Sở thích:", style: Theme.of(context).textTheme.titleSmall),
                Wrap(
                  spacing: 4.0, runSpacing: 0.0,
                  children: _interests.keys.map((String key) {
                    return SizedBox(width: MediaQuery.of(context).size.width / 2 - 30,
                      child: CheckboxListTile(
                        title: Text(key, style: const TextStyle(fontSize: 14)), 
                        value: _interests[key],
                        onChanged: (bool? value) { setState(() { _interests[key] = value ?? false; }); },
                        controlAffinity: ListTileControlAffinity.leading, dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      ),);}).toList(),
                ),
                const SizedBox(height: 16),
                AuthTextField(controller: _passwordController, hintText: 'Password', obscureText: true, prefixIcon: Icons.lock_outline, validator: (value) { if (value == null || value.isEmpty) return 'Please enter a password'; if (value.length < 6) return 'Password must be at least 6 characters'; return null; }),
                AuthTextField(controller: _confirmPasswordController, hintText: 'Confirm Password', obscureText: true, prefixIcon: Icons.lock_reset_outlined, validator: (value) { if (value == null || value.isEmpty) return 'Please confirm your password'; if (value != _passwordController.text) return 'Passwords do not match'; return null; }),
                const SizedBox(height: 24),
                _isLoading ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
                        onPressed: _register, child: const Text('Sign Up'),
                      ),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Already have an account?"),
                    TextButton(onPressed: () { if (!_isLoading) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())); }, child: const Text('Login')),
                  ],),
              ],
            ),
          ),
        ),
      ),
    );
  }
}