import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../../core/utils/validators/input_validator.dart';  // Updated import
import '../../../widgets/auth/auth_widgets.dart';
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
  String? _emailErrorMessage;
  String? _passwordErrorMessage;

  Future<void> _login() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    
    // Validate form
    if (!_validateForm()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _emailErrorMessage = null;
      _passwordErrorMessage = null;
    });
    
    try {
      _logger.i('Attempting to log in user: ${_emailController.text}');
      
      // Call auth service to log in with standard authentication
      await _authService.signInWithEmailAndPassword(
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
      
      _logger.i('Authentication verified, navigating to welcome screen');
      
      // Navigate back to auth check which will redirect to welcome screen
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      _logger.e('Login error: $e');
      
      if (!mounted) return;
      
      // Already formatted error messages from JarvisApiService
      if (e.toString().contains('Email hoặc mật khẩu không đúng')) {
        setState(() {
          _passwordErrorMessage = e.toString();
          _isLoading = false;
        });
        return;
      }
      
      // Handle other errors
      String errorMsg;
      if (e.toString().contains('invalid_credentials') || 
          e.toString().contains('wrong password') ||
          e.toString().contains('user not found') ||
          e.toString().contains('EMAIL_PASSWORD_MISMATCH') ||
          e.toString().contains('Wrong e-mail or password')) {
        errorMsg = 'Email hoặc mật khẩu không đúng. Vui lòng thử lại.';
        setState(() {
          _passwordErrorMessage = errorMsg;
          _isLoading = false;
        });
        return;
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
        _passwordErrorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  bool _validateForm() {
    setState(() {
      _emailErrorMessage = null;
      _passwordErrorMessage = null;
    });
    
    // Validate email
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _emailErrorMessage = 'Vui lòng nhập email';
      });
      return false;
    }
    
    if (!InputValidator.isValidEmail(_emailController.text.trim())) {  // Updated class name
      setState(() {
        _emailErrorMessage = 'Email không hợp lệ';
      });
      return false;
    }
    
    // Validate password
    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordErrorMessage = 'Vui lòng nhập mật khẩu';
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
                          errorText: _emailErrorMessage,
                          onChanged: (_) => setState(() => _emailErrorMessage = null),
                        ),
                        const SizedBox(height: 16),
                        PasswordField(
                          controller: _passwordController,
                          labelText: 'Mật khẩu',
                          errorText: _passwordErrorMessage,
                          onChanged: (_) => setState(() => _passwordErrorMessage = null),
                          onSubmit: _login,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        SubmitButton(
                          label: 'Đăng nhập',
                          onPressed: _login,
                          isLoading: _isLoading,
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