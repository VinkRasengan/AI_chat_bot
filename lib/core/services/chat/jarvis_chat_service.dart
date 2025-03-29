import 'dart:math' as Math;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/chat/chat_session.dart';
import '../../models/chat/message.dart';
import '../api/jarvis_api_service.dart';
import '../api/gemini_api_service.dart';
import '../../constants/api_constants.dart';

/// Service for chat-related operations using the Jarvis API
class JarvisChatService {
  static final JarvisChatService _instance = JarvisChatService._internal();
  factory JarvisChatService() => _instance;
  
  final Logger _logger = Logger();
  final JarvisApiService _apiService = JarvisApiService();
  final GeminiApiService _geminiApiService = GeminiApiService();
  bool _hasApiError = false;
  bool _useDirectGeminiApi = false;
  String? _selectedModel;

  // Circuit breaker to prevent infinite recursion in API calls
  int _apiRecursionCount = 0;
  static const int _maxApiRecursion = 2;
  DateTime? _lastApiFailure;
  
  JarvisChatService._internal();
  
  /// Get a list of the user's chat sessions
  Future<List<ChatSession>> getUserChatSessions() async {
    try {
      _logger.i('Getting user chat sessions');
      
      // First check if the API service is authenticated
      final isAuthenticated = _apiService.isAuthenticated();
      if (!isAuthenticated) {
        _logger.w('User is not authenticated, attempting token refresh');
        final refreshed = await _apiService.refreshToken();
        if (!refreshed) {
          // Switch to Gemini API fallback mode after failed refresh
          _useDirectGeminiApi = true;
          _logger.i('Authentication failed, switched to Gemini API fallback mode.');
          return [];
        }
        
        // Successfully refreshed token, reset fallback mode
        _useDirectGeminiApi = false;
        _logger.i('Token refresh successful, using API mode');
      }
      
      // Check if we had a previous API error
      if (_hasApiError) {
        _logger.w('Previous API error detected, attempting to refresh token');
        final refreshed = await _apiService.refreshToken();
        if (!refreshed) {
          // Switch to Gemini API fallback mode
          _useDirectGeminiApi = true;
          _logger.i('Token refresh failed, switched to Gemini API fallback mode.');
          return [];
        }
        _hasApiError = false;
      }
      
      // If we're already using direct Gemini API, return empty list
      if (_useDirectGeminiApi) {
        _logger.i('Using Gemini API directly, returning empty sessions list');
        return [];
      }
      
      // Check if selected model supports conversation history
      final model = await getSelectedModel();
      final supportsHistory = ApiConstants.modelSupportsConversationHistory[model] ?? false;
      
      if (!supportsHistory) {
        _logger.i('Selected model (${model}) does not support conversation history, creating local session');
        return [await _createLocalChatSession('New Chat')];
      }
      
      // Get conversations from API
      try {
        final sessions = await _apiService.getConversations();
        _logger.i('Retrieved ${sessions.length} chat sessions');
        
        // If we get an empty list but expecting sessions, check if it's because the model
        // doesn't support conversation history
        if (sessions.isEmpty) {
          // Create a single local session for better UX
          _logger.i('No sessions found, creating local chat session');
          
          return [
            await _createLocalChatSession('New Chat')
          ];
        }
        
        return sessions;
      } catch (e) {
        // Special handling for known error types
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('does not support conversation history') || 
            errorStr.contains('400 bad request')) {
          // This is an expected case for some models - create a local session instead
          _logger.i('Using a model that does not support conversation history. Creating local chat sessions.');
          
          // Return a single local session
          return [
            await _createLocalChatSession('New Chat'),
          ];
        } else if (errorStr.contains('unauthorized') || errorStr.contains('authentication failed')) {
          // Auth issues, switch to Gemini fallback
          _useDirectGeminiApi = true;
          _logger.i('API authentication issues, switched to Gemini API fallback mode.');
          return [];
        }
        throw e;
      }
    } catch (e) {
      _logger.e('Error getting chat sessions: $e');
      
      // Mark as having API error for future requests
      _hasApiError = true;
      
      // Check for specific "conversation history not supported" error pattern - expanded to catch more variants
      if (e.toString().toLowerCase().contains('does not support conversation history') ||
          e.toString().toLowerCase().contains('conversation history not supported') ||
          e.toString().toLowerCase().contains('400 bad request')) {
        _logger.i('Model does not support conversation history, creating local session');
        return [await _createLocalChatSession('New Chat')];
      }
      
      // Check if we should switch to direct API
      if (!_useDirectGeminiApi && 
          (e.toString().contains('Unauthorized') || 
           e.toString().contains('Authentication failed'))) {
        _useDirectGeminiApi = true;
        _logger.i('Switching to direct Gemini API due to auth errors');
        return [];
      }
      
      // Return an empty list rather than throwing for better UX
      return [];
    }
  }

  // Enhance local chat session to indicate it's due to model limitations
  Future<ChatSession> _createLocalChatSession(String title) async {
    // Get current model for reference
    final model = await getSelectedModel();
    return ChatSession(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title.isEmpty ? 'New Chat' : title,
      createdAt: DateTime.now(),
      metadata: {
        'localOnly': true, 
        'noHistorySupport': !(ApiConstants.modelSupportsConversationHistory[model] ?? false), // Fixed nullable expression
        'model': model
      },
    );
  }

  /// Get messages for a specific chat session with improved error handling
  Future<List<Message>> getMessages(String sessionId) async {
    try {
      // Prevent infinite recursion with circuit breaker
      _apiRecursionCount++;
      if (_apiRecursionCount > _maxApiRecursion) {
        _logger.w('Max API recursion reached ($_maxApiRecursion), breaking to prevent infinite loop');
        _apiRecursionCount = 0;
        return [];
      }
      
      _logger.i('Getting messages for chat session: $sessionId (attempt $_apiRecursionCount)');
      
      // Check for local session ID (used in fallback mode)
      if (sessionId.startsWith('local_')) {
        _logger.i('Local session ID detected, returning empty messages (fallback mode)');
        _apiRecursionCount = 0;
        
        // Load saved local messages if available
        return await _loadLocalMessages(sessionId);
      }
      
      // First check if the API service is authenticated
      final isAuthenticated = _apiService.isAuthenticated();
      if (!isAuthenticated) {
        _logger.w('User is not authenticated, attempting token refresh');
        final refreshed = await _apiService.refreshToken();
        if (!refreshed) {
          // If using direct Gemini API, return empty messages list
          if (_useDirectGeminiApi) {
            _logger.i('Using Gemini API directly, returning empty messages list');
            _apiRecursionCount = 0;
            return [];
          }
          throw 'Authentication failed. Please login again.';
        }
      }
      
      // Check if we had a previous API error
      if (_hasApiError) {
        _logger.w('Previous API error detected, attempting to refresh token');
        final refreshed = await _apiService.refreshToken();
        if (!refreshed) {
          // If token refresh fails and we're not using Gemini, try switching to it
          if (!_useDirectGeminiApi) {
            _logger.i('Token refresh failed, switching to direct Gemini API');
            _useDirectGeminiApi = true;
            _apiRecursionCount = 0;
            return [];
          }
          throw 'Unable to refresh token after previous API error';
        }
        _hasApiError = false;
      }
      
      // If we're using direct Gemini API, return empty messages list
      if (_useDirectGeminiApi) {
        _logger.i('Using Gemini API directly, returning empty messages list');
        _apiRecursionCount = 0;
        return [];
      }
      
      // Get conversation history from API
      try {
        final messages = await _apiService.getConversationHistory(sessionId);
        _logger.i('Retrieved ${messages.length} messages');
        _apiRecursionCount = 0;
        return messages;
      } catch (e) {
        // Check for scope-related errors
        if (e.toString().toLowerCase().contains('scope') || 
            e.toString().toLowerCase().contains('permission')) {
          _logger.e('Auth scope issue detected: $e');
          _lastApiFailure = DateTime.now();
          
          // Display diagnostics
          _logger.i('API configuration diagnostics:');
          final config = _apiService.getApiConfig();
          config.forEach((key, value) => _logger.i('- $key: $value'));
          
          // Switch to fallback mode on scope issues
          _useDirectGeminiApi = true;
          _logger.i('Switching to direct Gemini API due to scope issues');
          _apiRecursionCount = 0;
          return [];
        }
        
        // Re-throw the error for other handling
        throw e;
      }
    } catch (e) {
      _apiRecursionCount = 0; // Reset counter on error
      _logger.e('Error getting messages: $e');
      
      // If it's an auth error and we're not using Gemini, switch to it
      if (e.toString().contains('Unauthorized') || 
          e.toString().contains('Authentication failed') ||
          e.toString().contains('401') ||
          e.toString().contains('403')) {
        if (!_useDirectGeminiApi) {
          _logger.i('Authorization error, switching to direct Gemini API');
          _useDirectGeminiApi = true;
          return [];
        }
      }
      
      // Mark as having API error for future requests
      _hasApiError = true;
      
      return []; // Return empty list instead of throwing to improve UX
    }
  }
  
  /// Send a message in a chat session with improved API error handling
  Future<Message> sendMessage(String sessionId, String text) async {
    try {
      _logger.i('Sending message to session: $sessionId');
      
      // Track if this is a local session for better debugging
      final isLocalSession = sessionId.startsWith('local_');
      _logger.i('Is local session: $isLocalSession, Using direct Gemini: $_useDirectGeminiApi');
      
      // Handle local sessions more gracefully
      if (_useDirectGeminiApi || isLocalSession) {
        _logger.i('Using direct Gemini API for message');
        
        // Create and save the message
        final userMessage = Message(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        );
        
        // Save the message to local storage if it's a local session
        if (isLocalSession) {
          await _saveLocalMessage(sessionId, userMessage);
          _logger.i('Saved message to local storage for session: $sessionId');
        } else {
          _logger.w('Not saving message to server due to direct Gemini API mode');
        }
        
        // Update chat title if this is the first message
        await _updateChatTitleIfFirstMessage(sessionId, text);
        return userMessage;
      }  
      
      // Check if we had a previous API error
      if (_hasApiError) {
        _logger.w('Previous API error detected, attempting to refresh token');
        final refreshed = await _apiService.refreshToken();
        if (!refreshed) {
          // If refresh token fails, switch to direct Gemini API
          _logger.i('Token refresh failed, switching to direct Gemini API');
          _useDirectGeminiApi = true;
          return Message(
            text: text,
            isUser: true,
            timestamp: DateTime.now(),
          );
        }
        _hasApiError = false;
      }
      
      // Send message to API
      final response = await _apiService.sendMessage(sessionId, text);
      
      _logger.i('Message sent successfully to Jarvis API');
      return response;
    } catch (e) {
      _logger.e('Error sending message: $e');
      
      // If Jarvis API fails, switch to direct Gemini API
      if (!_useDirectGeminiApi) {
        _logger.i('Switching to direct Gemini API due to error');
        _useDirectGeminiApi = true;
      }
      
      // Always return a message to maintain UX
      final fallbackMessage = Message(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      );
      
      // Try to save the message locally
      if (sessionId.startsWith('local_')) {
        await _saveLocalMessage(sessionId, fallbackMessage);
      }
      return fallbackMessage;
    }   
  }      

  // Add helper methods for local message storage
  Future<void> _saveLocalMessage(String sessionId, Message message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing messages
      final List<String> existingMessages = prefs.getStringList(sessionId) ?? [];
      
      // Add the new message
      existingMessages.add(message.toJson());
      
      // Save back to preferences
      await prefs.setStringList(sessionId, existingMessages);
      
      _logger.i('Saved message to local storage for session: $sessionId');
    } catch (e) {
      _logger.e('Error saving local message: $e');
    } 
  }

  Future<List<Message>> _loadLocalMessages(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get saved messages
      final List<String> savedMessages = prefs.getStringList(sessionId) ?? [];
      
      if (savedMessages.isEmpty) {
        return [];
      }
      
      // Convert JSON strings to Message objects
      final messages = savedMessages.map((json) {
        try {
          return Message.fromJson(json);
        } catch (e) {
          _logger.e('Error parsing saved message: $e');
          return null;
        }
      }).whereType<Message>().toList();
      
      _logger.i('Loaded ${messages.length} messages from local storage for session: $sessionId');
      return messages;
    } catch (e) {
      _logger.e('Error loading local messages: $e');
      return [];
    } 
  }

  // Helper method to debug message storage
  Future<bool> _verifyLocalMessages(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedMessages = prefs.getStringList(sessionId) ?? [];
      
      if (savedMessages.isEmpty) {
        _logger.w('No messages found for session: $sessionId');
        return false;
      }
      
      // Check each message can be parsed
      int validCount = 0;
      for (int i = 0; i < savedMessages.length; i++) {
        try {
          final message = Message.fromJson(savedMessages[i]);
          validCount++;
          _logger.d('Message $i: ${message.isUser ? 'User' : 'AI'} - ${message.text.substring(0, Math.min(20, message.text.length))}');
        } catch (e) {
          _logger.e('Error parsing message $i: $e');
        }
      }
      
      _logger.i('Verified $validCount/${savedMessages.length} messages for session: $sessionId');
      return validCount == savedMessages.length;
    } catch (e) {
      _logger.e('Error verifying local messages: $e');
      return false;
    }
  }

  Future<void> _updateChatTitleIfFirstMessage(String sessionId, String message) async {
    try {
      final messages = await _loadLocalMessages(sessionId);
      if (messages.isEmpty) {
        _logger.i('Updating chat title for session: $sessionId');
        String title = _generateTitleFromMessage(message);
        await _saveChatTitle(sessionId, title);
      }
    } catch (e) {
      _logger.e('Error updating chat title: $e');
    }
  }

  Future<void> _saveChatTitle(String sessionId, String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> sessionsJson = prefs.getStringList('chat_sessions') ?? [];
      final sessions = sessionsJson.map((json) => ChatSession.fromJson(json)).toList();
      
      for (int i = 0; i < sessions.length; i++) {
        if (sessions[i].id == sessionId) {
          sessions[i] = sessions[i].copyWith(title: title);
          break;
        }
      }
      
      await prefs.setStringList('chat_sessions', sessions.map((session) => session.toJson()).toList());
    } catch (e) {
      _logger.e('Error saving chat title: $e');
    }
  }

  String _generateTitleFromMessage(String message) {
    // If message is short enough, use it directly
    if (message.length <= 30) {
      return message;
    }
    
    // Check if it contains a question
    final questionIndex = message.indexOf('?');
    if (questionIndex > 0 && questionIndex < 60) {
      return message.substring(0, questionIndex + 1);
    }
    
    // Look for the first sentence
    final sentenceEnd = message.indexOf('. ');
    if (sentenceEnd > 0 && sentenceEnd < 60) {
      return message.substring(0, sentenceEnd + 1);
    }
    
    // If message starts with common prefixes, try to extract a meaningful part
    final commonPrefixes = [
      'Can you ', 'Could you ', 'I need ', 'Please ', 'How do ', 
      'What is ', 'Why is ', 'When is ', 'Where is ', 'Who is '
    ];
    
    for (final prefix in commonPrefixes) {
      if (message.startsWith(prefix)) {
        // Find a good breaking point after the prefix
        final remainingText = message.substring(prefix.length);
        final breakIndex = remainingText.indexOf(' ', 25); // Look for space after at least 25 chars
        
        if (breakIndex > 0) {
          return prefix + remainingText.substring(0, breakIndex) + '...';
        }
      }
    }
    
    // Default to the first 30 characters with ellipsis
    return '${message.substring(0, Math.min(30, message.length))}...';
  }

  /// Get a direct response from the AI when using Gemini API
  Future<String> getDirectAIResponse(String text, List<Map<String, String>> chatHistory) async {
    try {
      _logger.i('Getting direct AI response using Gemini API');
      
      // Generate response using Gemini API
      final response = await _geminiApiService.generateChatResponse(text, chatHistory: chatHistory);
      
      _logger.i('Successfully generated AI response via Gemini');
      return response;
    } catch (e) {
      _logger.e('Error getting direct AI response: $e');
      return "I'm sorry, I couldn't generate a response at this time. Please try again later.";
    }
  }
  
  /// Create a new chat session with improved handling
  Future<ChatSession?> createChatSession(String title) async {
    try {
      _logger.i('Creating new chat session: $title');
      
      // First check if we should be using API
      if (_apiService.isAuthenticated() && !_useDirectGeminiApi) {
        _logger.i('Using API for chat session creation - user is authenticated');
        
        try {
          // Create conversation via API
          final session = await _apiService.createConversation(title);
          
          // Log ID details for debugging
          _logger.i('Chat session created with ID: ${session.id}');
          _logger.i('Is local session: ${session.id.startsWith('local_')}');
          
          return session;
        } catch (apiError) {
          _logger.e('API error creating session: $apiError');
          _hasApiError = true;
          
          // Fall through to local session creation
        }
      }
      
      // If using direct Gemini API or API call failed, create a local session
      _logger.i('Creating local chat session');
      return await _createLocalChatSession(title);
    } catch (e) {
      _logger.e('Error creating chat session: $e');
      return await _createLocalChatSession(title);
    }
  }
  
  /// Delete a chat session
  Future<bool> deleteChatSession(String sessionId) async {
    try {
      _logger.i('Deleting chat session: $sessionId');
      
      // Check if we had a previous API error
      if (_hasApiError) {
        _logger.w('Previous API error detected, attempting to refresh token');
        final refreshed = await _apiService.refreshToken();
        if (!refreshed) {
          throw 'Unable to refresh token after previous API error';
        }
        _hasApiError = false;
      }
      
      // Delete conversation via API
      final success = await _apiService.deleteConversation(sessionId);
      
      _logger.i('Chat session deleted: $success');
      return success;
    } catch (e) {
      _logger.e('Error deleting chat session: $e');
      
      // Mark as having API error for future requests
      _hasApiError = true;
      
      throw 'Failed to delete chat session: ${e.toString()}';
    }
  }
  
  /// Get available AI models
  Future<List<Map<String, String>>> getAvailableModels() async {
    try {
      _logger.i('Getting available AI models');
      
      // Get models from API
      final models = await _apiService.getAvailableModels();
      
      _logger.i('Retrieved ${models.length} available models');
      return models;
    } catch (e) {
      _logger.e('Error getting available models: $e');
      
      // Return default models as fallback
      final defaultModels = ApiConstants.modelNames.entries.map((entry) => {
        'id': entry.key,
        'name': entry.value,
      }).toList();
      
      return defaultModels;
    }
  }

  /// Get the currently selected AI model
  Future<String?> getSelectedModel() async {
    // Return cached value if available
    if (_selectedModel != null) {
      return _selectedModel;
    }
    
    try {
      _logger.i('Getting selected AI model');
      
      // Load selected model from preferences
      final prefs = await SharedPreferences.getInstance();
      final model = prefs.getString('selectedModel');
      
      if (model != null && model.isNotEmpty) {
        _selectedModel = model;
        _logger.i('Retrieved selected model: $model');
      } else {
        // Set default model if none is selected
        _selectedModel = ApiConstants.defaultModel;
        _logger.i('No selected model found, using default: ${ApiConstants.defaultModel}');
      }
      
      return _selectedModel;
    } catch (e) {
      _logger.e('Error getting selected model: $e');
      
      // Return default model as fallback
      return ApiConstants.defaultModel;
    }
  }
  
  /// Update the selected AI model
  Future<bool> updateSelectedModel(String modelId) async {
    try {
      _logger.i('Updating selected AI model to: $modelId');
      
      // Save selected model to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedModel', modelId);
      
      // Update cached value
      _selectedModel = modelId;
      
      _logger.i('Selected model updated successfully');
      return true;
    } catch (e) {
      _logger.e('Error updating selected model: $e');
      return false;
    }
  }
  
  /// Reset API error state
  void resetApiErrorState() {
    _logger.i('Resetting API error state');
    _hasApiError = false;
  }
  
  /// Check API connection
  Future<bool> checkApiConnection() async {
    try {
      _logger.i('Checking API connection');
      return await _apiService.checkApiStatus();
    } catch (e) {
      _logger.e('Error checking API connection: $e');
      return false;
    }
  }
  
  /// Check both API connections
  Future<Map<String, bool>> checkAllApiConnections() async {
    final results = <String, bool>{};
    try {
      _logger.i('Checking all API connections');
      
      // Check Jarvis API
      results['jarvisApi'] = await checkApiConnection();
      
      // Check Gemini API
      results['geminiApi'] = await _geminiApiService.checkApiStatus();
      
      return results;
    } catch (e) {
      _logger.e('Error checking API connections: $e');
      return {
        'jarvisApi': false,
        'geminiApi': false,
      };
    }
  }
  
  /// Toggle between Jarvis API and direct Gemini API
  void toggleDirectGeminiApi(bool useDirectApi) {
    _logger.i('Toggling direct Gemini API: $useDirectApi');
    _useDirectGeminiApi = useDirectApi;
  }
  
  /// Get whether direct Gemini API is in use
  bool isUsingDirectGeminiApi() {
    return _useDirectGeminiApi;
  }

  /// Get diagnostic information for troubleshooting
  Map<String, dynamic> getDiagnosticInfo() {
    return {
      'isUsingDirectGeminiApi': _useDirectGeminiApi,
      'hasApiError': _hasApiError,
      'selectedModel': _selectedModel,
      'lastApiFailure': _lastApiFailure?.toString(),
      'apiServiceAuthenticated': _apiService.isAuthenticated(),
      'apiConfig': _apiService.getApiConfig(),
    };
  }
  
  /// Forces an authentication state update by refreshing the token
  Future<bool> forceAuthStateUpdate() async {
    try {
      _logger.i('Forcing authentication state update');
      final success = await _apiService.forceTokenRefresh();
      
      if (success) {
        _hasApiError = false;
        _logger.i('Authentication state updated successfully');
      } else {
        _logger.w('Authentication state update failed');
      }
      
      return success;
    } catch (e) {
      _logger.e('Error during force auth state update: $e');
      return false;
    }
  }

  /// Check if we need to reset fallback mode on startup
  Future<void> _resetFallbackIfNeeded() async {
    try {
      // Get the most recent setting
      final prefs = await SharedPreferences.getInstance();
      final usesFallback = prefs.getBool('use_local_fallback') ?? false;
      
      // If we're using fallback but the user is authenticated, try to reset
      if (usesFallback && _apiService.isAuthenticated()) {
        _logger.i('User is authenticated but fallback mode is active, attempting to reset');
        
        // Check if API is accessible
        final apiStatus = await _apiService.checkApiStatus();
        if (apiStatus) {
          _logger.i('API is accessible, resetting fallback mode');
          _useDirectGeminiApi = false;
          _apiService.switchToFallbackMode();
        }
      }
    } catch (e) {
      _logger.e('Error checking fallback mode: $e');
    }
  }

  /// Force service to use API mode and reset fallback flags
  Future<bool> forceUseApiMode() async {
    try {
      _logger.i('Forcing use of API mode');
      
      // Reset the flags
      _useDirectGeminiApi = false;
      _hasApiError = false;
      
      // Force token refresh to ensure we have a valid token
      final tokenRefreshed = await _apiService.forceTokenRefresh();
      _logger.i('Token refresh result: $tokenRefreshed');
      
      // Save the setting
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_direct_gemini', false);
      
      // Test API access
      final apiStatus = await _apiService.checkApiStatus();
      _logger.i('API status check result: $apiStatus');
      
      return apiStatus;
    } catch (e) {
      _logger.e('Error forcing API mode: $e');
      return false;
    }
  }
}
