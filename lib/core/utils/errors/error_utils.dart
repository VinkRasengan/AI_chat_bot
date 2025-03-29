import 'dart:io';
import 'dart:async' show TimeoutException; // Update import for clarity
import 'package:logger/logger.dart';

class ErrorInfo {
  final String message;
  final String? field; // The field associated with the error (email, password, etc.)
  final String? code; // Error code for programmatic handling
  final int? severity; // 1-5 where 5 is most severe

  ErrorInfo({
    required this.message, 
    this.field,
    this.code,
    this.severity = 3
  });
}

/// Utility class for handling and formatting errors
class ErrorUtils {
  static final Logger _logger = Logger();
  
  /// Get user-friendly message for common chat errors
  static String getChatErrorMessage(dynamic error) {
    if (error.toString().contains('rate_limit') || 
        error.toString().contains('too_many_requests')) {
      return 'Bạn đã gửi quá nhiều tin nhắn trong thời gian ngắn. Vui lòng đợi một lát và thử lại.';
    }
    
    if (error.toString().contains('content_filter') || 
        error.toString().contains('content_moderation')) {
      return 'Tin nhắn của bạn không thể được xử lý do vi phạm quy định nội dung.';
    }
    
    if (error.toString().contains('token_limit') || 
        error.toString().contains('context_length')) {
      return 'Cuộc trò chuyện này quá dài. Vui lòng bắt đầu cuộc trò chuyện mới.';
    }
    
    return 'Không thể xử lý tin nhắn của bạn. Vui lòng thử lại sau.';
  }
  
  /// Check if error is a network connectivity error
  static bool isNetworkError(dynamic error) {
    return error is SocketException || 
           error.toString().contains('network') ||
           error.toString().contains('connect') ||
           error.toString().contains('connection');
  }
  
  /// Check if error is an authentication error
  static bool isAuthError(dynamic error) {
    return error.toString().contains('unauthorized') || 
           error.toString().contains('unauthenticated') ||
           error.toString().contains('invalid_token') ||
           error.toString().contains('auth') && error.toString().contains('invalid') ||
           error.toString().contains('permission_denied') ||
           error.toString().contains('403') ||
           error.toString().contains('401');
  }

  /// Gets user-friendly error information from authentication errors
  static ErrorInfo getAuthErrorInfo(String error) {
    _logger.d('Processing auth error: $error');
    
    // Error for wrong credentials
    if (error.contains('user-not-found') || 
        error.contains('Tài khoản không tồn tại')) {
      return ErrorInfo(
        message: 'Không tìm thấy tài khoản với email này',
        field: 'email',
        code: 'user-not-found',
      );
    } 
    
    if (error.contains('wrong-password') || 
        error.contains('Mật khẩu không đúng') ||
        error.contains('Tài khoản hoặc mật khẩu không đúng')) {
      return ErrorInfo(
        message: 'Mật khẩu không chính xác',
        field: 'password',
        code: 'wrong-password',
      );
    }
    
    // Rate limiting
    if (error.contains('too-many-requests')) {
      return ErrorInfo(
        message: 'Quá nhiều yêu cầu. Vui lòng thử lại sau vài phút',
        code: 'too-many-requests',
        severity: 4,
      );
    }
    
    // Network errors
    if (error.contains('network-request-failed')) {
      return ErrorInfo(
        message: 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối internet của bạn',
        code: 'network-error',
        severity: 3,
      );
    }
    
    // Invalid format errors
    if (error.contains('invalid-email')) {
      return ErrorInfo(
        message: 'Định dạng email không hợp lệ',
        field: 'email',
        code: 'invalid-email',
      );
    }
    
    // Account disabled
    if (error.contains('user-disabled')) {
      return ErrorInfo(
        message: 'Tài khoản này đã bị vô hiệu hóa',
        code: 'user-disabled',
        severity: 4,
      );
    }
    
    // Email verification error
    if (error.contains('email-not-verified')) {
      return ErrorInfo(
        message: 'Email chưa được xác minh. Vui lòng kiểm tra hộp thư của bạn',
        code: 'email-not-verified',
      );
    }
    
    // Registration errors
    if (error.contains('email-already-in-use') || 
        error.contains('Email already exists')) {
      return ErrorInfo(
        message: 'Email này đã được đăng ký',
        field: 'email',
        code: 'email-already-exists',
      );
    }
    
    if (error.contains('weak-password')) {
      return ErrorInfo(
        message: 'Mật khẩu quá yếu, vui lòng chọn mật khẩu mạnh hơn',
        field: 'password',
        code: 'weak-password',
      );
    }
    
    // Password reset errors
    if (error.contains('expired-action-code')) {
      return ErrorInfo(
        message: 'Liên kết đặt lại mật khẩu đã hết hạn',
        code: 'expired-link',
        severity: 3,
      );
    }
    
    // Default for unhandled errors
    return ErrorInfo(
      message: 'Đã xảy ra lỗi: ${_getSanitizedErrorMessage(error)}',
      code: 'unknown-error',
    );
  }
  
  /// Format API errors into user-friendly messages
  static String formatApiError(dynamic error) {
    _logger.e('API Error: $error');
    
    // Handle network errors
    if (error is SocketException) {
      return 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối internet của bạn và thử lại.';
    }
    
    // Handle timeout errors
    if (error is TimeoutException) {
      return 'Yêu cầu đã hết thời gian chờ. Vui lòng thử lại sau.';
    }
    
    // Handle authentication errors
    if (error.toString().contains('unauthorized') || 
        error.toString().contains('invalid_token') ||
        error.toString().contains('401')) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    
    // Handle common API errors
    if (error.toString().contains('invalid_credentials') || 
        error.toString().contains('wrong password') ||
        error.toString().contains('user not found')) {
      return 'Tên đăng nhập hoặc mật khẩu không đúng.';
    }
    
    if (error.toString().contains('email-already-in-use')) {
      return 'Email này đã được sử dụng bởi một tài khoản khác.';
    }
    
    // Default error message
    return 'Đã xảy ra lỗi: ${error.toString()}';
  }
  
  // Clean up error message to avoid showing too much technical detail to users
  static String _getSanitizedErrorMessage(String error) {
    // For security, don't show full error details to users
    if (error.length > 100) {
      return 'Lỗi không xác định. Vui lòng thử lại sau.';
    }
    
    // Remove any sensitive data
    error = error.replaceAll(RegExp(r'API key: [a-zA-Z0-9_-]+'), '[API KEY]');
    error = error.replaceAll(RegExp(r'token: [a-zA-Z0-9_-]+'), '[TOKEN]');
    
    // Remove Firebase prefixes
    error = error.replaceAll('FirebaseError: ', '');
    error = error.replaceAll('FirebaseAuthException: ', '');
    
    return error;
  }
}