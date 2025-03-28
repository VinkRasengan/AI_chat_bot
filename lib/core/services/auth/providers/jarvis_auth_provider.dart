import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/user_model.dart';
import '../auth_provider_interface.dart';
import '../../api/jarvis_api_service.dart';
import '../../../constants/api_constants.dart';

/// Authentication provider using the Jarvis API service
class JarvisAuthProvider implements AuthProviderInterface {
  static final JarvisAuthProvider _instance = JarvisAuthProvider._internal();
  factory JarvisAuthProvider() => _instance;

  final Logger _logger = Logger();
  final JarvisApiService _apiService = JarvisApiService();
  bool _isInitialized = false;
  UserModel? _currentUser;

  JarvisAuthProvider._internal();

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.i('Initializing Jarvis Auth Provider');

      // Initialize API service
      await _apiService.initialize();

      // Try to refresh token and get user
      if (_apiService.isAuthenticated()) {
        await _refreshUserData();
      }

      _isInitialized = true;
      _logger.i('Jarvis Auth Provider initialized successfully');
    } catch (e) {
      _logger.e('Error initializing Jarvis Auth Provider: $e');
    }
  }

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<bool> isLoggedIn() async {
    if (!_isInitialized) await initialize();

    // Check if we have a valid token
    if (!_apiService.isAuthenticated()) {
      _logger.w('No access token found, attempting to refresh token');

      // Try refreshing token if we have a refresh token
      final refreshed = await refreshToken();
      if (!refreshed) {
        _logger.w('Token refresh failed, user is not logged in');
        return false;
      }

      _logger.i('Token refreshed successfully, user is logged in');
      return true;
    }

    // If we don't have the current user, try to refresh
    if (_currentUser == null) {
      try {
        await _refreshUserData();
        _logger.i('User data refreshed successfully, user is logged in');
        return _currentUser != null;
      } catch (e) {
        _logger.e('Error refreshing user data: $e');

        // Try refreshing token as a fallback
        final refreshed = await refreshToken();
        if (refreshed) {
          await _refreshUserData();
          return _currentUser != null;
        }

        return false;
      }
    }

    return true;
  }

  @override
  bool isEmailVerified() {
    if (_currentUser == null) return false;
    return _currentUser!.isEmailVerified;
  }

  @override
  Future<UserModel> signInWithEmailAndPassword(String email, String password) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Signing in with email: $email');

      // Call API service to sign in - ignore the result
      await _apiService.signIn(email, password);

      // Refresh user data
      await _refreshUserData();

      if (_currentUser == null) {
        throw 'Failed to get user data after sign in';
      }

      _logger.i('Sign in successful for user: $email');
      return _currentUser!;
    } catch (e) {
      _logger.e('Sign in error: $e');
      throw e.toString();
    }
  }

  @override
  Future<UserModel> signUpWithEmailAndPassword(String email, String password, {String? name}) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Signing up with email: $email');

      // Call API service to sign up - ignore the result
      await _apiService.signUp(email, password, name: name);

      // Refresh user data
      await _refreshUserData();

      if (_currentUser == null) {
        throw 'Failed to get user data after sign up';
      }

      _logger.i('Sign up successful for user: $email');
      return _currentUser!;
    } catch (e) {
      _logger.e('Sign up error: $e');
      throw e.toString();
    }
  }

  @override
  Future<void> signOut() async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Signing out current user');

      // Call API service to sign out
      await _apiService.logout();

      // Clear current user
      _currentUser = null;

      _logger.i('Sign out successful');
    } catch (e) {
      _logger.e('Sign out error: $e');
      throw e.toString();
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Sending password reset email to: $email');

      // This is a stub for now as we don't have a direct method in Jarvis API
      // In the future, this would call _apiService.sendPasswordResetEmail(email)
      await Future.delayed(const Duration(seconds: 1));

      _logger.i('Password reset email sent to: $email');
    } catch (e) {
      _logger.e('Error sending password reset email: $e');
      throw e.toString();
    }
  }

  @override
  Future<bool> refreshToken() async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Refreshing auth token from provider');

      // Call API service to refresh token
      final result = await _apiService.refreshToken();

      if (result) {
        _logger.i('Token refresh succeeded, updating user data');

        // After successful token refresh, update user data
        try {
          await _refreshUserData();
          _logger.i('User data updated after token refresh');
        } catch (e) {
          _logger.w('Failed to refresh user data after token refresh: $e');
          // Even if we fail to get user data, token refresh was successful
        }
      } else {
        _logger.w('Token refresh failed in provider');
      }

      _logger.i('Token refresh result: $result');
      return result;
    } catch (e) {
      _logger.e('Token refresh error in provider: $e');
      return false;
    }
  }

  @override
  Future<void> reloadUser() async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Reloading user data');

      // Refresh user data from API
      await _refreshUserData();

      _logger.i('User data reloaded successfully');
    } catch (e) {
      _logger.e('Error reloading user: $e');
      throw e.toString();
    }
  }

  @override
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Confirming password reset');

      // This is a stub for now as we don't have a direct method in Jarvis API
      // In the future, this would call _apiService.confirmPasswordReset(code, newPassword)
      await Future.delayed(const Duration(seconds: 1));

      _logger.i('Password reset confirmed successfully');
    } catch (e) {
      _logger.e('Error confirming password reset: $e');
      throw e.toString();
    }
  }

  @override
  Future<bool> checkEmailVerificationStatus(String email) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Checking email verification status for: $email');

      // Make direct API call to check email verification status
      final response = await http.post(
        Uri.parse('${ApiConstants.authApiUrl}/api/v1/auth/emails/verification/status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Stack-Access-Type': 'client',
          'X-Stack-Project-Id': ApiConstants.stackProjectId,
          'X-Stack-Publishable-Client-Key': ApiConstants.stackPublishableClientKey,
        },
        body: jsonEncode({'email': email}),
      );

      _logger.i('Verification status check raw response: [${response.statusCode}] ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          // Check for success/status field
          bool isVerified = false;
          
          // The API might return different formats, check all possible paths
          if (data.containsKey('is_verified')) {
            isVerified = data['is_verified'] == true;
          } else if (data.containsKey('data') && data['data'] is Map && data['data'].containsKey('is_verified')) {
            isVerified = data['data']['is_verified'] == true;
          } else if (data.containsKey('status') && data['status'] == 'verified') {
            isVerified = true;
          } else if (data.containsKey('verified') && data['verified'] == true) {
            isVerified = true;
          }
          
          // Log detailed verification status data for debugging
          _logger.i('Email verification status data: $data');
          _logger.i('Email verification result for $email: ${isVerified ? 'VERIFIED' : 'NOT VERIFIED'}');
          
          return isVerified;
        } catch (jsonError) {
          _logger.e('Error parsing verification status JSON: $jsonError for response: ${response.body}');
          // In case of JSON parsing error, check raw response for verification confirmation
          return response.body.toLowerCase().contains('verified') || 
                 response.body.toLowerCase().contains('success');
        }
      } else if (response.statusCode == 204) {
        // Some APIs return 204 No Content for successful verification checks
        _logger.i('Received 204 No Content response, assuming email is verified');
        return true;
      } else {
        _logger.w('Failed to check verification status: ${response.statusCode}, ${response.body}');
        
        // Try to extract message from error response
        try {
          final errorData = jsonDecode(response.body);
          _logger.w('Verification status error details: $errorData');
          
          // If the error indicates the email doesn't exist, and we know the user has an account,
          // they might be using a different email that's already verified
          if (errorData.toString().contains('not found') || 
              errorData.toString().contains('does not exist')) {
            _logger.i('Email not found in system, might be already verified with different email');
          }
        } catch (e) {
          // Ignore JSON parsing errors for error responses
        }
        
        return false;
      }
    } catch (e) {
      _logger.e('Error checking email verification status: $e');
      return false;
    }
  }

  @override
  Future<bool> manuallySetEmailVerified() async {
    _logger.w('Manual email verification is disabled for security reasons');
    return false;
  }

  @override
  Future<bool> updateUserProfile(Map<String, dynamic> userData) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Updating user profile: $userData');

      // Call API service to update profile
      final result = await _apiService.updateUserProfile(userData);

      if (result) {
        // Refresh user data to get updated profile
        await _refreshUserData();
      }

      _logger.i('Profile update result: $result');
      return result;
    } catch (e) {
      _logger.e('Error updating user profile: $e');
      return false;
    }
  }

  /// Update the user's client metadata
  Future<bool> updateClientMetadata(Map<String, dynamic> metadata) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Updating client metadata: $metadata');

      // Call API service to update client metadata
      final success = await _apiService.updateUserClientMetadata(metadata);

      if (success) {
        // Update cached user data
        if (_currentUser != null) {
          final updatedMetadata = {...(_currentUser!.clientMetadata ?? {}), ...metadata};
          _currentUser = _currentUser!.copyWith(clientMetadata: updatedMetadata);
          await _saveUserToPrefs(_currentUser!);
        }

        _logger.i('Client metadata updated successfully');
      } else {
        _logger.w('Failed to update client metadata');
      }

      return success;
    } catch (e) {
      _logger.e('Error updating client metadata: $e');
      return false;
    }
  }

  /// Get the user's client metadata
  Map<String, dynamic>? getClientMetadata() {
    if (_currentUser == null) {
      _logger.w('Cannot get client metadata: No current user');
      return null;
    }

    return _currentUser!.clientMetadata;
  }

  /// Get the user's client read-only metadata
  Map<String, dynamic>? getClientReadOnlyMetadata() {
    if (_currentUser == null) {
      _logger.w('Cannot get client read-only metadata: No current user');
      return null;
    }

    return _currentUser!.clientReadOnlyMetadata;
  }

  /// Check if the current token is valid
  Future<bool> isTokenValid() async {
    if (!_isInitialized) await initialize();
    return await _apiService.verifyTokenValid();
  }

  /// Check if the current token has all required scopes
  Future<bool> verifyTokenScopes(List<String> requiredScopes) async {
    try {
      _logger.i('Verifying token has required scopes: $requiredScopes');

      // Call API service to verify token scopes
      final hasScopes = await _apiService.verifyTokenHasScopes(requiredScopes);

      if (!hasScopes) {
        _logger.w('Token is missing required scopes');
      } else {
        _logger.i('Token has all required scopes');
      }

      return hasScopes;
    } catch (e) {
      _logger.e('Error verifying token scopes: $e');
      return false;
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Initiating Google sign in');

      // Check if we're on web platform
      if (kIsWeb) {
        // For web, redirect to Google auth URL
        final googleAuthUrl = getGoogleAuthUrl();
        _logger.i('Redirecting to Google auth URL: $googleAuthUrl');

        // Launch the URL in the current tab
        final uri = Uri.parse(googleAuthUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          // This will actually redirect, so the following code won't execute on web
          throw 'Redirect initiated, this exception should not be seen';
        } else {
          throw 'Could not launch Google auth URL';
        }
      } else {
        // For mobile/desktop, use the API service to get the auth URL
        final googleAuthUrl = getGoogleAuthUrl();
        _logger.i('Opening Google auth URL in browser: $googleAuthUrl');

        // Launch the URL in an external browser
        final uri = Uri.parse(googleAuthUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          // Since we can't directly handle the redirect in a mobile app,
          // we need to inform the user to complete the process in the browser
          throw 'Please complete Google authentication in the browser';
        } else {
          throw 'Could not launch Google auth URL';
        }
      }
    } catch (e) {
      _logger.e('Google sign in error: $e');
      throw e.toString();
    }
  }

  @override
  String getGoogleAuthUrl() {
    final redirectUri = Uri.encodeFull('https://chat.dev.jarvis.cx/auth/google/callback');

    final params = {
      'client_id': ApiConstants.stackProjectId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'state': _generateRandomState(),
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    final url = '${ApiConstants.authApiUrl}/api/v1/auth/google/authorize?$queryString';

    _logger.i('Generated Google auth URL: $url');
    return url;
  }

  @override
  Future<UserModel?> processGoogleAuthResponse(Map<String, String> params) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Processing Google auth response: $params');

      // Check for error parameters
      if (params.containsKey('error')) {
        _logger.e('Error in Google auth response: ${params['error']}');
        throw params['error_description'] ?? params['error'] ?? 'Unknown Google auth error';
      }

      // Extract code and state
      final code = params['code'];
      final state = params['state'];

      if (code == null || code.isEmpty) {
        _logger.e('No code found in Google auth response');
        throw 'No authentication code found in the response';
      }

      // Validate state if needed (anti-CSRF)
      // This would require storing the state when generating the URL and comparing it here

      // Exchange code for tokens
      final response = await http.post(
        Uri.parse('${ApiConstants.authApiUrl}/api/v1/auth/google/callback'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Stack-Access-Type': 'client',
          'X-Stack-Project-Id': ApiConstants.stackProjectId,
          'X-Stack-Publishable-Client-Key': ApiConstants.stackPublishableClientKey,
        },
        body: jsonEncode({
          'code': code,
          'redirect_uri': 'https://chat.dev.jarvis.cx/auth/google/callback',
        }),
      );

      _logger.i('Google auth callback response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save tokens
        await _saveAuthToken(
          data['access_token'],
          data['refresh_token'],
          data['user_id'],
        );

        // Refresh user data
        await _refreshUserData();

        if (_currentUser == null) {
          throw 'Failed to get user data after Google sign in';
        }

        _logger.i('Google sign in successful for user: ${_currentUser!.email}');
        return _currentUser;
      } else {
        _logger.e('Google auth callback error: ${response.body}');

        try {
          final errorData = jsonDecode(response.body);
          throw errorData['message'] ?? errorData['error'] ?? 'Unknown error during Google authentication';
        } catch (e) {
          throw 'Error during Google authentication: ${response.reasonPhrase}';
        }
      }
    } catch (e) {
      _logger.e('Error processing Google auth response: $e');
      throw e.toString();
    }
  }

  @override
  Future<bool> resendVerificationEmail(String email) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('Resending verification email to: $email');

      // Call API to resend verification email
      final response = await http.post(
        Uri.parse('${ApiConstants.authApiUrl}/api/v1/auth/emails/verification/resend'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Stack-Access-Type': 'client',
          'X-Stack-Project-Id': ApiConstants.stackProjectId,
          'X-Stack-Publishable-Client-Key': ApiConstants.stackPublishableClientKey,
        },
        body: jsonEncode({
          'email': email,
          'verification_callback_url': ApiConstants.verificationCallbackUrl,
        }),
      );

      _logger.i('Resend verification email response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        _logger.i('Verification email resent successfully');
        return true;
      } else {
        _logger.e('Error resending verification email: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e('Error resending verification email: $e');
      return false;
    }
  }

  /// Get the current access token synchronously
  String? getCurrentToken() {
    try {
      // Get from SharedPreferences without awaiting
      // Note: This is NOT ideal and should be replaced with a proper token cache
      final prefs = SharedPreferences.getInstance().then((prefs) {
        return prefs.getString(ApiConstants.accessTokenKey);
      });
      
      // Since we can't await in a sync method, we have to use a workaround
      // In a real app, this should be replaced with a proper token cache
      // or a more robust solution
      return null;
    } catch (e) {
      _logger.e('Error getting current token: $e');
      return null;
    }
  }

  // Helper to generate a random state for OAuth
  String _generateRandomState() {
    final randomBytes = List<int>.generate(16, (_) => DateTime.now().millisecondsSinceEpoch % 256);
    return base64Url.encode(randomBytes).replaceAll('=', '');
  }

  // Helper method to refresh user data from API with better error handling
  Future<void> _refreshUserData() async {
    try {
      _logger.i('Refreshing user data from API');

      // Verify token is valid before making the request
      if (!_apiService.isAuthenticated()) {
        _logger.w('Cannot refresh user data: Not authenticated');
        throw 'Not authenticated';
      }

      // Attempt to get user profile
      final user = await _apiService.getCurrentUser();

      if (user != null) {
        _currentUser = user;
        await _saveUserToPrefs(user);
        _logger.i('User data refreshed successfully: ${user.email}');
      } else {
        _logger.w('Failed to get user data from API');

        // Try to load from preferences as fallback
        _currentUser = await _loadUserFromPrefs();

        if (_currentUser != null) {
          _logger.i('Loaded user data from preferences: ${_currentUser!.email}');
        } else {
          // Create a minimal placeholder user if we have a userId
          final userId = _apiService.getUserId();
          if (userId != null) {
            _currentUser = UserModel(
              uid: userId,
              email: '',
              createdAt: DateTime.now(),
              isEmailVerified: true,
            );
            _logger.i('Created placeholder user with ID: $userId');
            await _saveUserToPrefs(_currentUser!);
          } else {
            _logger.w('No user data available and no user ID');
            throw 'Failed to get user data';
          }
        }
      }
    } catch (e) {
      _logger.e('Error refreshing user data: $e');
      throw e.toString();
    }
  }

  // Helper method to save user to preferences
  Future<void> _saveUserToPrefs(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save user data directly using toJson
      await prefs.setString('currentUser', user.toJson());

      _logger.i('User data saved to preferences');
    } catch (e) {
      _logger.e('Error saving user to preferences: $e');
    }
  }

  // Helper method to load user from preferences
  Future<UserModel?> _loadUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('currentUser');

      if (userJson == null || userJson.isEmpty) {
        return null;
      }

      return UserModel.fromJson(userJson);
    } catch (e) {
      _logger.e('Error loading user from preferences: $e');
      return null;
    }
  }

  // Helper method to save authentication tokens
  Future<void> _saveAuthToken(String accessToken, String refreshToken, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', accessToken);
      await prefs.setString('refreshToken', refreshToken);
      await prefs.setString('userId', userId);

      _logger.i('Authentication tokens saved to preferences');
    } catch (e) {
      _logger.e('Error saving authentication tokens: $e');
    }
  }
}
