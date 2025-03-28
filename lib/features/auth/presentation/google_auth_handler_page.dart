import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../chat/presentation/home_page.dart';

class GoogleAuthHandlerPage extends StatefulWidget {
  final Map<String, String> params;
  
  const GoogleAuthHandlerPage({
    super.key,
    required this.params,
  });

  @override
  State<GoogleAuthHandlerPage> createState() => _GoogleAuthHandlerPageState();
}

class _GoogleAuthHandlerPageState extends State<GoogleAuthHandlerPage> {
  final Logger _logger = Logger();
  final AuthService _authService = AuthService();
  
  bool _isProcessing = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _processAuth();
  }
  
  Future<void> _processAuth() async {
    try {
      _logger.i('Processing Google auth callback with params: ${widget.params}');
      
      // Process the auth response
      final user = await _authService.processGoogleAuthResponse(widget.params);
      
      if (!mounted) return;
      
      if (user != null) {
        _logger.i('Google authentication successful for user: ${user.email}');
        
        setState(() {
          _isProcessing = false;
        });
        
        // Navigate to home page after short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _navigateToHome();
          }
        });
      } else {
        _logger.w('Google authentication returned null user');
        setState(() {
          _errorMessage = 'Xác thực Google không thành công';
          _isProcessing = false;
        });
      }
    } catch (e) {
      _logger.e('Error processing Google auth: $e');
      
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Lỗi xác thực: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }
  
  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: _isProcessing
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text(
                      'Đang xử lý đăng nhập...',
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : _errorMessage != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[700],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Lỗi đăng nhập',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Đăng nhập thành công',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _navigateToHome,
                          child: const Text('Tiếp tục'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
