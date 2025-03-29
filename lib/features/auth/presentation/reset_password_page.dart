import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../../core/utils/validators/password_validator.dart';
import '../../../widgets/auth/auth_widgets.dart';
import '../../../widgets/auth/password_requirement_widget.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  final String code;
  
  const ResetPasswordPage({
    super.key,
    required this.code,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  final Logger _logger = Logger();
  
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;
  String _passwordStrength = '';

  @override
  void initState() {
    super.initState();
    _passwordStrength = PasswordValidator.getPasswordStrength('');
  }

  Future<void> _resetPassword() async {
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
      _logger.i('Attempting to reset password with code: ${widget.code}');
      
      // Call auth service to confirm password reset
      final success = await _authService.confirmPasswordReset(
        widget.code,
        _passwordController.text,
      );
      
      if (!mounted) return;
      
      if (success) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Không thể đặt lại mật khẩu. Vui lòng thử lại.';
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Password reset error: $e');
      
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Lỗi: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  bool _validateForm() {
    setState(() {
      _errorMessage = null;
    });
    
    // Validate password
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập mật khẩu mới';
      });
      return false;
    }
    
    if (!PasswordValidator.isValidPassword(_passwordController.text)) {
      setState(() {
        _errorMessage = 'Mật khẩu không đáp ứng các yêu cầu bảo mật';
      });
      return false;
    }
    
    // Validate confirm password
    if (_confirmPasswordController.text != _passwordController.text) {
      setState(() {
        _errorMessage = 'Mật khẩu xác nhận không khớp';
      });
      return false;
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt lại mật khẩu'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isSuccess ? _buildSuccessContent() : _buildResetContent(),
        ),
      ),
    );
  }

  Widget _buildResetContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tạo mật khẩu mới',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Vui lòng nhập mật khẩu mới của bạn.',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          PasswordField(
            controller: _passwordController,
            labelText: 'Mật khẩu mới',
            onChanged: (value) {
              setState(() {
                _passwordStrength = PasswordValidator.getPasswordStrength(value);
                _errorMessage = null;
              });
            },
          ),
          if (_passwordController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: PasswordValidator.getPasswordStrengthRatio(_passwordStrength),
              color: PasswordValidator.getPasswordStrengthColor(_passwordStrength),
            ),
            const SizedBox(height: 4),
            Text(
              'Độ mạnh: $_passwordStrength',
              style: TextStyle(
                color: PasswordValidator.getPasswordStrengthColor(_passwordStrength),
              ),
            ),
          ],
          const SizedBox(height: 8),
          PasswordRequirementWidget(
            password: _passwordController.text,
            isVisible: true,
          ),
          const SizedBox(height: 16),
          PasswordField(
            controller: _confirmPasswordController,
            labelText: 'Xác nhận mật khẩu mới',
            errorText: _errorMessage,
            onChanged: (_) => setState(() => _errorMessage = null),
            onSubmit: _resetPassword,
          ),
          const SizedBox(height: 24),
          SubmitButton(
            label: 'Đặt lại mật khẩu',
            onPressed: _resetPassword,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          const Text(
            'Mật khẩu đã được đặt lại thành công',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Bạn có thể đăng nhập bằng mật khẩu mới',
            style: TextStyle(
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginPage(),
                ),
              );
            },
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
