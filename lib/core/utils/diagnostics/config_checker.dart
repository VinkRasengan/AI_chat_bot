import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import '../../../core/constants/api_constants.dart';

/// Utility class for checking and validating application configuration
class ConfigChecker {
  static final Logger _logger = Logger();
  
  /// Check if the essential API configuration is available and valid
  static Map<String, bool> checkApiConfig() {
    final results = <String, bool>{};

    // Load from env if available
    try {
      if (dotenv.isInitialized) {
        final envJarvisApiUrl = dotenv.env['JARVIS_API_URL'];
        if (envJarvisApiUrl != null && envJarvisApiUrl.isNotEmpty) {
          results['hasJarvisApiUrl'] = true;
        }

        final envJarvisApiKey = dotenv.env['JARVIS_API_KEY'];
        if (envJarvisApiKey != null && envJarvisApiKey.isNotEmpty) {
          results['hasJarvisApiKey'] = true;
        }

        final envStackProjectId = dotenv.env['STACK_PROJECT_ID'];
        if (envStackProjectId != null && envStackProjectId.isNotEmpty) {
          results['hasStackProjectId'] = true;
        }

        final envStackClientKey = dotenv.env['STACK_PUBLISHABLE_CLIENT_KEY'];
        if (envStackClientKey != null && envStackClientKey.isNotEmpty) {
          results['hasStackClientKey'] = true;
        }
      }
    } catch (e) {
      _logger.e('Error checking env configuration: $e');
    }

    // Add overall status - fixed nullable value issue
    final hasJarvisApiUrl = results['hasJarvisApiUrl'] ?? false;
    final hasJarvisApiKey = results['hasJarvisApiKey'] ?? false;
    final hasStackProjectId = results['hasStackProjectId'] ?? false;
    final hasStackPublishableClientKey = results['hasStackPublishableClientKey'] ?? false;

    results['isApiConfigValid'] = 
        hasJarvisApiUrl &&
        hasJarvisApiKey &&
        hasStackProjectId &&
        hasStackPublishableClientKey;

    final isApiConfigValid = results['isApiConfigValid'] ?? false;
    _logger.i('API configuration check: ${isApiConfigValid ? 'Valid' : 'Invalid'}');

    return results;
  }

  
  /// Check if the Jarvis API configuration is valid
  static Future<bool> checkJarvisApiConfig() async {
    try {
      final config = checkApiConfig();
      final isApiConfigValid = config['isApiConfigValid'] ?? false;
      _logger.i('Jarvis API config check result: $isApiConfigValid');
      return isApiConfigValid;
    } catch (e) {
      _logger.e('Error checking Jarvis API config: $e');
      return false;
    }
  }
  
  /// Check if .env file is properly loaded
  static bool isEnvFileLoaded() {
    try {
      final isLoaded = dotenv.isInitialized;
      
      if (!isLoaded) {
        _logger.e('.env file is not loaded properly');
      } else {
        final varsCount = dotenv.env.length;
        _logger.i('.env file loaded successfully with $varsCount variables');
      }
      
      return isLoaded;
    } catch (e) {
      _logger.e('Error checking .env file: $e');
      return false;
    }
  }
  
  /// Get a guide for fixing API configuration issues
  static String getApiConfigGuide() {
    return '''
To fix API configuration issues:

1. Create a .env file at the project root (copy from .env.example)
2. Add your Jarvis API credentials:
   JARVIS_API_URL=https://api.jarvis.cx
   JARVIS_API_KEY=your_jarvis_api_key_here
   
3. Add your Stack authentication credentials:
   STACK_PROJECT_ID=your_stack_project_id
   STACK_PUBLISHABLE_CLIENT_KEY=your_stack_client_key
   
4. Restart the application to apply the changes

Alternatively, you can use the hardcoded values in ApiConstants class for development purposes.
''';
  }
  
  /// Get a diagnostic report of the application configuration
  static Map<String, dynamic> getDiagnosticReport() {
    final report = <String, dynamic>{};
    
    // API config
    final apiConfig = checkApiConfig();
    report['apiConfigStatus'] = apiConfig['isApiConfigValid'] == true ? 'Valid' : 'Invalid';
    report['apiConfigDetails'] = apiConfig;
    
    // .env file
    report['envFileLoaded'] = isEnvFileLoaded();
    
    // Add API constants info (mask sensitive data)
    report['jarvisApiUrl'] = ApiConstants.authApiUrl;
    report['stackProjectId'] = ApiConstants.stackProjectId.isNotEmpty 
        ? '${ApiConstants.stackProjectId.substring(0, 8)}...'
        : 'Not set';
    report['stackClientKeySet'] = ApiConstants.stackPublishableClientKey.isNotEmpty;
    
    return report;
  }
  
  /// Log the diagnostic report to the console
  static void logDiagnosticReport() {
    final report = getDiagnosticReport();
    _logger.i('Diagnostic Report:');
    report.forEach((key, value) {
      if (value is Map) {
        _logger.i('  $key:');
        value.forEach((k, v) {
          _logger.i('    $k: $v');
        });
      } else {
        _logger.i('  $key: $value');
      }
    });
  }
}

/// Run this script directly with: dart lib/core/utils/diagnostics/config_checker.dart
void main() async {
  final configValid = await ConfigChecker.checkJarvisApiConfig();
  
  // Exit with appropriate status code
  if (!configValid) {
    exit(1);
  }
}
