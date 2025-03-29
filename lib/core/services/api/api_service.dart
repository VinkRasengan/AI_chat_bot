import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Base API service interface
abstract class ApiService {
  final Logger _logger = Logger();
  
  /// Make a GET request with error handling
  Future<Map<String, dynamic>> get(String endpoint, {bool requiresAuth = true}) async {
    try {
      final response = await http.get(
        Uri.parse(endpoint),
        headers: requiresAuth ? getAuthHeaders() : getHeaders(),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        _logger.e('API GET error: [${response.statusCode}] ${response.reasonPhrase}');
        throw 'API error: ${response.statusCode} ${response.reasonPhrase}';
      }
    } catch (e) {
      _logger.e('API GET exception: $e');
      rethrow;
    }
  }
  
  /// Make a POST request with error handling
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data, {bool requiresAuth = true}) async {
    try {
      final headers = requiresAuth ? getAuthHeaders() : getHeaders();
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(data),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        _logger.e('API POST error: [${response.statusCode}] ${response.reasonPhrase}');
        throw 'API error: ${response.statusCode} ${response.reasonPhrase}';
      }
    } catch (e) {
      _logger.e('API POST exception: $e');
      rethrow;
    }
  }
  
  /// Check API availability
  Future<bool> checkApiStatus();
  
  /// Get API configuration info
  Map<String, String> getApiConfig();
  
  /// Get user profile (for common services)
  Future<Map<String, dynamic>?> getUserProfile();
  
  /// Get auth headers for API requests
  Map<String, String> getAuthHeaders() {
    // Default implementation - should be overridden
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
  
  /// Get regular headers for API requests
  Map<String, String> getHeaders() {
    // Default implementation - should be overridden
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
}