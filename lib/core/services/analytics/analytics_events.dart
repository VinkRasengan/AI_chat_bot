import 'package:logger/logger.dart';

/// Analytics events constants and utility methods
class AnalyticsEvents {
  // Singleton instance
  static final AnalyticsEvents _instance = AnalyticsEvents._internal();
  factory AnalyticsEvents() => _instance;
  AnalyticsEvents._internal();
  
  final Logger _logger = Logger();

  // User engagement events
  static const String EVENT_CHAT_STARTED = 'chat_started';
  static const String EVENT_MESSAGE_SENT = 'message_sent';
  static const String EVENT_AI_MODEL_SWITCHED = 'ai_model_switched';
  static const String EVENT_PROMPT_USED = 'prompt_used';
  static const String EVENT_ERROR_OCCURRED = 'error_occurred';
  static const String EVENT_CONVERSATION_CLEARED = 'conversation_cleared';
  
  // Subscription events
  static const String EVENT_SUBSCRIPTION_VIEW = 'subscription_view';
  static const String EVENT_SUBSCRIPTION_ATTEMPT = 'subscription_attempt';
  static const String EVENT_SUBSCRIPTION_SUCCESS = 'subscription_success';
  static const String EVENT_SUBSCRIPTION_ERROR = 'subscription_error';
  static const String EVENT_TOKEN_LOW = 'token_low_warning';
  
  // Feature usage events
  static const String EVENT_FEATURE_USED = 'feature_used';
  static const String EVENT_SHARE_CONVERSATION = 'share_conversation';
  static const String EVENT_EXPORT_CONVERSATION = 'export_conversation';
  
  // User property keys
  static const String USER_PROPERTY_SUBSCRIPTION = 'subscription_level';
  static const String USER_PROPERTY_MODEL_PREFERENCE = 'preferred_model';
  static const String USER_PROPERTY_THEME = 'theme_preference';
  static const String USER_PROPERTY_IS_POWER_USER = 'is_power_user';
}
