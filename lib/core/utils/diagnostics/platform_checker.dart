import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';

/// Utility class for checking platform information
class PlatformChecker {
  static final Logger _logger = Logger();

  /// Returns true if the app is running on a mobile platform (Android or iOS)
  static bool get isMobile {
    try {
      return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    } catch (e) {
      _logger.e('Error checking platform: $e');
      return false;
    }
  }

  /// Returns true if the app is running on a desktop platform (Windows, macOS, or Linux)
  static bool get isDesktop {
    try {
      return !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    } catch (e) {
      _logger.e('Error checking platform: $e');
      return false;
    }
  }

  /// Returns true if the app is running on a web platform
  static bool get isWeb {
    return kIsWeb;
  }

  /// Returns a map containing platform information
  static Map<String, dynamic> getPlatformInfo() {
    try {
      if (kIsWeb) {
        return {
          'platform': 'web',
          'isWeb': true,
          'isMobile': false,
          'isDesktop': false,
        };
      } else {
        return {
          'platform': Platform.operatingSystem,
          'platformVersion': Platform.operatingSystemVersion,
          'isWeb': false,
          'isMobile': Platform.isAndroid || Platform.isIOS,
          'isDesktop': Platform.isWindows || Platform.isMacOS || Platform.isLinux,
          'isAndroid': Platform.isAndroid,
          'isIOS': Platform.isIOS,
          'isWindows': Platform.isWindows,
          'isMacOS': Platform.isMacOS,
          'isLinux': Platform.isLinux,
          'localHostname': Platform.localHostname,
          'numberOfProcessors': Platform.numberOfProcessors,
        };
      }
    } catch (e) {
      _logger.e('Error getting platform info: $e');
      return {
        'error': e.toString(),
        'isWeb': kIsWeb,
      };
    }
  }

  /// Logs platform information to the console
  static void logPlatformInfo() {
    final info = getPlatformInfo();
    _logger.i('Platform information:');
    info.forEach((key, value) {
      _logger.i('  $key: $value');
    });
  }
}

/// Run this script directly with: dart lib/core/utils/diagnostics/platform_checker.dart
void main() {
  PlatformChecker.logPlatformInfo();
}
