import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../../core/utils/validators/password_validator.dart';
import '../../../widgets/auth/auth_widgets.dart';
import 'login_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  final Logger _logger = Logger();
  
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  Future<void> _resetPassword() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    
    // Validate email
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập email';
      });
      return;
    }
    
    if (!PasswordValidator.isValidEmail(_emailController.text.trim())) {
      setState(() {
        _errorMessage = 'Email không hợp lệ';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      _logger.i('Attempting to send password reset email to: ${_emailController.text}');
      
      // Call auth service to send password reset email
      await _authService.sendPasswordResetEmail(_emailController.text.trim());
      
      if (!mounted) return;
      
      _logger.i('Password reset email sent successfully');
      
      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Password reset error: $e');
      
      if (!mounted) return;
      
      String errorMsg;
      
      // Check for common API errors
      if (e.toString().contains('user-not-found')) {
        errorMsg = 'Không tìm thấy tài khoản với email này';
      } else if (e.toString().contains('too-many-requests')) {
        errorMsg = 'Quá nhiều yêu cầu, vui lòng thử lại sau';
      } else if (e.toString().contains('network')) {
        errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối internet của bạn.';
      } else {
        // Use a more user-friendly error message
        errorMsg = 'Không thể gửi email đặt lại mật khẩu: ${e.toString()}';
      }
      
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isSuccess ? _buildSuccessContent() : _buildRequestContent(),
      ),
    );
  }

  Widget _buildRequestContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Đặt lại mật khẩu',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Nhập địa chỉ email của bạn để nhận liên kết đặt lại mật khẩu.',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 24),
        EmailField(
          controller: _emailController,
          errorText: _errorMessage,
          onChanged: (_) => setState(() => _errorMessage = null),
        ),
        const SizedBox(height: 24),
        SubmitButton(
          label: 'Gửi yêu cầu đặt lại mật khẩu',
          onPressed: _resetPassword,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 80,
          color: Colors.green,
        ),
        const SizedBox(height: 24),
        const Text(
          'Email sent successfully',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'We have sent a password reset link to ${_emailController.text.trim()}. '
          'Please check your inbox and follow the instructions.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'If you do not see the email in your inbox, check your spam folder.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginPage(),
              ),
            );
          },
          child: const Text('Return to Login'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
