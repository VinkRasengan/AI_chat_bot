import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/api_constants.dart';
import '../../models/chat/chat_session.dart';
import '../../models/chat/message.dart';
import '../auth/auth_service.dart';

/// Unified Chat Service
class JarvisChatService {
  final Logger _logger = Logger();
  final AuthService _authService;
  
  // Selected model
  String? _selectedModel;
  
  // Other state
  bool _isInitialized = false;
  List<ChatSession> _chatSessions = [];
  DateTime? _lastChatSessionsRefresh;
  
  JarvisChatService(this._authService);
  
  /// Initialize the chat service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.i('Initializing JarvisChatService');
      
      // Load selected model from preferences
      await getSelectedModel();
      
      _isInitialized = true;
    } catch (e) {
      _logger.e('Error initializing JarvisChatService: $e');
      rethrow;
    }
  }
  
  /// Get conversations/chat sessions for the current user
  Future<List<ChatSession>> getUserChatSessions() async {
    try {
      _logger.i('Getting user chat sessions');
      
      // Check if we have cached results and they are still fresh (less than 30 seconds old)
      if (_lastChatSessionsRefresh != null &&
          DateTime.now().difference(_lastChatSessionsRefresh!).inSeconds < 30 &&
          _chatSessions.isNotEmpty) {
        _logger.i('Returning cached chat sessions (${_chatSessions.length})');
        return _chatSessions;
      }
      
      // Check if user is logged in
      final isLoggedIn = await _authService.isLoggedIn();
      if (!isLoggedIn) {
        _logger.w('User is not logged in, returning empty chat sessions list');
        return [];
      }
      
      // Get model info to check if it supports conversations
      final selectedModel = await getSelectedModel();
      final supportsHistory = ApiConstants.modelSupportsConversationHistory[selectedModel ?? ''] ?? false;
      
      if (!supportsHistory) {
        _logger.i('Selected model does not support conversation history');
        return [];
      }
      
      // Make API request
      final response = await http.get(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.conversations}'),
        headers: _authService.getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['items'] != null) {
          _chatSessions = (data['items'] as List)
              .map((item) => ChatSession(
                    id: item['id'] ?? '',
                    title: item['title'] ?? 'New Chat',
                    createdAt: item['createdAt'] != null
                        ? DateTime.fromMillisecondsSinceEpoch(item['createdAt'] * 1000)
                        : DateTime.now(),
                  ))
              .toList();
          
          _lastChatSessionsRefresh = DateTime.now();
          return _chatSessions;
        }
        
        return [];
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to refresh token and retry
        final refreshed = await _authService.refreshToken();
        if (refreshed) {
          return getUserChatSessions();
        } else {
          throw 'Authentication failed';
        }
      } else {
        _logger.e('Error getting chat sessions: ${response.statusCode} ${response.body}');
        throw 'Failed to get chat sessions';
      }
    } catch (e) {
      _logger.e('Error getting user chat sessions: $e');
      rethrow;
    }
  }
  
  /// Create a new chat session
  Future<ChatSession> createChatSession(String title) async {
    try {
      _logger.i('Creating new chat session: $title');
      
      // Get the selected model
      final selectedModel = await getSelectedModel();
      
      // Check if model supports conversation history
      final supportsHistory = ApiConstants.modelSupportsConversationHistory[selectedModel ?? ''] ?? false;
      
      if (!supportsHistory) {
        // Create a local session when model doesn't support server conversations
        final chatSession = ChatSession(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          title: title.isEmpty ? 'New Chat' : title,
          createdAt: DateTime.now(),
        );
        
        return chatSession;
      }
      
      // Create an API request body
      final requestBody = {
        'title': title.isEmpty ? 'New Chat' : title,
        'assistantModel': 'dify',  // Required parameter per API docs
      };
      
      // Add assistant ID if we have a selected model
      if (selectedModel != null && selectedModel.isNotEmpty) {
        requestBody['assistantId'] = selectedModel;
      }
      
      // Make API request
      final response = await http.post(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.conversations}'),
        headers: _authService.getHeaders(),
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Create a chat session from the response
        final chatSession = ChatSession(
          id: data['id'] ?? '',
          title: data['title'] ?? 'New Chat',
          createdAt: data['createdAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] * 1000)
              : DateTime.now(),
        );
        
        // Clear cache to force refresh on next getUserChatSessions
        _lastChatSessionsRefresh = null;
        
        return chatSession;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to refresh token and retry
        final refreshed = await _authService.refreshToken();
        if (refreshed) {
          return createChatSession(title);
        } else {
          throw 'Authentication failed';
        }
      } else {
        _logger.e('Error creating chat session: ${response.statusCode} ${response.body}');
        throw 'Failed to create chat session';
      }
    } catch (e) {
      _logger.e('Error creating chat session: $e');
      rethrow;
    }
  }
  
  /// Delete a chat session
  Future<bool> deleteChatSession(String sessionId) async {
    try {
      _logger.i('Deleting chat session: $sessionId');
      
      // Check if it's a local session
      if (sessionId.startsWith('local_')) {
        // For local sessions, just return success immediately
        _lastChatSessionsRefresh = null;
        return true;
      }
      
      // Make API request
      final response = await http.delete(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.conversations}/$sessionId'),
        headers: _authService.getHeaders(),
      );
      
      // Clear cache to force refresh on next getUserChatSessions
      _lastChatSessionsRefresh = null;
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      _logger.e('Error deleting chat session: $e');
      return false;
    }
  }
  
  /// Get messages for a conversation
  Future<List<Message>> getMessages(String conversationId) async {
    try {
      _logger.i('Getting messages for conversation: $conversationId');
      
      // Check if it's a local session
      if (conversationId.startsWith('local_')) {
        return [];
      }
      
      // Make API request
      final response = await http.get(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.conversationMessages(conversationId)}'),
        headers: _authService.getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Message> messages = [];
        
        if (data['items'] != null) {
          for (var item in data['items']) {
            // User message has a 'query' field, bot message has an 'answer' field
            final bool isUserMessage = item.containsKey('query');
            final String content = isUserMessage ? (item['query'] ?? '') : (item['answer'] ?? '');
            
            messages.add(Message(
              id: item['id'] ?? '',
              text: content,
              isUser: isUserMessage,
              timestamp: item['createdAt'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(item['createdAt'] * 1000)
                  : DateTime.now(),
              metadata: item['metadata'],
            ));
          }
        }
        
        return messages;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to refresh token and retry
        final refreshed = await _authService.refreshToken();
        if (refreshed) {
          return getMessages(conversationId);
        } else {
          throw 'Authentication failed';
        }
      } else {
        _logger.e('Error getting messages: ${response.statusCode} ${response.body}');
        throw 'Failed to get messages';
      }
    } catch (e) {
      _logger.e('Error getting messages: $e');
      return [];
    }
  }
  
  /// Send a message in a conversation
  Future<void> sendMessage(String conversationId, String message) async {
    try {
      _logger.i('Sending message to conversation: $conversationId');
      
      // Check if it's a local session
      if (conversationId.startsWith('local_')) {
        throw 'Cannot send messages to local sessions via API';
      }
      
      // Make API request
      final response = await http.post(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.messages}'),
        headers: _authService.getHeaders(),
        body: jsonEncode({
          'conversation_id': conversationId,
          'content': message,
          'model': _selectedModel ?? ApiConstants.defaultModel,
        }),
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        _logger.e('Error sending message: ${response.statusCode} ${response.body}');
        throw 'Failed to send message';
      }
    } catch (e) {
      _logger.e('Error sending message: $e');
      throw 'Error: $e';
    }
  }
  
  /// Get AI response directly from the API
  Future<String> getDirectAIResponse(String message) async {
    try {
      _logger.i('Getting direct AI response for message: ${message.substring(0, min(20, message.length))}...');
      
      final selectedModel = await getSelectedModel();
      
      final response = await http.post(
        Uri.parse('${ApiConstants.jarvisApiUrl}/api/v1/ai-chat/completion'),
        headers: _authService.getHeaders(),
        body: jsonEncode({
          'model': selectedModel ?? ApiConstants.defaultModel,
          'messages': [
            {'role': 'user', 'content': message}
          ],
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? 'No response generated';
      } else {
        _logger.e('Error getting AI response: ${response.statusCode} ${response.body}');
        throw 'Failed to get AI response';
      }
    } catch (e) {
      _logger.e('Error getting direct AI response: $e');
      throw 'Error: $e';
    }
  }
  
  /// Check if using direct API mode
  Future<bool> isUsingDirectGeminiApi() async {
    try {
      // Always false now that we don't use Gemini API directly
      return false;
    } catch (e) {
      _logger.e('Error checking if using direct Gemini API: $e');
      return false;
    }
  }
  
  /// Check all API connections
  Future<Map<String, bool>> checkAllApiConnections() async {
    try {
      final results = <String, bool>{};
      
      // Check auth API
      try {
        final authResponse = await http.get(
          Uri.parse('${ApiConstants.authApiUrl}/api/v1/status'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 5));
        
        results['authApi'] = authResponse.statusCode == 200;
      } catch (e) {
        results['authApi'] = false;
      }
      
      // Check Jarvis API
      try {
        final jarvisResponse = await http.get(
          Uri.parse('${ApiConstants.jarvisApiUrl}/api/v1/status'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 5));
        
        results['jarvisApi'] = jarvisResponse.statusCode == 200;
      } catch (e) {
        results['jarvisApi'] = false;
      }
      
      // Add an authenticated check
      try {
        final authCheckedResponse = await http.get(
          Uri.parse('${ApiConstants.jarvisApiUrl}/api/v1/status'),
          headers: _authService.getHeaders(),
        ).timeout(const Duration(seconds: 5));
        
        results['authenticated'] = authCheckedResponse.statusCode == 200;
      } catch (e) {
        results['authenticated'] = false;
      }
      
      return results;
    } catch (e) {
      _logger.e('Error checking API connections: $e');
      return {'error': false};
    }
  }
  
  /// Get diagnostic information
  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    try {
      final info = <String, dynamic>{};
      
      // Add basic info
      info['selectedModel'] = await getSelectedModel();
      info['isInitialized'] = _isInitialized;
      info['isLoggedIn'] = await _authService.isLoggedIn();
      info['usingDirectAPI'] = false;
      
      // Check API connections
      info['apiConnections'] = await checkAllApiConnections();
      
      return info;
    } catch (e) {
      _logger.e('Error getting diagnostic info: $e');
      return {'error': e.toString()};
    }
  }
  
  /// Force update of API mode
  Future<void> forceUseApiMode(bool useAPI) async {
    // This method is now just a compatibility stub since we always use the API
    _logger.i('Force use API mode called with: $useAPI (always true now)');
  }
  
  /// Force update of auth state
  Future<bool> forceAuthStateUpdate() async {
    return await _authService.forceAuthStateUpdate();
  }
  
  /// Get the selected model
  Future<String?> getSelectedModel() async {
    try {
      // If we already have a cached value, return it
      if (_selectedModel != null) {
        return _selectedModel;
      }
      
      // Otherwise, try to load from preferences
      final prefs = await SharedPreferences.getInstance();
      _selectedModel = prefs.getString('selectedModel');
      
      // Set default if not found
      if (_selectedModel == null || _selectedModel!.isEmpty) {
        _selectedModel = ApiConstants.defaultModel;
      }
      
      return _selectedModel;
    } catch (e) {
      _logger.e('Error getting selected model: $e');
      return ApiConstants.defaultModel;
    }
  }
  
  /// Update the selected model
  Future<void> updateSelectedModel(String modelId) async {
    try {
      _logger.i('Updating selected model to: $modelId');
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedModel', modelId);
      
      // Update cached value
      _selectedModel = modelId;
      
      // Clear chat sessions cache since a model change might affect available sessions
      _lastChatSessionsRefresh = null;
    } catch (e) {
      _logger.e('Error updating selected model: $e');
    }
  }
  
  // Toggle direct Gemini API use - now a legacy method
  Future<void> toggleDirectGeminiApi() async {
    _logger.i('Toggle direct Gemini API called (now a no-op)');
  }
  
  // Helper function to get min of two integers
  int min(int a, int b) {
    return a < b ? a : b;
  }
}
