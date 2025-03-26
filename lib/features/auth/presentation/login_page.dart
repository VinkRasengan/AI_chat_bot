import 'package:flutter/material.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../../widgets/auth/auth_widgets.dart';
import '../../../features/chat/presentation/home_page.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import 'package:logger/logger.dart';
import '../../../core/utils/errors/error_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final Logger _logger = Logger();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    // Add any initialization code here
  }

  Future<void> _login() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    
    // Basic validation
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập email và mật khẩu';
      });
      return;
    }
    
    // Show loading indicator and clear any previous errors
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _authService.signInWithEmailAndPassword(email, password);
      
      if (!mounted) return;
      
      // Navigate to home page on success
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Handle authentication errors
      final error = ErrorUtils.getAuthErrorInfo(e.toString());
      
      setState(() {
        _errorMessage = error.message;
      });
      
      _logger.e('Login error: ${e.toString()}');
    } finally {
      // Always reset loading state if still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    // Early return if already loading
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // For all platforms, we now use the Jarvis API's method
      await _authService.signInWithGoogle();
      
      if (!mounted) return;
      
      // Navigate to home page on success
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Special handling for unsupported error
      if (e.toString().contains('Not implemented')) {
        _logger.w('Google Sign In not supported by Jarvis API');
        
        setState(() {
          _errorMessage = 'Google Sign In is not supported in the current configuration';
        });
      } else {
        // Handle other errors
        _logger.e('Google sign-in error: $e');
        setState(() {
          _errorMessage = 'Error signing in with Google: ${e.toString()}';
        });
      }
    } finally {
      // Always reset loading state if still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: AuthCard(
            title: 'Đăng nhập',
            children: [
              EmailField(
                controller: _emailController,
                onChanged: (_) => setState(() => _errorMessage = null),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _passwordController,
                onChanged: (_) => setState(() => _errorMessage = null),
                onSubmit: _login,  // Change from onSubmitted to onSubmit
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) => setState(() => _rememberMe = value ?? false),
                      ),
                      const Text('Ghi nhớ đăng nhập'),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                    ),
                    child: const Text('Quên mật khẩu?'),
                  ),
                ],
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Use the standardized button
              SubmitButton(
                label: 'Đăng nhập',
                onPressed: _login,
                isLoading: _isLoading,
              ),
              
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('hoặc'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              
              // Google Sign-In Button with clear styling
              OutlinedButton.icon(
                icon: Image.asset(
                  'assets/images/google_logo.png', 
                  height: 24,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.login),
                ),
                label: const Text('Đăng nhập với Google'),
                onPressed: _isLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: Colors.grey.shade300),
                  foregroundColor: Colors.black,
                  disabledForegroundColor: Colors.grey.shade400,
                ),
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chưa có tài khoản?'),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignupPage()),
                    ),
                    child: const Text('Đăng ký ngay'),
                  ),
                ],
              ),
            ],
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