import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import '../../../core/services/auth/auth_service.dart';
import 'login_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;
  
  const EmailVerificationPage({
    super.key,
    required this.email,
  });

  @override
  EmailVerificationPageState createState() => EmailVerificationPageState();
}

class EmailVerificationPageState extends State<EmailVerificationPage> {
  final AuthService _authService = AuthService();
  final Logger _logger = Logger();
  Timer? _timer;
  bool _isVerified = false;
  bool _isCheckingStatus = false;
  int _countdown = 60;
  bool _canResend = false;
  bool _isResending = false;
  int _checkCount = 0;
  
  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
    _startCountdown();
  }
  
  void _startVerificationCheck() {
    // Check initially
    _checkVerificationStatus();
    
    // Then check every 15 seconds (increased interval to reduce API load)
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkVerificationStatus();
    });
  }
  
  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }
  
  Future<void> _checkVerificationStatus() async {
    if (_isCheckingStatus) return;
    
    setState(() {
      _isCheckingStatus = true;
    });
    
    try {
      _logger.i('Checking email verification status for: ${widget.email}');
      
      // Check verification status directly from server
      final isVerified = await _authService.checkEmailVerificationStatus(widget.email);
      
      _logger.i('Verification check result: ${isVerified ? "VERIFIED" : "NOT VERIFIED"}');
      
      setState(() {
        _isVerified = isVerified;
        _isCheckingStatus = false;
      });
      
      if (isVerified) {
        _logger.i('Email is verified, stopping verification check');
        _timer?.cancel();
        _timer = null;
        
        // Show success dialog and navigate
        await _showVerificationSuccessDialog();
      } else {
        _logger.i('Email is not yet verified, continuing to check');
        
        // If this is at least the third check and we're still not verified,
        // suggest to the user they might need to use the force continue option
        _checkCount++;
        if (_checkCount >= 3) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'If you\'ve already clicked "Verify my email" in your email but it\'s not being detected, '
                  'you can use the "Force Continue" option below.'
                ),
                duration: Duration(seconds: 8),
              ),
            );
          }
        }
      }
    } catch (e) {
      _logger.e('Error checking verification status: $e');
      
      setState(() {
        _isCheckingStatus = false;
      });
    }
  }

  Future<void> _manuallyMarkAsVerified() async {
    try {
      _logger.i('User manually confirming email has been verified');
      
      // Show confirmation dialog to make sure the user is certain
      final bool confirmed = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Email Verified'),
          content: const Text(
            'By continuing, you confirm that you have verified your email by clicking the verification link in the email sent to you.\n\n'
            'Did you click "Verify my email" in the email?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No, Go Back'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, I Verified'),
            ),
          ],
        ),
      ) ?? false;
      
      if (!confirmed) return;
      
      // Set as verified if the user confirms
      setState(() {
        _isVerified = true;
      });
      
      _timer?.cancel();
      _timer = null;
      
      await _showVerificationSuccessDialog();
    } catch (e) {
      _logger.e('Error manually marking as verified: $e');
    }
  }
  
  Future<void> _openVerificationLinkDirectly() async {
    final code = "auto_${DateTime.now().millisecondsSinceEpoch}";
    final verificationUrl = 'https://auth.dev.jarvis.cx/handler/email-verification?after_auth_return_to=%2Fauth%2Fsignin%3Fclient_id%3Djarvis_chat%26redirect%3Dhttps%253A%252F%252Fchat.dev.jarvis.cx%252Fauth%252Foauth%252Fsuccess&code=$code';
    
    try {
      final uri = Uri.parse(verificationUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // Show message to notify user
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification link opened in browser. Please complete verification there.'),
            duration: Duration(seconds: 5),
          ),
        );
        
        // After a delay, check verification status again
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _checkVerificationStatus();
          }
        });
      } else {
        throw 'Could not launch verification URL';
      }
    } catch (e) {
      _logger.e('Error opening verification link: $e');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening verification link: ${e.toString()}'),
        ),
      );
    }
  }
  
  Future<void> _showVerificationSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Email Verified'),
        content: const Text('Your email has been verified successfully. You can now log in.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to login page
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _resendVerificationEmail() async {
    try {
      setState(() {
        _isResending = true;
      });
      
      _logger.i('Resending verification email to: ${widget.email}');
      
      // Use the resendVerificationEmail method
      final success = await _authService.resendVerificationEmail(widget.email);
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent. Please check your inbox and click on the "Verify my email" button.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Reset countdown
        setState(() {
          _isResending = false;
          _canResend = false;
          _countdown = 60;
        });
        
        _startCountdown();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend verification email. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        
        setState(() {
          _isResending = false;
        });
      }
    } catch (e) {
      _logger.e('Error resending verification email: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isResending = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _openEmailApp() async {
    final email = widget.email;
    String? emailDomain;
    
    if (email.contains('@')) {
      emailDomain = email.split('@')[1];
    }
    
    String? emailUrl;
    
    // Check common email providers
    if (emailDomain != null) {
      if (emailDomain.contains('gmail')) {
        emailUrl = 'https://mail.google.com';
      } else if (emailDomain.contains('yahoo')) {
        emailUrl = 'https://mail.yahoo.com';
      } else if (emailDomain.contains('outlook') || emailDomain.contains('hotmail')) {
        emailUrl = 'https://outlook.live.com';
      } else if (emailDomain.contains('proton')) {
        emailUrl = 'https://mail.proton.me';
      }
    }
    
    // Fall back to a general "mailto:" if no specific provider is found
    emailUrl ??= 'mailto:';
    
    try {
      final uri = Uri.parse(emailUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch email app';
      }
    } catch (e) {
      _logger.e('Error opening email app: $e');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email app. Please check your email manually.'),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
      ),
      body: _isVerified ? _buildVerifiedView() : _buildVerificationView(),
    );
  }
  
  Widget _buildVerificationView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.mark_email_unread,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              'Verify Your Email',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'We\'ve sent a verification email to:\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'Please check your inbox and click the "Verify my email" button in the email from Jarvis Development.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openEmailApp,
              icon: const Icon(Icons.email),
              label: const Text('Open Email App'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
            const SizedBox(height: 16),
            _isCheckingStatus
                ? Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        'Checking verification status...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      TextButton(
                        onPressed: _checkVerificationStatus,
                        child: const Text('Check Verification Status'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Already verified your email?',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      ElevatedButton(
                        onPressed: _manuallyMarkAsVerified,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('I\'ve Verified My Email - Continue'),
                      ),
                      const SizedBox(height: 16),
                      if (_checkCount >= 2) // Only show direct link option after 2 failed checks
                        OutlinedButton(
                          onPressed: _openVerificationLinkDirectly,
                          child: const Text('Try Verification Link Directly'),
                        ),
                    ],
                  ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Didn\'t receive the email?',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            _canResend
                ? TextButton.icon(
                    onPressed: _isResending ? null : _resendVerificationEmail,
                    icon: _isResending 
                        ? Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(right: 8),
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isResending ? 'Sending...' : 'Resend Verification Email'),
                  )
                : Text(
                    'Resend in $_countdown seconds',
                    style: const TextStyle(color: Colors.grey),
                  ),
            const SizedBox(height: 16),
            const Text(
              'Make sure to check your spam or junk folder if you can\'t find the email in your inbox.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildVerifiedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              'Email Verified',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank you for verifying your email address. You can now log in to your account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('Log In'),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}