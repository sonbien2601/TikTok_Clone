// tiktok_frontend/lib/src/features/auth/presentation/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/features/auth/presentation/pages/register_page.dart';
import 'package:tiktok_frontend/src/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _textFieldController;
  late AnimationController _logoController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _logoRotation;
  List<Animation<Offset>> _textFieldAnimations = [];

  // Focus nodes for smooth transitions
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize focus nodes
    for (int i = 0; i < 2; i++) {
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
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _logoRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Create staggered animations for text fields
    for (int i = 0; i < 2; i++) {
      _textFieldAnimations.add(
        Tween<Offset>(
          begin: const Offset(-1.0, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _textFieldController,
            curve: Interval(i * 0.2, 0.8 + (i * 0.1), curve: Curves.easeOutBack),
          ),
        ),
      );
    }

    _fadeController.forward();
    _slideController.forward();
    _logoController.forward();
    
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
    _logoController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await Provider.of<AuthService>(context, listen: false)
            .login(_emailController.text, _passwordController.text);
      } catch (e) {
        if (mounted) {
          _showSnackBar('Đăng nhập thất bại: ${e.toString()}', isError: true);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
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
  }) {
    return SlideTransition(
      position: _textFieldAnimations[index],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1F1F1F),
          border: Border.all(
            color: _focusNodes[index].hasFocus 
                ? const Color(0xFFFF0000) 
                : const Color(0xFF333333),
            width: _focusNodes[index].hasFocus ? 2 : 1,
          ),
          boxShadow: [
            if (_focusNodes[index].hasFocus)
              BoxShadow(
                                                color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
          style: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.w500, 
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF888888), 
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon, 
                color: _focusNodes[index].hasFocus 
                    ? const Color(0xFFFF0000) 
                    : const Color(0xFF888888),
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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

  Widget _buildYouTubeButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: onPressed != null 
            ? const Color(0xFFFF0000)
            : const Color(0xFF555555),
        boxShadow: onPressed != null ? [
          BoxShadow(
            color: const Color(0xFFFF0000).withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ] : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
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

  Widget _buildSocialButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
        color: const Color(0xFF1F1F1F),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
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
                    const SizedBox(height: 60),
                    
                    // YouTube Shorts Logo Animation
                    Center(
                      child: AnimatedBuilder(
                        animation: _logoRotation,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _logoRotation.value * 0.1,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF0000),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF0000).withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Header
                    Column(
                      children: [
                        const Text(
                          'Chào Mừng Trở Lại!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Đăng nhập vào',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF888888),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'YouTube ',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFFFF0000),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: 'Shorts',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // Form Fields
                    _buildCustomTextField(
                      controller: _emailController,
                      hintText: 'Email hoặc tên người dùng',
                      icon: Icons.person_outline,
                      index: 0,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập email hoặc tên người dùng';
                        }
                        return null;
                      },
                    ),
                    
                    _buildCustomTextField(
                      controller: _passwordController,
                      hintText: 'Mật khẩu',
                      icon: Icons.lock_outline,
                      index: 1,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        if (value.length < 6) {
                          return 'Mật khẩu phải có ít nhất 6 ký tự';
                        }
                        return null;
                      },
                    ),
                    
                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implement forgot password
                        },
                        child: const Text(
                          'Quên mật khẩu?',
                          style: TextStyle(
                            color: Color(0xFFFF0000),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Login Button
                    _buildYouTubeButton(
                      text: 'Đăng Nhập',
                      onPressed: _isLoading ? null : _login,
                      isLoading: _isLoading,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Hoặc tiếp tục với',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Social Login Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildSocialButton(
                            text: 'Google',
                            icon: Icons.g_mobiledata,
                            onPressed: () {
                              // TODO: Implement Google login
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSocialButton(
                            text: 'Facebook',
                            icon: Icons.facebook,
                            onPressed: () {
                              // TODO: Implement Facebook login
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Chưa có tài khoản? ",
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 16,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (!_isLoading) {
                              Navigator.pushReplacement(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const RegisterPage(),
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
                          child: const Text(
                            'Đăng ký',
                            style: TextStyle(
                              color: Color(0xFFFF0000),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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