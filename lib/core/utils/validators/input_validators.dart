/// Utility class for validating different types of user inputs
class InputValidators {
  /// Validate name input (not empty, reasonable length)
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập tên của bạn';
    }
    
    if (value.trim().length < 2) {
      return 'Tên quá ngắn';
    }
    
    if (value.trim().length > 50) {
      return 'Tên quá dài';
    }
    
    return null;
  }
  
  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập email của bạn';
    }
    
    // Use RegExp to validate email format
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Email không hợp lệ';
    }
    
    return null;
  }
  
  /// Validate phone number format (Vietnamese phone numbers)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    
    // Vietnamese phone number regex
    // Accepts formats like: 0912345678, 84912345678, +84912345678
    final phoneRegex = RegExp(
      r'^(0|\+84|84)([3|5|7|8|9])([0-9]{8})$',
    );
    
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Số điện thoại không hợp lệ';
    }
    
    return null;
  }
  
  /// Validate that input is not empty
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    
    return null;
  }
  
  /// Validate min length of input
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    
    if (value.trim().length < minLength) {
      return '$fieldName phải có ít nhất $minLength ký tự';
    }
    
    return null;
  }
  
  /// Validate max length of input
  static String? validateMaxLength(String? value, int maxLength, String fieldName) {
    if (value == null) {
      return null;
    }
    
    if (value.trim().length > maxLength) {
      return '$fieldName không được vượt quá $maxLength ký tự';
    }
    
    return null;
  }
  
  /// Validate that input is a number
  static String? validateNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    
    if (double.tryParse(value.trim()) == null) {
      return '$fieldName phải là số';
    }
    
    return null;
  }
  
  /// Validate that input is a positive number
  static String? validatePositiveNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    
    final number = double.tryParse(value.trim());
    
    if (number == null) {
      return '$fieldName phải là số';
    }
    
    if (number <= 0) {
      return '$fieldName phải là số dương';
    }
    
    return null;
  }

  /// Validate email format (boolean)
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }

  /// Validate password length
  static bool isValidPassword(String password) {
    return password.length >= 8;
  }
}
