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
      _logger.i('JarvisChatService initialized successfully');
    } catch (e) {
      _logger.e('Error initializing JarvisChatService: $e');
      // Don't rethrow to prevent app startup failures
      _isInitialized = true; // Mark as initialized anyway to prevent repeated failures
    }
  }
  
  /// Get conversations/chat sessions for the current user
  Future<List<ChatSession>> getUserChatSessions({int retryCount = 0}) async {
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
      
      // Prepare query parameters according to the API documentation
      final queryParams = {
        'assistantModel': 'dify', // Required parameter per API docs
        'limit': '100',
      };

      // Add assistantId if we have a selected model
      if (selectedModel != null && selectedModel.isNotEmpty) {
        queryParams['assistantId'] = selectedModel;
      }

      // Build the URI with query parameters
      final uri = Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.conversations}')
          .replace(queryParameters: queryParams);
      
      // Get auth headers
      final headers = _authService.getHeaders();
      // Add x-jarvis-guid header which is specified in the API doc
      headers['x-jarvis-guid'] = '';
      
      // Make API request
      final response = await http.get(
        uri,
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Parse response according to documented structure with better error handling
        if (data.containsKey('items') && data['items'] is List) {
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
          
          // Save cursor for potential pagination if needed
          if (data['cursor'] != null && data['has_more'] == true) {
            _logger.i('Pagination available with cursor: ${data['cursor']}');
            // Store cursor for potential pagination implementation
          }
          
          return _chatSessions;
        } else {
          _logger.w('No items found in chat sessions response or invalid format');
          return [];
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Limit the number of retries to avoid infinite recursion
        if (retryCount >= 2) {
          _logger.w('Max retry count reached for token refresh, returning empty list');
          return [];
        }
        
        // Try to refresh token and retry with non-recursive approach
        final refreshed = await _authService.refreshToken();
        if (refreshed) {
          // Increment retry count and try again, but don't call this method recursively
          return await getUserChatSessions(retryCount: retryCount + 1);
        } else {
          _logger.w('Token refresh failed, returning empty list');
          return [];
        }
      } else {
        _logger.e('Error getting chat sessions: ${response.statusCode} ${response.body}');
        throw 'Failed to get chat sessions';
      }
    } catch (e) {
      _logger.e('Error getting user chat sessions: $e');
      return [];
    }
  }
  
  /// Create a new chat session
  Future<ChatSession> createChatSession(String title, {int retryCount = 0}) async {
    try {
      _logger.i('Creating new chat session: $title');
      
      // Get the selected model
      final selectedModel = await getSelectedModel();
      
      // Check if model supports conversation history
      final supportsHistory = ApiConstants.modelSupportsConversationHistory[selectedModel ?? ''] ?? false;
      
      if (!supportsHistory) {
        throw 'Selected model does not support conversation history. Please select another model.';
      }
      
      // Based on the example code, we need to send an initial message to create a conversation
      // Since there's no direct endpoint for creating empty conversations
      final modelName = ApiConstants.modelNames[selectedModel ?? ApiConstants.defaultModel] ?? 'AI Assistant';
      
      // Get headers and add x-jarvis-guid header
      final headers = _authService.getHeaders();
      headers['x-jarvis-guid'] = '';
      
      // Initial message to create conversation
      final response = await http.post(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.messages}'),
        headers: headers,
        body: jsonEncode({
          'content': 'Create a new chat titled: $title',
          'files': [],
          'metadata': {
            'conversation': {
              'messages': []  // No previous messages since this is new
            }
          },
          'assistant': {
            'id': selectedModel ?? ApiConstants.defaultModel,
            'model': 'dify',
            'name': modelName
          }
        }),
      );
      
      _logger.d('Create conversation response: ${response.statusCode} ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Get the conversation ID from the response
        final conversationId = data['conversationId'] ?? '';
        
        if (conversationId.isEmpty) {
          throw 'Failed to get conversation ID from response';
        }
        
        // Create a chat session from the response
        final chatSession = ChatSession(
          id: conversationId,
          title: title.isEmpty ? 'New Chat' : title,
          createdAt: DateTime.now(),
        );
        
        // Clear cache to force refresh on next getUserChatSessions
        _lastChatSessionsRefresh = null;
        
        return chatSession;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Limit the number of retries
        if (retryCount >= 2) {
          _logger.w('Max retry count reached for token refresh');
          throw 'Authentication failed after multiple attempts';
        }
        
        // Try to refresh token and retry with non-recursive approach
        final refreshed = await _authService.refreshToken();
        if (refreshed) {
          // Increment retry count and try again
          return await createChatSession(title, retryCount: retryCount + 1);
        } else {
          throw 'Authentication failed';
        }
      } else {
        _logger.e('Error creating chat session: ${response.statusCode} ${response.body}');
        throw 'Failed to create chat session: ${response.statusCode}';
      }
    } catch (e) {
      _logger.e('Error creating chat session: $e');
      throw 'Failed to create chat session: $e';
    }
  }
  
  /// Delete a chat session
  Future<bool> deleteChatSession(String sessionId) async {
    try {
      _logger.i('Deleting chat session: $sessionId');
      
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
  Future<List<Message>> getMessages(String conversationId, {int retryCount = 0}) async {
    try {
      _logger.i('Getting messages for conversation: $conversationId');
      
      // Prepare query parameters according to the API documentation
      final queryParams = {
        'assistantModel': 'dify', // Required parameter per API docs
        'limit': '100',
      };

      // Add assistantId if we have a selected model
      final selectedModel = await getSelectedModel();
      if (selectedModel != null && selectedModel.isNotEmpty) {
        queryParams['assistantId'] = selectedModel;
      }

      // Build the URI with query parameters
      final uri = Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.conversationMessages(conversationId)}')
          .replace(queryParameters: queryParams);
      
      // Get headers and add required x-jarvis-guid header
      final headers = _authService.getHeaders();
      headers['x-jarvis-guid'] = '';
      
      // Make API request
      final response = await http.get(
        uri,
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Message> messages = [];
        
        // Parse items array from the response with better error handling
        if (data.containsKey('items') && data['items'] is List) {
          for (var item in data['items']) {
            // User message has a 'query' field, bot message has an 'answer' field
            final bool isUserMessage = item.containsKey('query');
            final String content = isUserMessage ? (item['query'] ?? '') : (item['answer'] ?? '');
            
            messages.add(Message(
              id: item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              text: content,
              isUser: isUserMessage,
              timestamp: item['createdAt'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(item['createdAt'] * 1000)
                  : DateTime.now(),
              metadata: item,
            ));
          }
        } else {
          _logger.w('No items found in messages response or invalid format');
        }
        
        // Store pagination info if available for potential future use
        final hasCursor = data['cursor'] != null && data['cursor'].toString().isNotEmpty;
        final hasMore = data['has_more'] == true;
        
        if (hasCursor && hasMore) {
          _logger.i('Pagination available with cursor: ${data['cursor']}');
          // Store cursor for potential pagination implementation
        }
        
        return messages;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Limit the number of retries
        if (retryCount >= 2) {
          _logger.w('Max retry count reached for token refresh, returning empty list');
          return [];
        }
        
        // Try to refresh token and retry with non-recursive approach
        final refreshed = await _authService.refreshToken();
        if (refreshed) {
          // Get fresh headers after token refresh
          final newHeaders = _authService.getHeaders();
          newHeaders['x-jarvis-guid'] = '';
          
          // Retry the request with fresh headers
          final retryResponse = await http.get(
            uri,
            headers: newHeaders,
          );
          
          if (retryResponse.statusCode == 200) {
            final data = jsonDecode(retryResponse.body);
            List<Message> messages = [];
            
            // Parse items array from the response
            for (var item in data['items'] ?? []) {
              // User message has a 'query' field, bot message has an 'answer' field
              final bool isUserMessage = item.containsKey('query');
              final String content = isUserMessage ? (item['query'] ?? '') : (item['answer'] ?? '');
              
              messages.add(Message(
                id: item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                text: content,
                isUser: isUserMessage,
                timestamp: item['createdAt'] != null
                    ? DateTime.fromMillisecondsSinceEpoch(item['createdAt'] * 1000)
                    : DateTime.now(),
                metadata: item,
              ));
            }
            
            return messages;
          } else {
            _logger.w('Retry failed after token refresh, returning empty message list');
            return [];
          }
        } else {
          _logger.w('Token refresh failed, returning empty message list');
          return [];
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
  Future<Map<String, dynamic>> sendMessage(String conversationId, String message) async {
    try {
      _logger.i('Sending message to conversation: $conversationId');
      
      // Get selected model
      final selectedModel = await getSelectedModel() ?? ApiConstants.defaultModel;
      if (selectedModel == ApiConstants.defaultModel) {
        _logger.w('Using default model as no model was selected');
      }
      final modelName = ApiConstants.modelNames[selectedModel] ?? 'AI Assistant';
      
      // Get conversation history for proper formatting
      final messages = await getMessages(conversationId);
      
      // Format messages according to API requirements - only include previous messages
      final formattedMessages = messages.map((msg) => {
        'role': msg.isUser ? 'user' : 'model',
        'content': msg.text,
        'files': [],
        'assistant': {
          'id': selectedModel,
          'model': 'dify',
          'name': modelName
        }
      }).toList();
      
      // Get headers and add x-jarvis-guid header
      final headers = _authService.getHeaders();
      headers['x-jarvis-guid'] = '';
      
      // Make API request with proper structure per API documentation
      final response = await http.post(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.messages}'),
        headers: headers,
        body: jsonEncode({
          'content': message, // New message only in content field
          'files': [],
          'metadata': {
            'conversation': {
              'id': conversationId,
              'messages': formattedMessages // Only previous messages, not including the new one
            }
          },
          'assistant': {
            'id': selectedModel,
            'model': 'dify',
            'name': modelName
          }
        }),
      );
      
      if (response.statusCode == 200) {
        // Parse response
        final data = jsonDecode(response.body);
        _logger.i('Message sent successfully. Response: ${data['message']}');
        _logger.d('Conversation ID: ${data['conversationId']}, Remaining Usage: ${data['remainingUsage']}');
        
        // Force the cache to refresh for this conversation since we have new messages
        _lastChatSessionsRefresh = null;
        
        // Return both the user message and AI response for proper UI updates
        return {
          'message': data['message'],          // AI's response text
          'conversationId': data['conversationId'],
          'remainingUsage': data['remainingUsage'],
          'userMessage': message,              // Original user message
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'success': true
        };
      } else {
        _logger.e('Error sending message: ${response.statusCode} ${response.body}');
        return {
          'error': 'Failed to send message: ${response.statusCode}',
          'success': false
        };
      }
    } catch (e) {
      _logger.e('Error sending message: $e');
      return {
        'error': 'Failed to send message: $e',
        'success': false
      };
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
    // Always use the server API
    return false;
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
    _logger.i('Force use API mode called (always true now)');
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
