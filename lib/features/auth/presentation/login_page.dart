import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/services/auth/auth_service.dart';
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
  
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        // Attempt to sign in with email and password
        final user = await _authService.signInWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );
        
        _logger.i('Login successful for: ${user.email}');
        
        // Force auth state update to ensure all systems are synchronized
        final authUpdated = await _authService.forceAuthStateUpdate();
        if (!authUpdated) {
          _logger.w('Auth state update failed, but login was successful - proceeding anyway');
          // Don't show an error here - just log the issue but continue
        }
        
        if (!mounted) return;
        
        // Navigate to home page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } catch (e) {
        _logger.e('Login error: $e');
        
        if (!mounted) return;
        
        // Format the error message to be more user-friendly
        setState(() {
          if (e.toString().contains('scope')) {
            // For scope-related errors, provide a more helpful message
            _errorMessage = 'Login successful, but some features may be limited. Please contact support.';
          } else {
            _errorMessage = 'Authentication failed. Please try again.';
          }
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
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