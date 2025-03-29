/// Custom exceptions for API-related errors
/// 
/// These exceptions provide more structured error handling for specific API error cases

/// Exception thrown when user has insufficient tokens/usage quota
class InsufficientTokensException implements Exception {
  final String message;
  
  InsufficientTokensException(this.message);
  
  @override
  String toString() => 'InsufficientTokensException: $message';
}

/// Exception thrown when authentication fails
class AuthenticationException implements Exception {
  final String message;
  final int? statusCode;
  
  AuthenticationException(this.message, {this.statusCode});
  
  @override
  String toString() => 'AuthenticationException: $message${statusCode != null ? ' (Status code: $statusCode)' : ''}';
}

/// Exception thrown for API rate limiting
class RateLimitException implements Exception {
  final String message;
  final int? retryAfterSeconds;
  
  RateLimitException(this.message, {this.retryAfterSeconds});
  
  @override
  String toString() => 'RateLimitException: $message${retryAfterSeconds != null ? ' (Retry after: $retryAfterSeconds seconds)' : ''}';
}

/// Exception thrown for invalid input
class InvalidInputException implements Exception {
  final String message;
  final String? field;
  
  InvalidInputException(this.message, {this.field});
  
  @override
  String toString() => 'InvalidInputException: $message${field != null ? ' (Field: $field)' : ''}';
}

/// Exception thrown for general API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;
  
  ApiException(this.message, {this.statusCode, this.details});
  
  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (Status code: $statusCode)' : ''}';
}
