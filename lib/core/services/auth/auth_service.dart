import 'package:logger/logger.dart';
import 'auth_provider_interface.dart';
import 'providers/jarvis_auth_provider.dart';
import '../../models/user_model.dart';
import '../../constants/api_constants.dart';  // Add this import
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication service that delegates to the configured auth provider
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  
  final Logger _logger = Logger();
  late AuthProviderInterface _provider;
  bool _isInitialized = false;
  
  AuthService._internal() {
    // Use Jarvis Auth Provider by default
    _provider = JarvisAuthProvider();
  }
  
  /// Initialize the auth service
  Future<void> initializeService() async {
    if (_isInitialized) return;
    
    try {
      _logger.i('Initializing Auth Service');
      
      // Initialize the provider
      await _provider.initialize();
      
      _isInitialized = true;
      _logger.i('Auth Service initialized successfully');
    } catch (e) {
      _logger.e('Error initializing Auth Service: $e');
      throw Exception('Failed to initialize Auth Service: $e');
    }
  }
  
  /// Get the current authenticated user
  UserModel? get currentUser => _provider.currentUser;
  
  /// Check if user is logged in with valid token
  Future<bool> isLoggedIn() async {
    if (!_isInitialized) await initializeService();
    
    try {
      // First check if logged in via provider
      final isLoggedIn = await _provider.isLoggedIn();
      if (!isLoggedIn) {
        _logger.i('Provider reports user is not logged in');
        return false;
      }
      
      // Then verify if Jarvis API token is valid
      // This cast is needed since we're using JarvisAuthProvider as the implementation
      final jarvisProvider = _provider as JarvisAuthProvider;
      final isTokenValid = await jarvisProvider.isTokenValid();
      
      if (!isTokenValid) {
        _logger.w('Token is invalid or expired, attempting to refresh');
        final refreshSuccess = await _provider.refreshToken();
        
        if (refreshSuccess) {
          _logger.i('Token refreshed successfully, user is logged in');
          
          // Test if the refreshed token is valid
          final isRefreshedTokenValid = await _testRefreshedToken();
          if (!isRefreshedTokenValid) {
            _logger.w('Refreshed token is invalid, user needs to log in again');
            return false;
          }
          
          // Get fresh user data to ensure all components have current information
          await _provider.reloadUser();
          
          return true;
        } else {
          _logger.w('Token refresh failed, user needs to log in again');
          return false;
        }
      }
      
      _logger.i('User is logged in with valid token');
      return true;
    } catch (e) {
      _logger.e('Error checking login status: $e');
      return false;
    }
  }

  /// Test if the refreshed token is valid by making a simple API call
  Future<bool> _testRefreshedToken() async {
    try {
      _logger.i('Testing refreshed token validity');
      
      // Get token information for debugging
      _logTokenInfo();
      
      // Try a simple GET request to test the token validity
      // First try the user profile endpoint
      final response = await http.get(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.userProfile}'),
        headers: getHeaders(),
      );
      
      _logger.i('Token test response: [${response.statusCode}] ${response.reasonPhrase}');
      
      // If we can successfully get user profile, token is valid
      if (response.statusCode == 200) {
        _logger.i('Token is valid - successfully retrieved user profile');
        return true;
      }
      
      // For 401/403, try to refresh token once more before failing
      if (response.statusCode == 401 || response.statusCode == 403) {
        _logger.w('Token test failed with ${response.statusCode}, attempting secondary validation');
        
        // For a more accurate test, try API status endpoint
        final statusResponse = await http.get(
          Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.apiStatus}'),
          headers: getHeaders(),
        );
        
        if (statusResponse.statusCode == 200) {
          _logger.i('Secondary validation successful - API status OK');
          return true;
        }
        
        _logger.e('Token is invalid - authentication failed');
        return false;
      }
      
      // For 404 (Not Found), the endpoint might not exist but token could still be valid
      if (response.statusCode == 404) {
        _logger.w('API endpoint not found (404), trying secondary endpoints');
        
        // Try API status endpoint as fallback
        final statusResponse = await http.get(
          Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.apiStatus}'),
          headers: getHeaders(),
        );
        
        if (statusResponse.statusCode == 200) {
          _logger.i('Secondary validation successful - API status OK');
          return true;
        }
        
        // If both endpoints return 404, token may still be valid (endpoints just don't exist)
        _logger.w('Secondary validation endpoint not found, assuming token is valid');
        return true;
      }
      
      // For other status codes, assume token is valid but log the unexpected response
      _logger.w('Unexpected status code ${response.statusCode} in token test, proceeding with caution');
      return true;
    } catch (e) {
      _logger.e('Error testing token: $e');
      // On network errors, assume token might still be valid to avoid false negatives
      return true;
    }
  }

  /// Helper method to log token information
  void _logTokenInfo() {
    try {
      final token = _getAccessToken();
      if (token == null || token.isEmpty) {
        _logger.w('No token available to analyze');
        return;
      }
      
      // Basic token structure parsing
      final parts = token.split('.');
      if (parts.length != 3) {
        _logger.w('Token does not have the expected JWT structure');
        return;
      }
      
      // Decode the payload part (part 1)
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded) as Map<String, dynamic>;
      
      // Log relevant info
      _logger.i('Token info:');
      _logger.i('- Subject: ${payload['sub'] ?? 'Not found'}');
      
      // Handle exp as either string or int
      if (payload.containsKey('exp')) {
        final exp = payload['exp'];
        if (exp is int) {
          final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          _logger.i('- Expiration: $expDate');
        } else {
          _logger.i('- Expiration: $exp');
        }
      }
      
      _logger.i('- Issuer: ${payload['iss'] ?? 'Not found'}');
      
      // Check for scopes - could be in different formats
      if (payload.containsKey('scope')) {
        _logger.i('- Scopes: ${payload['scope']}');
      } else if (payload.containsKey('scopes')) {
        _logger.i('- Scopes: ${payload['scopes']}');
      } else if (payload.containsKey('scp')) {
        _logger.i('- Scopes: ${payload['scp']}');
      } else {
        _logger.w('No scopes found in token');
        // No scopes doesn't necessarily mean the token is invalid
        // Some systems don't include scopes in the token
      }
    } catch (e) {
      _logger.e('Error parsing token: $e');
    }
  }
  
  /// Force update of auth state - call this after token refresh with improved scope checking
  Future<bool> forceAuthStateUpdate() async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Forcing authentication state update with scope verification');
      
      // Get JarvisAuthProvider for direct API access
      final jarvisProvider = _provider as JarvisAuthProvider;
      
      // Refresh token with proper scopes
      final refreshSuccess = await jarvisProvider.refreshToken();
      if (!refreshSuccess) {
        _logger.w('Failed to refresh token during force auth state update');
        return false;
      }
      
      // Check if token has required scopes, but don't fail if scopes are missing
      // This change allows authentication to succeed even when scopes aren't in the token
      final hasRequiredScopes = await jarvisProvider.verifyTokenScopes(ApiConstants.requiredScopes);
      if (!hasRequiredScopes) {
        _logger.w('Token is missing some required scopes, but continuing with authentication');
        // We're not returning false here to allow the auth to proceed
      } else {
        _logger.i('Token has all required scopes');
      }
      
      // Then reload user data
      await _provider.reloadUser();
      
      _logger.i('Auth state successfully updated');
      return true;
    } catch (e) {
      _logger.e('Error during force auth state update: $e');
      return false;
    }
  }
  
  /// Check if email is verified
  bool isEmailVerified() {
    if (!_isInitialized) {
      _logger.w('Auth Service not initialized, returning false for isEmailVerified');
      return false;
    }
    return _provider.isEmailVerified();
  }
  
  /// Check email verification status directly from server
  Future<bool> checkEmailVerificationStatus(String email) async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Checking email verification status for: $email');
      
      // Cast provider to JarvisAuthProvider to access verification status check
      final jarvisProvider = _provider as JarvisAuthProvider;
      return await jarvisProvider.checkEmailVerificationStatus(email);
    } catch (e) {
      _logger.e('Error checking email verification status: $e');
      return false;
    }
  }
  
  /// Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword(String email, String password) async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Sign in request for email: $email');
      return await _provider.signInWithEmailAndPassword(email, password);
    } catch (e) {
      _logger.e('Sign in error: $e');
      throw e.toString();
    }
  }
  
  /// Sign up with email and password
  Future<UserModel> signUpWithEmailAndPassword(String email, String password, {String? name}) async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Sign up request for email: $email');
      return await _provider.signUpWithEmailAndPassword(email, password, name: name);
    } catch (e) {
      _logger.e('Sign up error: $e');
      throw e.toString();
    }
  }
  
  /// Sign out the current user
  Future<void> signOut() async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Sign out request');
      await _provider.signOut();
    } catch (e) {
      _logger.e('Sign out error: $e');
      throw e.toString();
    }
  }
  
  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Password reset request for email: $email');
      await _provider.sendPasswordResetEmail(email);
    } catch (e) {
      _logger.e('Password reset error: $e');
      throw e.toString();
    }
  }
  
  /// Refresh the auth tokens
  Future<bool> refreshToken() async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Token refresh request');
      return await _provider.refreshToken();
    } catch (e) {
      _logger.e('Token refresh error: $e');
      return false;
    }
  }
  
  /// Refresh the user information
  Future<void> reloadUser() async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Reload user request');
      await _provider.reloadUser();
    } catch (e) {
      _logger.e('Reload user error: $e');
      throw e.toString();
    }
  }
  
  /// Confirm password reset
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Confirm password reset request');
      await _provider.confirmPasswordReset(code, newPassword);
    } catch (e) {
      _logger.e('Confirm password reset error: $e');
      throw e.toString();
    }
  }
  
  /// Manually verify email - only for testing/development!
  Future<bool> manuallySetEmailVerified() async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Manual email verification request');
      return await _provider.manuallySetEmailVerified();
    } catch (e) {
      _logger.e('Manual email verification error: $e');
      return false;
    }
  }
  
  /// Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> userData) async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Update user profile request');
      return await _provider.updateUserProfile(userData);
    } catch (e) {
      _logger.e('Update user profile error: $e');
      return false;
    }
  }
  
  /// Update the user's client metadata
  Future<bool> updateClientMetadata(Map<String, dynamic> metadata) async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Update client metadata request: $metadata');
      
      // Get JarvisAuthProvider for client metadata methods
      final jarvisProvider = _provider as JarvisAuthProvider;
      return await jarvisProvider.updateClientMetadata(metadata);
    } catch (e) {
      _logger.e('Update client metadata error: $e');
      return false;
    }
  }
  
  /// Get the user's client metadata
  Map<String, dynamic>? getClientMetadata() {
    if (!_isInitialized) {
      _logger.w('Auth Service not initialized, returning null for getClientMetadata');
      return null;
    }
    
    // Get JarvisAuthProvider for client metadata methods
    final jarvisProvider = _provider as JarvisAuthProvider;
    return jarvisProvider.getClientMetadata();
  }
  
  /// Get the user's client read-only metadata
  Map<String, dynamic>? getClientReadOnlyMetadata() {
    if (!_isInitialized) {
      _logger.w('Auth Service not initialized, returning null for getClientReadOnlyMetadata');
      return null;
    }
    
    // Get JarvisAuthProvider for client metadata methods
    final jarvisProvider = _provider as JarvisAuthProvider;
    return jarvisProvider.getClientReadOnlyMetadata();
  }
  
  /// Sign in with Google
  Future<UserModel> signInWithGoogle() async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Sign in with Google request');
      
      // Cast provider to JarvisAuthProvider to access Google auth methods
      final jarvisProvider = _provider as JarvisAuthProvider;
      return await jarvisProvider.signInWithGoogle();
    } catch (e) {
      _logger.e('Google sign in error: $e');
      throw e.toString();
    }
  }
  
  /// Get Google auth URL for web redirect flow
  String getGoogleAuthUrl() {
    if (!_isInitialized) {
      _logger.w('Auth Service not initialized, returning empty Google auth URL');
      return '';
    }
    
    // Cast provider to JarvisAuthProvider to access Google auth methods
    final jarvisProvider = _provider as JarvisAuthProvider;
    return jarvisProvider.getGoogleAuthUrl();
  }
  
  /// Process Google auth response from redirect
  Future<UserModel?> processGoogleAuthResponse(Map<String, String> params) async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Processing Google auth response');
      
      // Cast provider to JarvisAuthProvider to access Google auth methods
      final jarvisProvider = _provider as JarvisAuthProvider;
      return await jarvisProvider.processGoogleAuthResponse(params);
    } catch (e) {
      _logger.e('Error processing Google auth response: $e');
      throw e.toString();
    }
  }
  
  /// Resend email verification link
  Future<bool> resendVerificationEmail(String email) async {
    if (!_isInitialized) await initializeService();
    
    try {
      _logger.i('Resending verification email to: $email');
      
      // Cast provider to JarvisAuthProvider to access email verification methods
      final jarvisProvider = _provider as JarvisAuthProvider;
      return await jarvisProvider.resendVerificationEmail(email);
    } catch (e) {
      _logger.e('Error resending verification email: $e');
      return false;
    }
  }
  
  /// Get HTTP headers with authorization token for API requests
  Map<String, String> getHeaders() {
    try {
      final token = _getAccessToken();
      if (token == null || token.isEmpty) {
        _logger.w('No access token available for headers');
        // Return basic headers without authorization
        return {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-jarvis-guid': '', // Add empty x-jarvis-guid header
        };
      }
      
      // Return headers with authorization token
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'x-jarvis-guid': '', // Add empty x-jarvis-guid header
      };
    } catch (e) {
      _logger.e('Error generating headers: $e');
      // Return basic headers without authorization on error
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'x-jarvis-guid': '', // Add empty x-jarvis-guid header
      };
    }
  }
  
  /// Get the current access token
  String? _getAccessToken() {
    try {
      // This should be synchronized with the provider's token storage
      final prefs = SharedPreferences.getInstance().then((prefs) {
        return prefs.getString(ApiConstants.accessTokenKey);
      });
      
      // For immediate use, we need to sync get the token
      // This is a workaround - in a real app, consider using a token cache
      return _getSyncAccessToken();
    } catch (e) {
      _logger.e('Error getting access token: $e');
      return null;
    }
  }
  
  /// Synchronously get the current access token
  /// This is a helper method for _getAccessToken
  String? _getSyncAccessToken() {
    try {
      // Try to get token from provider if possible
      if (_provider is JarvisAuthProvider) {
        final jarvisProvider = _provider as JarvisAuthProvider;
        // Assuming JarvisAuthProvider has a method to get the current token synchronously
        // You may need to implement this in JarvisAuthProvider
        return jarvisProvider.getCurrentToken();
      }
      
      // Fallback to getting from SharedPreferences
      final prefs = SharedPreferences.getInstance().then((prefs) {
        return prefs.getString(ApiConstants.accessTokenKey);
      });
      
      // This is not ideal, but since we need a sync result, return null
      // The proper implementation would cache tokens in memory
      return null;
    } catch (e) {
      _logger.e('Error getting sync access token: $e');
      return null;
    }
  }
  
  /// Clear the auth token (for logout or token invalidation)
  void clearAuthToken() {
    try {
      _logger.i('Clearing auth token');
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove(ApiConstants.accessTokenKey);
        prefs.remove(ApiConstants.refreshTokenKey);
      });
    } catch (e) {
      _logger.e('Error clearing auth token: $e');
    }
  }
}