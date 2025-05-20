import 'analytics_service.dart';

/// A global utility class for easier access to analytics functions throughout the app
class GlobalAnalytics {
  static final GlobalAnalytics _instance = GlobalAnalytics._internal();

  factory GlobalAnalytics() => _instance;

  final AnalyticsService _analyticsService = AnalyticsService();
  
  GlobalAnalytics._internal();

  /// Initialize the analytics service and check user preferences
  Future<void> initialize() async {
    try {
      // Initialize the AnalyticsService (empty implementation)
      await _analyticsService.initialize();
    } catch (e) {
      // Silent error handling - analytics are disabled
    }
  }

  /// Get the current analytics service instance
  AnalyticsService get service => _analyticsService;
}
