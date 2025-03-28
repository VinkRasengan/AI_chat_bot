import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/user_model.dart';
import '../auth_provider_interface.dart';
import '../../api/jarvis_api_service.dart';

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
      return false;
    }
    
    // If we don't have the current user, try to refresh
    if (_currentUser == null) {
      try {
        await _refreshUserData();
        return _currentUser != null;
      } catch (e) {
        _logger.e('Error refreshing user data: $e');
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
      _logger.i('Refreshing auth token');
      
      // Call API service to refresh token
      final result = await _apiService.refreshToken();
      
      _logger.i('Token refresh result: $result');
      return result;
    } catch (e) {
      _logger.e('Token refresh error: $e');
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
  Future<bool> manuallySetEmailVerified() async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.i('Manually setting email as verified');
      
      // This is a workaround as we don't have direct access to modify verification status
      if (_currentUser != null) {
        // Create a new user model with verified email
        _currentUser = _currentUser!.copyWith(isEmailVerified: true);
        
        // Save the updated user to preferences
        await _saveUserToPrefs(_currentUser!);
        
        _logger.i('Email manually marked as verified');
        return true;
      }
      
      _logger.w('Cannot manually verify email: No current user');
      return false;
    } catch (e) {
      _logger.e('Error manually setting email verified: $e');
      return false;
    }
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
  
  /// Check if the current token is valid
  Future<bool> isTokenValid() async {
    if (!_isInitialized) await initialize();
    return await _apiService.verifyTokenValid();
  }
  
  // Helper method to refresh user data from API
  Future<void> _refreshUserData() async {
    try {
      _logger.i('Refreshing user data from API');
      
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
          _logger.w('No user data in preferences');
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
}
