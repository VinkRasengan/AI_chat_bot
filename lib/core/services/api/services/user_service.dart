import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  /// Get the current user profile from the API
  Future<UserModel?> getCurrentUser() async {
    try {
      _logger.i('Getting current user profile');
      
      // Use the correct endpoint from constants
      final response = await http.get(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.userProfile}'),
        headers: _authService.getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Create a user model from the response
        // Updated field mapping to match actual API response structure
        final user = UserModel(
          uid: data['id'] ?? '',
          email: data['email'] ?? '',
          name: data['username'] ?? '',
          createdAt: DateTime.now(), // API doesn't return creation date
          isEmailVerified: true, // Assuming verified since we got the profile
        );
        
        _logger.i('Got user profile: ${user.email}');
        return user;
      } else if (response.statusCode == 404) {
        // The user profile endpoint might not exist, so create a fallback user
        _logger.w('Failed to get current user: 404');
        
        // Get user ID from shared preferences
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString(ApiConstants.userIdKey);
        
        if (userId != null && userId.isNotEmpty) {
          _logger.i('Creating fallback user model with stored user ID: $userId');
          
          return UserModel(
            uid: userId,
            email: '',
            createdAt: DateTime.now(),
            isEmailVerified: true,
          );
        }
        
        return null;
      } else {
        _logger.e('Failed to get current user: ${response.statusCode}');
        throw 'Failed to get user profile: ${response.reasonPhrase}';
      }
    } catch (e) {
      _logger.e('Error getting current user: $e');
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
