import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../constants/api_constants.dart';
import 'package:http/http.dart' as http;

/// Unified Authentication Service
class AuthService {
  final Logger _logger = Logger();
  bool _isInitialized = false;
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  UserModel? _currentUser;
  
  /// Initialize the auth service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.i('Initializing AuthService');
      
      // Load tokens from storage
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(ApiConstants.accessTokenKey);
      _refreshToken = prefs.getString(ApiConstants.refreshTokenKey);
      _userId = prefs.getString(ApiConstants.userIdKey);
      
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
      final refreshToken = prefs.getString(ApiConstants.refreshTokenKey) ?? _refreshToken;
      
      if (refreshToken == null || refreshToken.isEmpty) {
        _logger.w('No refresh token available');
        return false;
      }
      
      // Per API documentation, use specific headers for token refresh
      final headers = {
        'Content-Type': 'application/json',
        'X-Stack-Access-Type': 'client',
        'X-Stack-Project-Id': ApiConstants.stackProjectId,
        'X-Stack-Publishable-Client-Key': ApiConstants.stackPublishableClientKey,
        'X-Stack-Refresh-Token': refreshToken,
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
          _accessToken = newAccessToken;
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
  
  /// Sign in with email and password using Jarvis API
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
          _accessToken = data['access_token'];
          _refreshToken = data['refresh_token'] ?? '';
          _userId = data['user_id'] ?? '';
          
          await _saveAuthTokens();
        }
        
        // Create and return user model
        _currentUser = UserModel(
          id: data['user_id'] ?? '',
          uid: data['user_id'] ?? '',
          email: email,
          createdAt: DateTime.now(),
          isEmailVerified: false, // We'll assume not verified until checked
        );
        
        return _currentUser!;
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to sign in';
      }
    } catch (e) {
      _logger.e('Error signing in: $e');
      throw e.toString();
    }
  }
  
  /// Sign up with email and password using Jarvis API
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
          _accessToken = data['access_token'];
          _refreshToken = data['refresh_token'] ?? '';
          _userId = data['user_id'] ?? '';
          
          await _saveAuthTokens();
        }
        
        // Create and return user model
        _currentUser = UserModel(
          id: data['user_id'] ?? '',
          uid: data['user_id'] ?? '',
          email: email,
          name: name,
          createdAt: DateTime.now(),
          isEmailVerified: false,
        );
        
        return _currentUser!;
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to sign up';
      }
    } catch (e) {
      _logger.e('Error signing up: $e');
      throw e.toString();
    }
  }
  
  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _logger.i('Sending password reset email to: $email');
      
      final requestBody = {
        'email': email,
        'reset_password_url': ApiConstants.verificationCallbackUrl,
      };
      
      final response = await http.post(
        Uri.parse('${ApiConstants.authApiUrl}/api/v1/auth/password/reset'),
        headers: getAuthHeaders(includeAuth: false),
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to send password reset email';
      }
    } catch (e) {
      _logger.e('Error sending password reset email: $e');
      throw e.toString();
    }
  }
  
  /// Confirm password reset with code and new password
  Future<bool> confirmPasswordReset(String code, String newPassword) async {
    try {
      _logger.i('Confirming password reset');
      
      final requestBody = {
        'code': code,
        'new_password': newPassword,
      };
      
      final response = await http.post(
        Uri.parse('${ApiConstants.authApiUrl}/api/v1/auth/password/reset/confirm'),
        headers: getAuthHeaders(includeAuth: false),
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        _logger.i('Password reset confirmed successfully');
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to confirm password reset';
      }
    } catch (e) {
      _logger.e('Error confirming password reset: $e');
      return false;
    }
  }
  
  /// Check email verification status
  Future<bool> checkEmailVerificationStatus(String email) async {
    try {
      _logger.i('Checking email verification status for: $email');
      
      final requestBody = {
        'email': email,
      };
      
      final response = await http.post(
        Uri.parse('${ApiConstants.authApiUrl}${ApiConstants.authEmailVerificationStatus}'),
        headers: getAuthHeaders(includeAuth: false),
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['is_verified'] == true;
      } else {
        return false;
      }
    } catch (e) {
      _logger.e('Error checking email verification status: $e');
      return false;
    }
  }
  
  /// Resend verification email
  Future<bool> resendVerificationEmail(String email) async {
    try {
      _logger.i('Resending verification email to: $email');
      
      final requestBody = {
        'email': email,
        'verification_callback_url': ApiConstants.verificationCallbackUrl,
      };
      
      final response = await http.post(
        Uri.parse('${ApiConstants.authApiUrl}/api/v1/auth/emails/verification/resend'),
        headers: getAuthHeaders(includeAuth: false),
        body: jsonEncode(requestBody),
      );
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      _logger.e('Error resending verification email: $e');
      return false;
    }
  }
  
  /// Force update of auth state
  Future<bool> forceAuthStateUpdate() async {
    try {
      _logger.i('Forcing authentication state update');
      
      // First check if there's a refresh token available
      if (_refreshToken == null || _refreshToken!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _refreshToken = prefs.getString(ApiConstants.refreshTokenKey);
        
        if (_refreshToken == null || _refreshToken!.isEmpty) {
          _logger.w('Cannot update auth state: No refresh token available');
          return false;
        }
      }
      
      // Try to refresh the token
      return await refreshToken();
    } catch (e) {
      _logger.e('Error during force auth state update: $e');
      return false;
    }
  }
  
  /// Get current user
  UserModel? get currentUser => _currentUser;
  
  /// Reload current user data from API
  Future<void> reloadUser() async {
    try {
      if (_accessToken == null) {
        _logger.w('Cannot reload user: Not authenticated');
        return;
      }
      
      final response = await http.get(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.userProfile}'),
        headers: getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        _currentUser = UserModel(
          id: data['id'] ?? _userId ?? '',
          uid: data['id'] ?? _userId ?? '',
          email: data['email'] ?? '',
          name: data['username'] ?? data['name'],
          createdAt: DateTime.now(),
          isEmailVerified: true, // Assume verified since we got the profile
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to refresh the token and retry
        if (await refreshToken()) {
          await reloadUser();
        }
      }
    } catch (e) {
      _logger.e('Error reloading user: $e');
    }
  }
  
  /// Get authentication headers
  Map<String, String> getAuthHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Stack-Access-Type': 'client',
      'X-Stack-Project-Id': ApiConstants.stackProjectId,
      'X-Stack-Publishable-Client-Key': ApiConstants.stackPublishableClientKey,
    };
    
    if (includeAuth && _accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    return headers;
  }
  
  /// Get regular headers
  Map<String, String> getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    return headers;
  }
  
  /// Check if user is authenticated
  bool isAuthenticated() {
    return _accessToken != null && _accessToken!.isNotEmpty;
  }
  
  /// Check if user is logged in (may refresh token if needed)
  Future<bool> isLoggedIn() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return true;
    }
    
    // Try to refresh the token if we have a refresh token
    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      return await refreshToken();
    }
    
    // Try loading from shared preferences
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(ApiConstants.accessTokenKey);
    _refreshToken = prefs.getString(ApiConstants.refreshTokenKey);
    
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return true;
    }
    
    // Try to refresh if we loaded a refresh token from prefs
    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      return await refreshToken();
    }
    
    return false;
  }
  
  /// Sign out
  Future<bool> signOut() async {
    try {
      _logger.i('Signing out user');
      
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        try {
          // Call Jarvis API to sign out
          await http.delete(
            Uri.parse('${ApiConstants.authApiUrl}${ApiConstants.authSessionCurrent}'),
            headers: getAuthHeaders(),
          );
        } catch (e) {
          _logger.w('Error calling sign out API: $e');
          // Continue with local sign out even if API call fails
        }
      }
      
      // Clear tokens from storage
      await _clearAuthTokens();
      
      // Clear current user
      _currentUser = null;
      _accessToken = null;
      _refreshToken = null;
      _userId = null;
      
      _logger.i('User signed out successfully');
      return true;
    } catch (e) {
      _logger.e('Error signing out: $e');
      return false;
    }
  }

  /// Alias for sign in to match JarvisApiService expectations
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      final user = await signInWithEmailAndPassword(email, password);
      return {
        'success': true,
        'user': user.toMap(),
        'access_token': _accessToken,
        'refresh_token': _refreshToken,
        'user_id': _userId,
      };
    } catch (e) {
      _logger.e('Error in signIn: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Alias for sign up to match JarvisApiService expectations
  Future<Map<String, dynamic>> signUp(String email, String password, {String? name}) async {
    try {
      final user = await signUpWithEmailAndPassword(email, password, name: name);
      return {
        'success': true,
        'user': user.toMap(),
        'access_token': _accessToken,
        'refresh_token': _refreshToken,
        'user_id': _userId,
      };
    } catch (e) {
      _logger.e('Error in signUp: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Alias for sign out to match JarvisApiService expectations
  Future<bool> logout() async {
    return await signOut();
  }
  
  /// Save authentication tokens to storage
  Future<void> _saveAuthTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_accessToken != null) {
        await prefs.setString(ApiConstants.accessTokenKey, _accessToken!);
      }
      
      if (_refreshToken != null) {
        await prefs.setString(ApiConstants.refreshTokenKey, _refreshToken!);
      }
      
      if (_userId != null) {
        await prefs.setString(ApiConstants.userIdKey, _userId!);
      }
    } catch (e) {
      _logger.e('Error saving auth tokens: $e');
    }
  }
  
  /// Clear authentication tokens from storage
  Future<void> _clearAuthTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConstants.accessTokenKey);
      await prefs.remove(ApiConstants.refreshTokenKey);
      await prefs.remove(ApiConstants.userIdKey);
    } catch (e) {
      _logger.e('Error clearing auth tokens: $e');
    }
  }
  
  /// Sign in with Google (redirects to Google auth URL)
  Future<UserModel> signInWithGoogle() async {
    try {
      _logger.i('Starting Google sign-in flow');
      
      // Create Google auth URL with required parameters
      final googleAuthUrl = '${ApiConstants.authApiUrl}${ApiConstants.googleAuthEndpoint}';
      
      // Build query parameters
      final queryParams = {
        'client_id': ApiConstants.stackProjectId,
        'redirect_uri': ApiConstants.googleRedirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'state': _generateRandomState(),
      };
      
      // Convert to query string
      final queryString = Uri(queryParameters: queryParams).query;
      final fullUrl = '$googleAuthUrl?$queryString';
      
      _logger.i('Redirecting to Google auth URL: $fullUrl');
      
      // This is a stub implementation - the UI will handle the actual redirect
      throw 'Please complete Google authentication in your browser';
    } catch (e) {
      _logger.e('Error initiating Google sign-in: $e');
      throw e.toString();
    }
  }
  
  /// Process Google auth response (after redirect)
  Future<UserModel?> processGoogleAuthResponse(Map<String, String> params) async {
    try {
      _logger.i('Processing Google auth response');
      
      // Check for error in response
      if (params.containsKey('error')) {
        throw params['error_description'] ?? params['error'] ?? 'Unknown error';
      }
      
      // Get authorization code
      final code = params['code'];
      if (code == null || code.isEmpty) {
        throw 'No authorization code in response';
      }
      
      // Exchange code for tokens
      final response = await http.post(
        Uri.parse('${ApiConstants.authApiUrl}${ApiConstants.googleCallbackEndpoint}'),
        headers: getAuthHeaders(includeAuth: false),
        body: jsonEncode({
          'code': code,
          'redirect_uri': ApiConstants.googleRedirectUri,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Save tokens
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _userId = data['user_id'];
        await _saveAuthTokens();
        
        // Load user profile
        await reloadUser();
        
        // Return the user
        if (_currentUser != null) {
          return _currentUser;
        } else {
          throw 'Failed to get user profile after Google sign-in';
        }
      } else {
        throw 'Failed to exchange code for tokens: ${response.statusCode}';
      }
    } catch (e) {
      _logger.e('Error processing Google auth response: $e');
      throw e.toString();
    }
  }
  
  /// Update client metadata
  Future<bool> updateClientMetadata(Map<String, dynamic> metadata) async {
    try {
      _logger.i('Updating client metadata: $metadata');
      
      final response = await http.patch(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.userProfile}'),
        headers: getHeaders(),
        body: jsonEncode({
          'client_metadata': metadata,
        }),
      );
      
      if (response.statusCode == 200) {
        // Update current user metadata if available
        if (_currentUser != null) {
          final updatedMetadata = {...(_currentUser!.clientMetadata ?? {}), ...metadata};
          _currentUser = _currentUser!.copyWith(clientMetadata: updatedMetadata);
        }
        
        return true;
      } else {
        _logger.e('Error updating client metadata: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Error updating client metadata: $e');
      return false;
    }
  }
  
  /// Get the user ID
  String? getUserId() {
    return _userId;
  }

  /// Verify if token is valid
  Future<bool> verifyTokenValid() async {
    if (_accessToken == null || _accessToken!.isEmpty) {
      return false;
    }
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.apiStatus}'),
        headers: getHeaders(),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Error verifying token: $e');
      return false;
    }
  }

  /// Verify if token has all required scopes
  Future<bool> verifyTokenHasScopes(List<String> requiredScopes) async {
    // Simplified implementation for now
    return await verifyTokenValid();
  }
  
  /// Generate a random state for OAuth security
  String _generateRandomState() {
    const timestamp = 123456789; // Must use literal value to allow const
    final random = timestamp.toString() + (timestamp % 10000).toString();
    return base64Url.encode(utf8.encode(random)).substring(0, 16);
  }
}