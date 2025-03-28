import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../../core/utils/validators/password_validator.dart';
import '../../../widgets/auth/auth_widgets.dart';
import '../../chat/presentation/home_page.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final Logger _logger = Logger();
  
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    
    // Validate form
    if (!_validateForm()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      _logger.i('Attempting to log in user: ${_emailController.text}');
      
      // Call auth service to log in with standard authentication
      final user = await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (!mounted) return;
      
      _logger.i('Login successful, verifying token validity');
      
      // Verify token validity after login
      final isTokenValid = await _authService.isLoggedIn();
      
      if (!isTokenValid) {
        _logger.w('Token validation failed after login, forcing auth state update');
        
        // Force auth state update if token validation fails
        final updateSuccess = await _authService.forceAuthStateUpdate();
        
        if (!updateSuccess) {
          _logger.e('Auth state update failed, showing error');
          throw 'Authentication failed. Please try again.';
        }
      }
      
      _logger.i('Authentication verified, navigating to home page');
      
      // Navigate to home page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
      );
    } catch (e) {
      _logger.e('Login error: $e');
      
      if (!mounted) return;
      
      String errorMsg;
      
      // Check for common API errors
      if (e.toString().contains('invalid_credentials') || 
          e.toString().contains('wrong password') ||
          e.toString().contains('user not found')) {
        errorMsg = 'Email hoặc mật khẩu không đúng. Vui lòng thử lại.';
      } else if (e.toString().contains('network') || 
                e.toString().contains('connect')) {
        errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối internet của bạn.';
      } else if (e.toString().toLowerCase().contains('scope') || 
                 e.toString().toLowerCase().contains('permission')) {
        errorMsg = 'Không thể đăng nhập với đầy đủ quyền truy cập. Vui lòng thử lại.';
      } else {
        // Use a more user-friendly error message
        errorMsg = 'Lỗi đăng nhập: ${e.toString()}';
      }
      
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      _logger.i('Attempting to sign in with Google');
      
      await _authService.signInWithGoogle();
      
      // Note: On success, this will redirect to another page, 
      // so we don't need to handle navigation here
    } catch (e) {
      _logger.e('Google sign in error: $e');
      
      if (!mounted) return;
      
      // Only set error message if we're still mounted and the error
      // isn't related to the redirect flow
      if (!e.toString().contains('Please complete Google authentication')) {
        setState(() {
          _errorMessage = 'Lỗi đăng nhập với Google: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  bool _validateForm() {
    setState(() {
      _errorMessage = null;
    });
    
    // Validate email
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập email';
      });
      return false;
    }
    
    if (!PasswordValidator.isValidEmail(_emailController.text.trim())) {
      setState(() {
        _errorMessage = 'Email không hợp lệ';
      });
      return false;
    }
    
    // Validate password
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập mật khẩu';
      });
      return false;
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'AI Chat Bot',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đăng nhập',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        EmailField(
                          controller: _emailController,
                          onChanged: (_) => setState(() => _errorMessage = null),
                        ),
                        const SizedBox(height: 16),
                        PasswordField(
                          controller: _passwordController,
                          labelText: 'Mật khẩu',
                          errorText: _errorMessage,
                          onChanged: (_) => setState(() => _errorMessage = null),
                          onSubmit: _login,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: const Text('Quên mật khẩu?'),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        SubmitButton(
                          label: 'Đăng nhập',
                          onPressed: _login,
                          isLoading: _isLoading,
                        ),
                        
                        const SizedBox(height: 16),
                        const Center(
                          child: Text('Hoặc'),
                        ),
                        const SizedBox(height: 16),
                        
                        // Google sign-in button
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: Image.asset(
                            'assets/images/google_logo.png',
                            height: 24,
                            width: 24,
                          ),
                          label: const Text('Đăng nhập bằng Google'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 45),
                            side: const BorderSide(color: Colors.grey),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Chưa có tài khoản?'),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignupPage(),
                                  ),
                                );
                              },
                              child: const Text('Đăng ký ngay'),
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}