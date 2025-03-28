import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../../../models/user_model.dart';
import '../../../constants/api_constants.dart';
import 'auth_service.dart';

/// Service for user profile and metadata management
class UserService {
  final Logger _logger = Logger();
  final AuthService _authService;
  final String _jarvisApiUrl = ApiConstants.jarvisApiUrl;
  final String _authApiUrl = ApiConstants.authApiUrl;
  
  UserService(this._authService);
  
  /// Get the current user's profile
  Future<UserModel?> getCurrentUser() async {
    try {
      if (!_authService.isAuthenticated()) {
        _logger.w('Cannot get current user: Not authenticated');
        return null;
      }

      _logger.i('Getting current user profile');

      final response = await http.get(
        Uri.parse('$_jarvisApiUrl/api/v1/user/profile'),
        headers: _authService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data['data'] ?? data;

        _logger.i('Successfully retrieved user profile');

        // Extract metadata from Stack Auth response
        Map<String, dynamic>? clientMetadata;
        Map<String, dynamic>? clientReadOnlyMetadata;
        Map<String, dynamic>? serverMetadata;
        
        // Check if metadata fields exist in response
        if (userData.containsKey('client_metadata')) {
          clientMetadata = userData['client_metadata'];
        }
        
        if (userData.containsKey('client_read_only_metadata')) {
          clientReadOnlyMetadata = userData['client_read_only_metadata'];
        }
        
        if (userData.containsKey('server_metadata')) {
          serverMetadata = userData['server_metadata'];
        }

        return UserModel(
          uid: userData['id'] ?? _authService.getUserId() ?? '',
          email: userData['email'] ?? '',
          name: userData['name'],
          createdAt: userData['created_at'] != null
              ? DateTime.parse(userData['created_at'])
              : DateTime.now(),
          isEmailVerified: userData['email_verified'] ?? true,
          selectedModel: userData['selected_model'] ?? ApiConstants.defaultModel,
          clientMetadata: clientMetadata,
          clientReadOnlyMetadata: clientReadOnlyMetadata,
          serverMetadata: serverMetadata,
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _logger.w('Authentication error (${response.statusCode}) when getting user profile, attempting token refresh');

        final refreshSuccess = await _authService.refreshToken();
        if (refreshSuccess) {
          _logger.i('Token refreshed successfully, retrying get user profile');
          return await getCurrentUser(); // Recursive call after refresh
        }
        
        _logger.w('Token refresh failed, user may need to re-authenticate');
        return null;
      } else {
        _logger.w('Failed to get current user: ${response.statusCode}');

        if (_authService.getUserId() != null) {
          _logger.i('Creating fallback user model with stored user ID: ${_authService.getUserId()}');
          return UserModel(
            uid: _authService.getUserId()!,
            email: '',
            createdAt: DateTime.now(),
            isEmailVerified: true,
          );
        }

        return null;
      }
    } catch (e) {
      _logger.e('Get current user error: $e');
      return null;
    }
  }
  
  /// Update the user's profile
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final apiData = {};
      data.forEach((key, value) {
        final snakeKey = key.replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        );
        apiData[snakeKey] = value;
      });

      final response = await http.put(
        Uri.parse('$_jarvisApiUrl/user/profile'),
        headers: _authService.getHeaders(),
        body: jsonEncode(apiData),
      );

      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Update user profile error: $e');
      return false;
    }
  }
  
  /// Change the user's password
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$_jarvisApiUrl/user/change-password'),
        headers: _authService.getHeaders(),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Change password error: $e');
      return false;
    }
  }
  
  /// Update user metadata (client, server, or client read-only)
  Future<bool> updateUserMetadata(Map<String, dynamic> metadata, String type) async {
    try {
      _logger.i('Updating user $type metadata');
      
      // Only client metadata can be updated from client side
      if (type != 'client') {
        _logger.w('$type metadata update requires server privileges and cannot be performed from client app');
        return false;
      }
      
      final response = await http.patch(
        Uri.parse('$_jarvisApiUrl/user/metadata/client'),
        headers: _authService.getHeaders(),
        body: jsonEncode(metadata),
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        _logger.i('$type metadata updated successfully');
        return true;
      } else {
        _logger.e('Failed to update $type metadata: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Error updating $type metadata: $e');
      return false;
    }
  }
  
  /// Check the email verification status
  Future<Map<String, dynamic>?> checkEmailVerificationStatus() async {
    try {
      if (!_authService.isAuthenticated()) {
        _logger.w('Cannot check verification status without being authenticated');
        return null;
      }

      _logger.i('Checking email verification status directly');

      final response = await http.get(
        Uri.parse('$_authApiUrl${ApiConstants.authEmailVerificationStatus}'),
        headers: _authService.getAuthHeaders(includeAuth: true),
      );

      _logger.i('Verification status check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.i('Verification status data: $data');
        return data['data'] ?? data;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        final refreshSuccess = await _authService.refreshToken();
        if (refreshSuccess) {
          return await checkEmailVerificationStatus();
        }
      }

      _logger.w('Verification status check failed, defaulting to verified');
      return {'is_verified': true, 'email': ''};
    } catch (e) {
      _logger.e('Error checking verification status: $e');
      return {'is_verified': true, 'email': ''};
    }
  }
}
