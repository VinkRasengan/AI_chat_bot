import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants/api_constants.dart';

/// Service for authentication and token management
class AuthService {
  final Logger _logger = Logger();
  
  final String _authApiUrl = ApiConstants.authApiUrl;
  final String _jarvisApiUrl = ApiConstants.jarvisApiUrl;
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _apiKey;
  String? _stackProjectId;
  String? _stackPublishableClientKey;
  
  // Circuit breaker to prevent infinite refresh loops
  int _refreshAttempts = 0;
  static const int _maxRefreshAttempts = 2;
  DateTime? _lastRefreshAttempt;

  // Track current refresh attempt to prevent multiple simultaneous refreshes
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;
  
  Future<void> initialize(String? apiKey) async {
    try {
      _logger.i('Initializing Auth Service');
      
      _apiKey = apiKey;
      _stackProjectId = ApiConstants.stackProjectId;
      _stackPublishableClientKey = ApiConstants.stackPublishableClientKey;
      
      await _loadAuthToken();
    } catch (e) {
      _logger.e('Error initializing Auth Service: $e');
    }
  }
  
  Future<Map<String, dynamic>> signUp(String email, String password, {String? name}) async {
    try {
      _logger.i('Attempting sign-up for email: $email');
      
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

      final url = Uri.parse('$_authApiUrl${ApiConstants.authPasswordSignUp}');
      
      // Include all required headers
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Stack-Access-Type': 'client',
        'X-Stack-Project-Id': _stackProjectId ?? ApiConstants.stackProjectId,
        'X-Stack-Publishable-Client-Key': _stackPublishableClientKey ?? ApiConstants.stackPublishableClientKey,
      };

      if (_apiKey != null && _apiKey!.isNotEmpty) {
        headers['X-API-KEY'] = _apiKey!;
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      _logger.i('Sign-up response status code: ${response.statusCode}');

      if (response.statusCode == 404 || response.statusCode == 405) {
        _logger.e('Possible API configuration issue: ${response.statusCode}');
        throw 'Endpoint not found. Please contact support with error code: AUTH-404-${DateTime.now().millisecondsSinceEpoch}';
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        _logger.e('Error parsing response JSON: $e');
        throw 'Invalid response from server: ${response.body}';
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String? userId;
        if (data['access_token'] != null) {
          userId = data['user_id'];
          await _saveAuthToken(
            data['access_token'],
            data['refresh_token'],
            userId,
          );
          _logger.i('Authentication tokens saved successfully');
        } else {
          _logger.w('No access token in successful response');
        }
        return data;
      } else {
        final errorMessage = data['message'] ?? data['error'] ?? 'Unknown error during sign up';
        throw errorMessage;
      }
    } catch (e) {
      _logger.e('Sign up error: $e');
      
      // Add more specific error handling
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        throw 'Cannot connect to Jarvis API. Please check your internet connection and API configuration.';
      } else if (e.toString().contains('404') || 
                e.toString().contains('Cannot POST')) {
        throw 'API endpoint not found. Please verify the API configuration and contact support.';
      }
      
      throw e.toString();
    }
  }
  
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      _logger.i('Attempting sign-in for email: $email');

      // Prepare request body according to API specification
      final requestBody = {
        'email': email,
        'password': password,
      };

      final url = Uri.parse('$_authApiUrl${ApiConstants.authPasswordSignIn}');
      
      // Include all required headers as specified in the API documentation
      final headers = {
        'Content-Type': 'application/json',
        'X-Stack-Access-Type': 'client',
        'X-Stack-Project-Id': _stackProjectId ?? ApiConstants.stackProjectId,
        'X-Stack-Publishable-Client-Key': _stackPublishableClientKey ?? ApiConstants.stackPublishableClientKey,
      };

      // Only add API key if available (not in the API documentation but might be needed)
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        headers['X-API-KEY'] = _apiKey!;
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      _logger.i('Sign-in response status code: ${response.statusCode}');

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        _logger.e('Error parsing response JSON: $e');
        throw 'Invalid response from server';
      }

      if (response.statusCode == 200) {
        if (data.containsKey('access_token') && 
            data.containsKey('refresh_token') && 
            data.containsKey('user_id')) {
          
          // Save authentication tokens
          await _saveAuthToken(
            data['access_token'],
            data['refresh_token'],
            data['user_id'],
          );
          
          _logger.i('Authentication tokens saved successfully');
        } else {
          _logger.w('Response missing required fields: ${data.keys}');
        }
        
        return data;
      } else {
        final errorMessage = data['message'] ?? data['error'] ?? 'Unknown error during sign in';
        throw errorMessage;
      }
    } catch (e) {
      _logger.e('Sign in error: $e');
      throw e.toString();
    }
  }
  
  Future<bool> refreshToken() async {
    try {
      // Prevent multiple simultaneous refresh attempts
      if (_isRefreshing) {
        _logger.i('Token refresh already in progress, waiting...');
        // If a refresh just happened (<5 seconds ago), reuse that result instead of waiting
        if (_lastRefreshTime != null && 
            DateTime.now().difference(_lastRefreshTime!).inSeconds < 5) {
          _logger.i('Using recent refresh result');
          return _accessToken != null;
        }
        
        // Wait for the current refresh to complete (with timeout)
        int attempts = 0;
        while (_isRefreshing && attempts < 10) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
        return _accessToken != null;
      }
      
      _isRefreshing = true;
      
      // Check if we have a refresh token before attempting to refresh
      if (_refreshToken == null || _refreshToken!.isEmpty) {
        _logger.w('Cannot refresh token: No refresh token available');
        // Load from preferences in case it's there but wasn't loaded into memory
        final prefs = await SharedPreferences.getInstance();
        _refreshToken = prefs.getString(ApiConstants.refreshTokenKey);
        
        if (_refreshToken == null || _refreshToken!.isEmpty) {
          _isRefreshing = false;
          return false;
        }
      }

      // Circuit breaker - prevent too many refresh attempts in a short time
      final now = DateTime.now();
      if (_lastRefreshAttempt != null && 
          now.difference(_lastRefreshAttempt!).inSeconds < 10 &&
          _refreshAttempts >= _maxRefreshAttempts) {
        _logger.w('Too many token refresh attempts. Switching to Gemini API fallback mode.');
        _isRefreshing = false;
        return false;
      }
      
      _lastRefreshAttempt = now;
      _refreshAttempts++;

      _logger.i('Attempting to refresh auth token (attempt $_refreshAttempts)');

      // Set up headers according to API documentation
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Stack-Access-Type': 'client',
        'X-Stack-Project-Id': _stackProjectId ?? ApiConstants.stackProjectId,
        'X-Stack-Publishable-Client-Key': _stackPublishableClientKey ?? ApiConstants.stackPublishableClientKey,
        'X-Stack-Refresh-Token': _refreshToken!,
      };

      if (_apiKey != null && _apiKey!.isNotEmpty) {
        headers['X-API-KEY'] = _apiKey!;
      }

      // Add an empty JSON body to satisfy the API's requirement
      final response = await http.post(
        Uri.parse('$_authApiUrl${ApiConstants.authSessionRefresh}'),
        headers: headers,
        body: '{}', // Empty JSON object
      );

      _logger.i('Token refresh response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);

          if (data['access_token'] != null) {
            // Save the new access token but keep the current refresh token
            await _saveAuthToken(
              data['access_token'],
              _refreshToken,
              _userId,
            );
            _logger.i('Access token refreshed successfully');
            
            // Test the new token immediately to ensure it works
            final testResult = await _testRefreshedToken();
            if (!testResult) {
              _logger.w('Refreshed token failed validation test');
            }
            
            // Reset refresh attempts counter on success
            _refreshAttempts = 0;
            _lastRefreshTime = DateTime.now();
            _isRefreshing = false;
            
            return true;
          } else {
            _logger.w('No access token in refresh response');
            _isRefreshing = false;
            return false;
          }
        } catch (e) {
          _logger.e('Error parsing refresh token response: $e');
          _isRefreshing = false;
          return false;
        }
      } else {
        try {
          final responseText = response.body;
          _logger.e('Token refresh failed with status ${response.statusCode}: $responseText');

          if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 403) {
            _logger.i('Clearing invalid tokens due to authentication error');
            await clearAuthToken();
          }

          _isRefreshing = false;
          return false;
        } catch (e) {
          _logger.e('Error processing token refresh error: $e');
          _isRefreshing = false;
          return false;
        }
      }
    } catch (e) {
      _logger.e('Token refresh error: $e');
      _isRefreshing = false;
      return false;
    }
  }

  Future<bool> logout() async {
    try {
      if (_accessToken == null) {
        _logger.w('No active session to logout from');
        return true;
      }

      _logger.i('Attempting to logout user');

      // Prepare headers exactly as specified in API documentation
      final headers = {
        'Content-Type': 'application/json',
        'X-Stack-Access-Type': 'client',
        'X-Stack-Project-Id': _stackProjectId ?? ApiConstants.stackProjectId,
        'X-Stack-Publishable-Client-Key': _stackPublishableClientKey ?? ApiConstants.stackPublishableClientKey,
      };
      
      // Add Authorization header if we have a token
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_accessToken';
      }
      
      // Add refresh token if available
      if (_refreshToken != null && _refreshToken!.isNotEmpty) {
        headers['X-Stack-Refresh-Token'] = _refreshToken!;
      }

      final response = await http.delete(
        Uri.parse('$_authApiUrl${ApiConstants.authSessionCurrent}'),
        headers: headers,
        body: '{}',  // Empty JSON object as required by the API
      );

      _logger.i('Logout response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          // According to API docs, the endpoint returns new tokens on success
          // Parse them in case they're needed for post-logout operations
          final data = jsonDecode(response.body);
          
          if (data.containsKey('access_token')) {
            _logger.i('Received new tokens after logout');
            // We don't save these tokens since we're logging out
          }
          
          // Clear local tokens
          await clearAuthToken();
          _logger.i('Logout successful, tokens cleared');
          return true;
        } catch (e) {
          _logger.w('Error parsing logout response: $e');
          await clearAuthToken();
          return true; // Still consider logout successful
        }
      } else if (response.statusCode == 204) {
        // No content response is also considered successful
        await clearAuthToken();
        _logger.i('Logout successful (204 No Content), tokens cleared');
        return true;
      } else {
        _logger.e('Logout failed with status code: ${response.statusCode}');
        
        // Try to parse error response
        try {
          final errorData = jsonDecode(response.body);
          _logger.e('Logout error response: $errorData');
        } catch (e) {
          // Ignore JSON parsing errors
        }
        
        // Clear tokens locally even if the server request failed
        await clearAuthToken();
        _logger.w('Cleared local tokens despite server logout failure');
        return false;
      }
    } catch (e) {
      _logger.e('Logout error: $e');
      // Clear tokens locally even if the request fails
      await clearAuthToken();
      return false;
    }
  }

  Future<bool> forceTokenRefresh() async {
    try {
      _logger.i('Forcing token refresh');

      if (_refreshToken == null) {
        _logger.w('Cannot force refresh without a refresh token');
        return false;
      }

      _accessToken = null;

      return await refreshToken();
    } catch (e) {
      _logger.e('Force token refresh error: $e');
      return false;
    }
  }

  Future<bool> verifyTokenValid() async {
    try {
      if (_accessToken == null) {
        return false;
      }

      final response = await http.get(
        Uri.parse('$_jarvisApiUrl/api/v1/status'),
        headers: getHeaders(),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return await refreshToken();
      } else {
        return false;
      }
    } catch (e) {
      _logger.e('Token verification error: $e');
      return false;
    }
  }

  Future<bool> verifyTokenHasScopes(List<String> requiredScopes) async {
    try {
      _logger.i('Checking if token has required scopes: $requiredScopes');
      
      if (_accessToken == null) {
        _logger.w('No access token available to check scopes');
        return false;
      }
      
      // Parse the JWT and check scopes
      final parts = _accessToken!.split('.');
      if (parts.length != 3) {
        _logger.w('Invalid JWT format');
        return false;
      }
      
      String payload = parts[1];
      payload = base64.normalize(payload);
      
      try {
        final decoded = utf8.decode(base64.decode(payload));
        final data = jsonDecode(decoded);
        
        // Check if token has scope claim
        if (!data.containsKey('scope')) {
          _logger.w('Token does not contain scope claim');
          return false;
        }
        
        // Parse scopes from space-delimited string
        final tokenScopes = (data['scope'] as String).split(' ');
        _logger.i('Token has scopes: $tokenScopes');
        
        // Check if all required scopes are present
        final missingScopes = requiredScopes
            .where((scope) => !tokenScopes.contains(scope))
            .toList();
            
        if (missingScopes.isNotEmpty) {
          _logger.w('Token is missing required scopes: $missingScopes');
          return false;
        }
        
        _logger.i('Token has all required scopes');
        return true;
      } catch (e) {
        _logger.e('Error parsing token payload: $e');
        return false;
      }
    } catch (e) {
      _logger.e('Error checking token scopes: $e');
      return false;
    }
  }

  // Helper method to refresh token after testing
  Future<bool> _testRefreshedToken() async {
    try {
      // First check token format to ensure scopes are present
      if (_accessToken != null) {
        _logTokenInfo(_accessToken!);
      }
      
      // Use a simpler endpoint for testing token validity - status is more reliable
      final response = await http.get(
        Uri.parse('$_jarvisApiUrl/api/v1/status'),
        headers: getHeaders(),
      ).timeout(const Duration(seconds: 3));
      
      _logger.i('Token test response: [${response.statusCode}] ${response.reasonPhrase}');
      
      // Consider these status codes as successful for token validation
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      _logger.w('Error testing refreshed token: $e');
      return false;
    }
  }
  
  // Decode and log token information for debugging
  void _logTokenInfo(String token) {
    try {
      // Extract the payload part of the JWT (second part)
      final parts = token.split('.');
      if (parts.length != 3) {
        _logger.w('Invalid JWT format');
        return;
      }
      
      // Decode the base64 payload
      String payload = parts[1];
      // Add any necessary padding
      payload = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(payload));
      final data = jsonDecode(decoded);
      
      // Log key token information 
      _logger.i('Token info:');
      _logger.i('- Subject: ${data['sub'] ?? 'not found'}');
      _logger.i('- Expiration: ${data['exp'] != null ? DateTime.fromMillisecondsSinceEpoch(data['exp'] * 1000) : 'not found'}');
      
      // Check if token uses Stack Auth format
      if (data.containsKey('iss')) {
        _logger.i('- Issuer: ${data['iss'] ?? 'not found'}');
      }
      
      // Log scopes if available
      if (data.containsKey('scope')) {
        final scopes = data['scope'];
        _logger.i('- Scopes: $scopes');
      } else {
        _logger.w('No scopes found in token');
      }
    } catch (e) {
      _logger.e('Error decoding token: $e');
    }
  }

  // Auth token management
  Future<void> _loadAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(ApiConstants.accessTokenKey);
      _refreshToken = prefs.getString(ApiConstants.refreshTokenKey);
      _userId = prefs.getString(ApiConstants.userIdKey);
    } catch (e) {
      _logger.e('Error loading auth token: $e');
    }
  }

  Future<void> _saveAuthToken(String accessToken, String? refreshToken, String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.accessTokenKey, accessToken);
      _accessToken = accessToken;

      if (refreshToken != null) {
        await prefs.setString(ApiConstants.refreshTokenKey, refreshToken);
        _refreshToken = refreshToken;
      }

      if (userId != null) {
        await prefs.setString(ApiConstants.userIdKey, userId);
        _userId = userId;
      }
    } catch (e) {
      _logger.e('Error saving auth token: $e');
    }
  }

  Future<void> clearAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConstants.accessTokenKey);
      await prefs.remove(ApiConstants.refreshTokenKey);
      await prefs.remove(ApiConstants.userIdKey);
      _accessToken = null;
      _refreshToken = null;
      _userId = null;
    } catch (e) {
      _logger.e('Error clearing auth token: $e');
    }
  }

  // Header utility methods
  Map<String, String> getAuthHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Stack-Access-Type': 'client',
      'X-Stack-Project-Id': _stackProjectId ?? ApiConstants.stackProjectId,
      'X-Stack-Publishable-Client-Key': _stackPublishableClientKey ?? ApiConstants.stackPublishableClientKey,
    };

    if (_apiKey != null && _apiKey!.isNotEmpty) {
      headers['X-API-KEY'] = _apiKey!;
    }

    if (includeAuth && _accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    return headers;
  }

  Map<String, String> getHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_apiKey != null && _apiKey!.isNotEmpty) {
      headers['X-API-KEY'] = _apiKey!;
    }

    if (includeAuth && _accessToken != null && _accessToken!.isNotEmpty) {
      // Ensure token is properly formatted with Bearer prefix
      if (_accessToken!.startsWith('Bearer ')) {
        headers['Authorization'] = _accessToken!;
      } else {
        headers['Authorization'] = 'Bearer $_accessToken';
      }
      
      // Include the stack authentication related headers as well
      headers['X-Stack-Access-Type'] = 'client';
      headers['X-Stack-Project-Id'] = _stackProjectId ?? ApiConstants.stackProjectId;
      headers['X-Stack-Publishable-Client-Key'] = _stackPublishableClientKey ?? ApiConstants.stackPublishableClientKey;
    }

    return headers;
  }
  
  // Status and info methods
  bool isAuthenticated() {
    return _accessToken != null;
  }

  String? getUserId() {
    return _userId;
  }
}
