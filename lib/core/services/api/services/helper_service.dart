import 'dart:convert';
import 'package:logger/logger.dart';

/// Utility service for common helper functions
class HelperService {
  static final Logger _logger = Logger();
  
  /// Mask sensitive data in strings (like API keys or tokens)
  static String maskString(String value) {
    if (value.length <= 8) return '****';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }
  
  /// Generate a request ID for tracking
  static String generateRequestId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = now % 10000;
    return 'req_$now$random';
  }
  
  /// Extract and decrypt JWT token payload for inspection
  static Map<String, dynamic>? decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        _logger.w('Invalid JWT format');
        return null;
      }
      
      String payload = parts[1];
      payload = base64.normalize(payload);
      
      final decoded = utf8.decode(base64.decode(payload));
      return jsonDecode(decoded);
    } catch (e) {
      _logger.e('Error decoding JWT: $e');
      return null;
    }
  }
  
  /// Convert snake_case to camelCase for API data
  static Map<String, dynamic> snakeToCamelCase(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    data.forEach((key, value) {
      final camelKey = key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase()
      );
      
      // Recursively convert nested maps
      if (value is Map<String, dynamic>) {
        result[camelKey] = snakeToCamelCase(value);
      } else if (value is List) {
        // Handle lists of maps
        result[camelKey] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return snakeToCamelCase(item);
          }
          return item;
        }).toList();
      } else {
        result[camelKey] = value;
      }
    });
    
    return result;
  }
  
  /// Convert camelCase to snake_case for API requests
  static Map<String, dynamic> camelToSnakeCase(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    data.forEach((key, value) {
      final snakeKey = key.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}'
      );
      
      // Recursively convert nested maps
      if (value is Map<String, dynamic>) {
        result[snakeKey] = camelToSnakeCase(value);
      } else if (value is List) {
        // Handle lists of maps
        result[snakeKey] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return camelToSnakeCase(item);
          }
          return item;
        }).toList();
      } else {
        result[snakeKey] = value;
      }
    });
    
    return result;
  }
  
  /// Parse ISO-8601 timestamp strings safely
  static DateTime? parseIsoDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return null;
    }
    
    try {
      return DateTime.parse(dateTimeString);
    } catch (e) {
      _logger.e('Error parsing date time: $e');
      return null;
    }
  }
}
