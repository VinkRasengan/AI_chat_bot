import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../constants/api_constants.dart';
import 'providers/jarvis_auth_provider.dart';
import 'package:http/http.dart' as http;

/// Unified Authentication Service
class AuthService {
  final Logger _logger = Logger();
  bool _isInitialized = false;
  
  /// Initialize the auth service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.i('Initializing AuthService');
      final authProvider = JarvisAuthProvider();
      await authProvider.initialize();
      _isInitialized = true;
    } catch (e) {
      _logger.e('Error initializing AuthService: $e');
      throw e.toString();
    }
  }
  
  /// Refresh the authentication token
  Future<bool> refreshToken() async {
    try {
      _logger.i('Refreshing authentication token');
      
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(ApiConstants.refreshTokenKey);
      
      if (refreshToken == null || refreshToken.isEmpty) {
        _logger.w('No refresh token available');
        return false;
      }
      
      // Per API documentation, use specific headers for token refresh
      final headers = {
        'X-Stack-Access-Type': 'client',
        'X-Stack-Project-Id': ApiConstants.stackProjectId,
        'X-Stack-Publishable-Client-Key': ApiConstants.stackPublishableClientKey,
        'X-Stack-Refresh-Token': refreshToken,
        'Content-Type': 'application/json'
      };
      
      // POST request body can be empty per the API example
      final response = await http.post(
        Uri.parse('${ApiConstants.authApiUrl}${ApiConstants.authSessionRefresh}'),
        headers: headers,
        body: '{}',
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['access_token'];
        
        if (newAccessToken != null) {
          // Save the new access token
          await prefs.setString(ApiConstants.accessTokenKey, newAccessToken);
          _logger.i('Token refreshed successfully');
          return true;
        } else {
          _logger.w('No access token in response');
          return false;
        }
      } else {
        _logger.e('Token refresh failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Error refreshing token: $e');
      return false;
    }
  }
  
  /// Confirm password reset
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    try {
      _logger.i('Confirming password reset');
      
      final authProvider = JarvisAuthProvider();
      await authProvider.initialize();
      await authProvider.confirmPasswordReset(code, newPassword);
      
      _logger.i('Password reset confirmed successfully');
    } catch (e) {
      _logger.e('Error confirming password reset: $e');
      throw e.toString();
    }
  }
  
  Future<UserModel> signInWithEmailAndPassword(String email, String password) async {
    try {
      final authProvider = JarvisAuthProvider();
      await authProvider.initialize();
      return await authProvider.signInWithEmailAndPassword(email, password);
    } catch (e) {
      throw e.toString();
    }
  }
  
  Future<UserModel> signUpWithEmailAndPassword(String email, String password, {String? name}) async {
    final authProvider = JarvisAuthProvider();
    await authProvider.initialize();
    return await authProvider.signUpWithEmailAndPassword(email, password, name: name);
  }
  
  Future<void> sendPasswordResetEmail(String email) async {
    final authProvider = JarvisAuthProvider();
    await authProvider.initialize();
    return await authProvider.sendPasswordResetEmail(email);
  }
  
  Future<bool> checkEmailVerificationStatus(String email) async {
    final authProvider = JarvisAuthProvider();
    await authProvider.initialize();
    return await authProvider.checkEmailVerificationStatus(email);
  }
  
  Future<bool> resendVerificationEmail(String email) async {
    final authProvider = JarvisAuthProvider();
    await authProvider.initialize();
    return await authProvider.resendVerificationEmail(email);
  }
  
  Future<UserModel?> processGoogleAuthResponse(Map<String, String> params) async {
    final authProvider = JarvisAuthProvider();
    await authProvider.initialize();
    return await authProvider.processGoogleAuthResponse(params);
  }
  
  Future<bool> forceAuthStateUpdate() async {
    final authProvider = JarvisAuthProvider();
    await authProvider.initialize();
    return await authProvider.refreshToken();
  }
  
  Future<UserModel> signInWithGoogle() async {
    final authProvider = JarvisAuthProvider();
    await authProvider.initialize();
    return await authProvider.signInWithGoogle();
  }
  
  Future<bool> updateClientMetadata(Map<String, dynamic> metadata) async {
    final authProvider = JarvisAuthProvider();
    await authProvider.initialize();
    return await authProvider.updateClientMetadata(metadata);
  }
  
  UserModel? get currentUser {
    final authProvider = JarvisAuthProvider();
    return authProvider.currentUser;
  }
  
  Future<void> reloadUser() async {
    final authProvider = JarvisAuthProvider();
    await authProvider.initialize();
    return await authProvider.reloadUser();
  }
  
  Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
  
  /// Get authenticated headers
  Map<String, String> getAuthHeaders({bool includeAuth = true}) {
    final authProvider = JarvisAuthProvider();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Stack-Access-Type': 'client',
      'X-Stack-Project-Id': ApiConstants.stackProjectId,
      'X-Stack-Publishable-Client-Key': ApiConstants.stackPublishableClientKey,
    };
    
    if (includeAuth) {
      final token = authProvider.getCurrentToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }
  
  /// Check if user is authenticated
  bool isAuthenticated() {
    final authProvider = JarvisAuthProvider();
    return authProvider.getCurrentToken() != null;
  }
  
  Future<bool> isLoggedIn() async {
    final authProvider = JarvisAuthProvider();
    await authProvider.initialize();
    return await authProvider.isLoggedIn();
  }
  
  Future<void> signOut() async {
    final authProvider = JarvisAuthProvider();
    await authProvider.initialize();
    return await authProvider.signOut();
  }
}