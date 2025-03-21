import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider_interface.dart';

// Windows-specific implementation that doesn't rely on Firebase Auth
class WindowsAuthService implements AuthProviderInterface {
  final Logger _logger = Logger();
  String? _currentUserEmail;
  
  // Stream controller for auth state changes
  final StreamController<String?> _authStateController = StreamController<String?>.broadcast();
  
  WindowsAuthService() {
    // Initialize current user
    getCurrentUserEmail().then((email) {
      _currentUserEmail = email;
      _authStateController.add(email);
    });
  }
  
  @override
  dynamic get currentUser => _currentUserEmail;
  
  @override
  Stream<String?> authStateChanges() {
    return _authStateController.stream;
  }
  
  // Check if user is logged in
  @override
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // Get current user email
  Future<String?> getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentUserEmail');
  }

  // Sign in with email and password
  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = await getUsers();
      
      final user = users.firstWhere(
        (user) => user['email'] == email && user['password'] == password,
        orElse: () => {},
      );
      
      if (user.isEmpty) {
        throw 'Tài khoản hoặc mật khẩu không đúng';
      }
      
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('currentUserEmail', email);
      _currentUserEmail = email;
      _authStateController.add(email); // Notify listeners
      _logger.i('Sign in successful for: $email');
    } catch (e) {
      _logger.e('Sign in error: $e');
      throw e.toString();
    }
  }

  // Sign up with email and password
  @override
  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = await getUsers();
      
      // Check if email already exists
      if (users.any((user) => user['email'] == email)) {
        throw 'Email already exists';
      }
      
      users.add({
        'email': email,
        'password': password,
        'isVerified': true, // Auto-verify on Windows
      });
      
      await prefs.setString('users', jsonEncode(users));
      _logger.i('Sign up successful for: $email');
    } catch (e) {
      _logger.e('Sign up error: $e');
      throw e.toString();
    }
  }

  // Sign out
  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('currentUserEmail');
    _currentUserEmail = null;
    _authStateController.add(null); // Notify listeners
    _logger.i('Sign out successful');
  }

  // Password reset (simulation)
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final users = await getUsers();
      final userExists = users.any((user) => user['email'] == email);
      
      if (!userExists) {
        throw 'Không tìm thấy người dùng với email này';
      }
      
      _logger.i('Password reset email would be sent to: $email');
    } catch (e) {
      _logger.e('Password reset error: $e');
      throw e.toString();
    }
  }

  // Always return true for Windows
  @override
  bool isEmailVerified() => true;

  // No-op for Windows
  @override
  Future<void> reloadUser() async {
    _currentUserEmail = await getCurrentUserEmail();
  }

  // Retrieve users from SharedPreferences
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('users');
      
      if (usersJson == null) {
        return [];
      }
      
      final List<dynamic> decoded = jsonDecode(usersJson);
      return decoded.map((user) => Map<String, dynamic>.from(user)).toList();
    } catch (e) {
      _logger.e('Error retrieving users: $e');
      return [];
    }
  }

  // Mock Google sign in with clear unsupported message for Windows
  @override
  Future<void> signInWithGoogle() async {
    try {
      _logger.w('Google Sign-In is not supported on Windows platform');
      throw 'Google Sign-In không được hỗ trợ trên Windows';
    } catch (e) {
      _logger.e('Google sign-in error: $e');
      throw e.toString();
    }
  }
  
  @override
  Future<void> resendVerificationEmail() async {
    // For Windows, we just simulate this since verification is auto-approved
    _logger.i('Simulating resend verification email on Windows platform');
  }
  
  // Clean up resources
  void dispose() {
    _authStateController.close();
  }
}
