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
      _logger.i('Signing in with email and password: $email');
      
      // Prepare request body according to API specification
      final requestBody = {
        'email': email,
        'password': password,
      };
      
      // Make API request with proper headers
      final response = await http.post(
        Uri.parse('${ApiConstants.authApiUrl}${ApiConstants.authPasswordSignIn}'),
        headers: getAuthHeaders(includeAuth: false),
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Save auth tokens from the response
        if (data['access_token'] != null) {
          await _saveAuthToken(
            data['access_token'],
            data['refresh_token'] ?? '',
            data['user_id'] ?? '',
          );
        }
        
        // Create and return user model
        return UserModel(
          id: data['user_id'] ?? '',
          uid: data['user_id'] ?? '',
          email: email,
          createdAt: DateTime.now(),
          isEmailVerified: false, // We'll assume not verified until checked
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to sign in';
      }
    } catch (e) {
      _logger.e('Error signing in: $e');
      throw e.toString();
    }
  }
  
  /// Sign up with email and password
  Future<UserModel> signUpWithEmailAndPassword(String email, String password, {String? name}) async {
    try {
      _logger.i('Signing up with email: $email');
      
      // Prepare request body with all required parameters
      final requestBody = {
        'email': email,
        'password': password,
        'verification_callback_url': ApiConstants.verificationCallbackUrl,
      };
      
      // Add name if provided
      if (name != null && name.isNotEmpty) {
        requestBody['name'] = name;
      }
      
      // Make the API request with proper headers
      final response = await http.post(
        Uri.parse('${ApiConstants.authApiUrl}${ApiConstants.authPasswordSignUp}'),
        headers: getAuthHeaders(includeAuth: false),
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Save auth tokens from the response
        if (data['access_token'] != null) {
          await _saveAuthToken(
            data['access_token'],
            data['refresh_token'] ?? '',
            data['user_id'] ?? '',
          );
        }
        
        // Create and return user model
        return UserModel(
          id: data['user_id'] ?? '',
          uid: data['user_id'] ?? '',
          email: email,
          name: name,
          createdAt: DateTime.now(),
          isEmailVerified: false,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to sign up';
      }
    } catch (e) {
      _logger.e('Error signing up: $e');
      throw e.toString();
    }
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
    try {
      _logger.i('Forcing authentication state update');
      
      // First check if there's a refresh token available
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(ApiConstants.refreshTokenKey);
      
      if (refreshToken == null || refreshToken.isEmpty) {
        _logger.w('Cannot update auth state: No refresh token available');
        return false;
      }
      
      // Use the JarvisAuthProvider but call initialize first
      final authProvider = JarvisAuthProvider();
      await authProvider.initialize();
      
      // Call provider's refreshToken directly (this handles refreshing the actual token)
      final result = await authProvider.refreshToken();
      
      if (result) {
        _logger.i('Auth state update successful, token refreshed');
        return true;
      } else {
        _logger.w('Auth state update failed, could not refresh token');
        return false;
      }
    } catch (e) {
      _logger.e('Error during force auth state update: $e');
      return false;
    }
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
  
  Future<bool> signOut() async {
    try {
      _logger.i('Signing out user');
      
      final authProvider = JarvisAuthProvider();
      await authProvider.initialize();
      await authProvider.signOut();
      
      // Also clear tokens from SharedPreferences directly for redundancy
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConstants.accessTokenKey);
      await prefs.remove(ApiConstants.refreshTokenKey);
      await prefs.remove(ApiConstants.userIdKey);
      
      _logger.i('User signed out successfully');
      return true;
    } catch (e) {
      _logger.e('Error signing out: $e');
      return false;
    }
  }
  
  Future<void> _saveAuthToken(String accessToken, String refreshToken, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.accessTokenKey, accessToken);
    await prefs.setString(ApiConstants.refreshTokenKey, refreshToken);
    await prefs.setString(ApiConstants.userIdKey, userId);
  }
}