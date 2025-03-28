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
  
  // Gemini API configuration
  static const String geminiApiKey = 'AIzaSyClkVxfV1SMF7iORASUZGVPa2HoIIa5KEk';
  static const String geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta';
  
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
  static const String userProfile = '/api/v1/user/profiles';
  static const String userChangePassword = '/api/v1/user/change-passwords';
  
  // AI chat endpoints
  static const String conversations = '/api/v1/ai-chats/conversations';          // Updated to "ai-chats" from "ai-chat"
  static const String messages = '/api/v1/ai-chats/messages';                    // Updated to "ai-chats" from "ai-chat"
  
  // Other API endpoints
  static const String status = '/api/v1/status';
  static const String models = '/api/v1/models';
  
  // Gemini API endpoints
  static const String geminiGenerateContent = '/models/gemini-2.0-flash:generateContent';
  static const String geminiStreamContent = '/models/gemini-2.0-flash:streamGenerateContent';
  
  // Model constants
  static const String defaultModel = 'gemini-1.5-flash-latest';
  static const Map<String, String> modelNames = {
    'gemini-1.5-flash-latest': 'Gemini 1.5 Flash',
    'gemini-1.5-pro-latest': 'Gemini 1.5 Pro',
    'claude-3-5-sonnet-20240620': 'Claude 3.5 Sonnet',
    'gpt-4o': 'GPT-4o',
    'gpt-4o-mini': 'GPT-4o Mini',
  };
  
  // Storage keys
  static const String accessTokenKey = 'jarvis_access_token';
  static const String refreshTokenKey = 'jarvis_refresh_token';
  static const String userIdKey = 'jarvis_user_id';

  // Required OAuth scopes for Jarvis API - updated with proper scope names
  static const List<String> requiredScopes = [
    'ai-chats:read',       // Updated from ai-chat:read
    'ai-chats:write',      // Updated from ai-chat:write
    'users:read',          // Updated from user:read
    'users:write',         // Updated from user:write
    'ai-models:read',      // Updated from ai-model:read
    'conversations:read',  // Updated from conversation:read
    'conversations:write'  // Updated from conversation:write
  ];
  
  // Stack Auth configuration - kept for reference but not used in current implementation
  static const bool useStackAuthFormatting = false; // Set to false to disable Stack Auth formatting
  static const String stackOAuthScopesParam = 'scopes';
  static const String oauthResponseType = 'code';
  static const bool stackUseServerFunctions = false; // Use client-side functions only

  // Note: Server-side keys like stackSecretServerKey should NEVER be included in client-side code
  // Server-only operations should be handled through secure backend services
}
