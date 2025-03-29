import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../../../models/user_model.dart';
import '../../../constants/api_constants.dart';
import '../../auth/auth_service.dart';

/// Service for user-related operations
class UserService {
  final Logger _logger = Logger();
  final AuthService _authService;
  
  UserService(this._authService);
  
  /// Get the current user's profile
  Future<UserModel?> getCurrentUser() async {
    try {
      _logger.i('Getting current user profile');
      
      final headers = _authService.getHeaders();
      
      final response = await http.get(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.userProfile}'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Create a user model from the response
        final user = UserModel(
          id: data['id'] ?? data['user_id'] ?? '',
          uid: data['id'] ?? data['user_id'] ?? '',
          email: data['email'] ?? '',
          name: data['name'] ?? data['username'],
          createdAt: DateTime.now(),
          isEmailVerified: data['email_verified'] ?? true,
          clientMetadata: data['client_metadata'],
          clientReadOnlyMetadata: data['client_read_only_metadata'],
          serverMetadata: data['server_metadata'],
        );
        
        return user;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to refresh token and retry
        final refreshed = await _authService.refreshToken();
        
        if (refreshed) {
          return await getCurrentUser();
        } else {
          _logger.w('Failed to refresh token, cannot get user profile');
          return null;
        }
      } else {
        _logger.e('Error getting user profile: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Error getting current user: $e');
      return null;
    }
  }
  
  /// Update the user's profile
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      _logger.i('Updating user profile: $data');
      
      final response = await http.patch(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.userProfile}'),
        headers: _authService.getHeaders(),
        body: jsonEncode(data),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Error updating user profile: $e');
      return false;
    }
  }
  
  /// Change the user's password
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      _logger.i('Changing user password');
      
      final response = await http.post(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.userChangePassword}'),
        headers: _authService.getHeaders(),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Error changing password: $e');
      return false;
    }
  }
  
  /// Update the user's metadata (client, server, or client_read_only)
  Future<bool> updateUserMetadata(Map<String, dynamic> metadata, String type) async {
    try {
      _logger.i('Updating user $type metadata');
      
      final data = {
        '${type}_metadata': metadata,
      };
      
      final response = await http.patch(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.userProfile}'),
        headers: _authService.getHeaders(),
        body: jsonEncode(data),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Error updating user metadata: $e');
      return false;
    }
  }
  
  /// Check the email verification status
  Future<Map<String, dynamic>?> checkEmailVerificationStatus() async {
    try {
      _logger.i('Checking email verification status');
      
      final user = await getCurrentUser();
      
      if (user != null) {
        return {
          'is_verified': user.isEmailVerified,
          'email': user.email,
        };
      }
      
      return null;
    } catch (e) {
      _logger.e('Error checking email verification status: $e');
      return null;
    }
  }
}
