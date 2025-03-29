/// Constants for API configuration
/// 
/// These constants are used for API authentication and configuration
class ApiConstants {
  // Stack Auth API configuration
  static const String stackProjectId = 'a914f06b-5e46-4966-8693-80e4b9f4f409';
  static const String stackPublishableClientKey = 'pck_tqsy29b64a585km2g4wnpc57ypjprzzdch8xzpq0xhayr';
  
  // API URLs - Update to use dev environment URLs
  static const String authApiUrl = 'https://auth-api.dev.jarvis.cx';  // Updated to dev auth API URL
  static const String jarvisApiUrl = 'https://api.dev.jarvis.cx';     // Updated to dev Jarvis API URL
  static const String knowledgeApiUrl = 'https://knowledge-api.dev.jarvis.cx';  // Already using dev knowledge API URL
  
  // Verification callback URL
  static const String verificationCallbackUrl = 'https://auth.dev.jarvis.cx/handler/email-verification?after_auth_return_to=%2Fauth%2Fsignin%3Fclient_id%3Djarvis_chat%26redirect%3Dhttps%253A%252F%252Fchat.dev.jarvis.cx%252Fauth%252Foauth%252Fsuccess';
  
  // Default API key for development environments
  static const String defaultApiKey = 'test_jarvis_api_key_for_development_only';
  
  // API endpoints - Keep as simple as possible to avoid path duplication
  static const String authPasswordSignUp = '/api/v1/auth/password/sign-up';
  static const String authPasswordSignIn = '/api/v1/auth/password/sign-in';
  static const String authSessionRefresh = '/api/v1/auth/sessions/current/refresh';
  static const String authSessionCurrent = '/api/v1/auth/sessions/current';
  static const String authEmailVerificationStatus = '/api/v1/auth/emails/verification/status';
  
  // User profile endpoints - updated to match actual API documentation
  static const String userProfile = '/api/v1/auth/me';
  static const String userChangePassword = '/api/v1/user/change-password';
  static const String userUsage = '/api/v1/tokens/usage';
  
  // AI chat endpoints - ensure paths are correct for the API version
  static const String conversations = '/api/v1/ai-chat/conversations';
  static const String messages = '/api/v1/ai-chat/messages';
  
  // Make sure the conversation messages endpoint uses the correct format
  static String conversationMessages(String conversationId) {
    final trimmedConversationId = conversationId.trim();
    return '/api/v1/ai-chat/conversations/$trimmedConversationId/messages';
  }
  
  // API status endpoint for token validation - fixed to use a simple endpoint
  static const String apiStatus = '/api/v1/status';  // General API status check
  static const String models = '/api/v1/models';
  
  // Model constants
  static const String defaultModel = 'gpt-4o-mini'; // Updated default to GPT-4o Mini for better balance of speed/quality
  static const Map<String, String> modelNames = {
    'claude-3-5-sonnet-20240620': 'Claude 3.5 Sonnet',
    'gpt-4o': 'GPT-4o',
    'gpt-4o-mini': 'GPT-4o Mini',
    'gemini-1.5-flash-latest': 'Gemini 1.5 Flash',
    'gemini-1.5-pro-latest': 'Gemini 1.5 Pro',
    'claude-3-haiku-20240307': 'Claude 3 Haiku',
  };
  
  // Model capabilities lookup - track which models support conversation history
  static const Map<String, bool> modelSupportsConversationHistory = {
    'claude-3-5-sonnet-20240620': true,
    'gpt-4o': true,
    'gpt-4o-mini': true,
    'gemini-1.5-flash-latest': true,
    'gemini-1.5-pro-latest': true, 
    'claude-3-haiku-20240307': true,
    // All models should require server conversation support
  };

  // Storage keys
  static const String accessTokenKey = 'jarvis_access_token';
  static const String refreshTokenKey = 'jarvis_refresh_token';
  static const String userIdKey = 'jarvis_user_id';

  // Required OAuth scopes for Jarvis API - Updated to match actual API requirements
  static const List<String> requiredScopes = [
    'ai-chat:read',        // Correct scope names for the API
    'ai-chat:write',       // These match the actual API requirements
    'users:read',          
    'users:write',
    'ai-models:read',
    'conversations:read',
    'conversations:write'
  ];
  
  // Stack Auth configuration - kept for reference but not used in current implementation
  static const String stackOAuthScopesParam = 'scopes';
  static const String oauthResponseType = 'code';

  // Note: Server-side keys like stackSecretServerKey should NEVER be included in client-side code
  // Server-only operations should be handled through secure backend services

  // Google Auth related constants
  static const String googleAuthEndpoint = '/api/v1/auth/google/authorize';
  static const String googleCallbackEndpoint = '/api/v1/auth/google/callback';
  static const String googleRedirectUri = 'https://chat.dev.jarvis.cx/auth/google/callback';
}
