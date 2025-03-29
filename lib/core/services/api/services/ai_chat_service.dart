import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/chat/chat_session.dart';
import '../../../models/chat/message.dart';
import '../../../constants/api_constants.dart';
import 'auth_service.dart';

/// Service for AI chat operations
class AiChatService {
  final Logger _logger = Logger();
  final AuthService _authService;
  final String _jarvisApiUrl = ApiConstants.jarvisApiUrl;
  
  // Store selected model
  String? _selectedModel;
  
  // Error tracking
  bool _hasAuthError = false;
  int _errorCount = 0;
  
  AiChatService(this._authService);
  
  /// Get headers with force refresh option 
  Future<Map<String, String>> _getHeaders({bool forceRefresh = false}) async {
    // If we've had auth errors, try to refresh the token first
    if (_hasAuthError || forceRefresh) {
      _logger.i('Auth error detected, attempting to refresh token before request');
      try {
        await _authService.refreshToken();
        _hasAuthError = false; // Reset error flag on successful refresh
      } catch (e) {
        _logger.e('Token refresh failed: $e');
        // Continue with current token, but keep error flag
      }
    }
    
    return _authService.getHeaders();
  }
  
  /// Get a list of conversations for the current user
  Future<List<ChatSession>> getConversations() async {
    // Check if we have a valid token
    await _checkForValidToken();
    
    try {
      // Check if selected model supports conversation history
      final model = await getSelectedModel();
      final supportsHistory = ApiConstants.modelSupportsConversationHistory[model] ?? false;
      
      if (!supportsHistory) {
        _logger.i('Selected model does not support conversation history, returning empty list');
        return [];
      }
      
      // Prepare query parameters according to the API documentation
      final queryParams = {
        'limit': '100',
        'assistantModel': 'dify', // Required parameter per API docs
      };

      // Add assistantId if we have a selected model
      if (_selectedModel != null && _selectedModel!.isNotEmpty) {
        queryParams['assistantId'] = _selectedModel!;
      }

      // Build the URI with query parameters
      final uri = Uri.parse('$_jarvisApiUrl${ApiConstants.conversations}')
          .replace(queryParameters: queryParams);

      _logger.i('Getting conversations: $uri');

      // Get headers with token refresh if needed
      final headers = await _getHeaders(forceRefresh: _errorCount > 0);
      // Add x-jarvis-guid header which might be required by the API
      headers['x-jarvis-guid'] = '';
      
      final response = await http.get(
        uri,
        headers: headers,
      );

      _logger.d('Conversations response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Reset error count on success
        _errorCount = 0;
        _hasAuthError = false;
        
        final data = jsonDecode(response.body);
        List<ChatSession> conversations = [];

        // Parse items array from the response
        for (var item in data['items'] ?? []) {
          conversations.add(ChatSession(
            id: item['id'] ?? '',
            title: item['title'] ?? 'New Chat',
            createdAt: item['createdAt'] != null
                ? DateTime.fromMillisecondsSinceEpoch(item['createdAt'] * 1000)
                : DateTime.now(),
          ));
        }

        return conversations;
      } else if (response.statusCode == 400) {
        // Parse the response to check for the specific error about conversation history
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? '';
          
          if (errorMessage.contains('does not support conversation history')) {
            _logger.i('Model does not support conversation history, returning empty list without error');
            // This is an expected limitation, not an error
            return [];
          }
        } catch (e) {
          // If we can't parse the response, continue with normal error handling
          _logger.e('Error parsing 400 response: $e');
        }
        
        _logger.e('Error getting conversations: ${response.body}');
        throw 'Failed to get conversations: ${response.statusCode} ${response.reasonPhrase}';
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _hasAuthError = true;
        _errorCount++;
        
        // Try to refresh the token and try again
        await _authService.refreshToken();
        
        // If this is our first retry, try again
        if (_errorCount < 2) {
          _logger.i('Retrying getConversations after token refresh');
          return await getConversations();
        }
        
        throw 'Authentication failed. Please log in again.';
      } else if (response.statusCode == 404) {
        // Handle 404 errors - could mean the endpoint is not available
        _logger.w('Conversations endpoint not found (404)');
        return [];
      } else {
        _logger.e('Error getting conversations: ${response.body}');
        throw 'Failed to get conversations: ${response.statusCode} ${response.reasonPhrase}';
      }
    } catch (e) {
      // Special handling for the "conversation history not supported" error
      if (e.toString().toLowerCase().contains('does not support conversation history')) {
        _logger.i('Model does not support conversation history, returning empty list');
        return [];
      }
      
      _errorCount++;
      _logger.e('Error getting conversations: $e');
      throw 'Failed to get conversations: $e';
    }
  }
  
  /// Get conversation history/messages for a specific conversation
  Future<List<Message>> getConversationHistory(String conversationId) async {
    try {
      _logger.i('Getting conversation history for: $conversationId');
      
      // Prepare query parameters according to the API documentation
      final queryParams = {
        'limit': '100',
        'assistantModel': 'dify', // Required parameter per API docs
      };

      // Add assistantId if we have a selected model
      if (_selectedModel != null && _selectedModel!.isNotEmpty) {
        queryParams['assistantId'] = _selectedModel!;
      }

      // Build the URI with the conversationId path parameter and query parameters
      // Make sure there are no double slashes in the path by using proper path joining
      final uri = Uri.parse('$_jarvisApiUrl${ApiConstants.conversationMessages(conversationId)}')
          .replace(queryParameters: queryParams);
      
      // Get headers with token refresh if needed
      final headers = await _getHeaders(forceRefresh: _hasAuthError);
      // Add x-jarvis-guid header which might be required by the API
      headers['x-jarvis-guid'] = '';
      
      final response = await http.get(
        uri,
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        // Reset error tracking on success
        _hasAuthError = false;
        
        final data = jsonDecode(response.body);
        List<Message> messages = [];
        
        // Parse items array from the response
        for (var item in data['items'] ?? []) {
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
        
        return messages;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _hasAuthError = true;
        
        // Try to refresh the token and retry once
        await _authService.refreshToken();
        
        // Retry the request with fresh token
        final retryHeaders = await _getHeaders(forceRefresh: true);
        final retryResponse = await http.get(
          uri,
          headers: retryHeaders,
        );
        
        if (retryResponse.statusCode == 200) {
          _hasAuthError = false;
          
          final data = jsonDecode(retryResponse.body);
          List<Message> messages = [];
          
          for (var item in data['items'] ?? []) {
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
          
          return messages;
        }
        
        // If retry also failed, throw error
        throw 'Authentication failed after token refresh';
      } else if (response.statusCode == 404) {
        // Handle 404 errors - this could be a new conversation
        _logger.w('Conversation history not found for ID: $conversationId');
        return [];
      } else {
        _logger.e('Error getting conversation history: ${response.statusCode} ${response.body}');
        throw 'Failed to get conversation history: ${response.statusCode} ${response.reasonPhrase}';
      }
    } catch (e) {
      _logger.e('Error getting conversation history: $e');
      
      // If this is an authentication issue, mark for future requests
      if (e.toString().contains('401') || 
          e.toString().contains('403') || 
          e.toString().contains('Authentication failed')) {
        _hasAuthError = true;
      }
      
      // Return empty list for less disruptive UX
      return [];
    }
  }
  
  /// Send a message to a conversation
  Future<Message> sendMessage(String conversationId, String text) async {
    try {
      _logger.i('Sending message to conversation: $conversationId');
      
      // First, get the existing conversation to build the history
      List<Message> existingMessages = [];
      try {
        existingMessages = await getConversationHistory(conversationId);
        _logger.d('Retrieved ${existingMessages.length} existing messages for conversation');
      } catch (e) {
        _logger.w('Error retrieving message history, proceeding with empty history: $e');
      }
      
      // Get the assistant details (using default if none specified)
      final assistantId = _selectedModel ?? ApiConstants.defaultModel;
      final assistantName = ApiConstants.modelNames[assistantId] ?? 'AI Assistant';
      
      // Format the message history according to the API requirements
      final messageHistory = existingMessages.map((msg) => {
        'role': msg.isUser ? 'user' : 'model',
        'content': msg.text,
        'files': [],
        'assistant': {
          'id': assistantId,
          'model': 'dify',
          'name': assistantName
        }
      }).toList();
      
      // Add the new user message to the history
      messageHistory.add({
        'role': 'user',
        'content': text,
        'files': [],
        'assistant': {
          'id': assistantId,
          'model': 'dify',
          'name': assistantName
        }
      });
      
      // Build the request body according to the API documentation
      final requestBody = {
        'content': text,
        'files': [],
        'metadata': {
          'conversation': {
            'id': conversationId,
            'messages': messageHistory
          }
        },
        'assistant': {
          'id': assistantId,
          'model': 'dify',
          'name': assistantName
        }
      };
      
      // Use the exact endpoint from constants
      final uri = Uri.parse('$_jarvisApiUrl${ApiConstants.messages}');
      
      _logger.d('Sending message request: ${jsonEncode(requestBody)}');
      
      // Get headers with token refresh if needed
      final headers = await _getHeaders(forceRefresh: _hasAuthError);
      // Add x-jarvis-guid header which might be required by the API
      headers['x-jarvis-guid'] = '';
      
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      );
      
      _logger.d('Message response code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Reset auth error flag on success
        _hasAuthError = false;
        
        final data = jsonDecode(response.body);
        
        _logger.i('Message sent successfully, received response: ${data['message']}');
        
        // Create and return a user message object to represent the sent message
        return Message(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _hasAuthError = true;
        
        // Try refreshing the token and retry once
        await _authService.refreshToken();
        
        // Only retry once to avoid infinite loops
        _logger.i('Retrying send message with fresh token');
        
        final retryHeaders = await _getHeaders(forceRefresh: true);
        final retryResponse = await http.post(
          uri,
          headers: retryHeaders,
          body: jsonEncode(requestBody),
        );
        
        if (retryResponse.statusCode == 200) {
          _hasAuthError = false;
          final data = jsonDecode(retryResponse.body);
          _logger.i('Retry successful, received response: ${data['message']}');
          
          return Message(
            text: text,
            isUser: true,
            timestamp: DateTime.now(),
          );
        }
        
        // If retry failed, throw an error
        throw 'Authentication failed after token refresh';
      } else {
        _logger.e('Error sending message: ${response.body}');
        throw 'Failed to send message: ${response.statusCode} ${response.reasonPhrase}';
      }
    } catch (e) {
      _logger.e('Error sending message: $e');
      
      // If this is an authentication issue, mark for future requests
      if (e.toString().contains('401') || 
          e.toString().contains('403') || 
          e.toString().contains('Authentication failed')) {
        _hasAuthError = true;
      }
      
      throw 'Error: $e';
    }
  }
  
  /// Create a new conversation
  Future<ChatSession> createConversation(String title) async {
    try {
      _logger.i('Creating new conversation: $title');
      
      // Check token before attempting API call
      final hasToken = await _checkForValidToken();
      if (!hasToken) {
        _logger.w('No valid token found, attempting to refresh before creating conversation');
        await _authService.refreshToken();
      }
      
      // Check if selected model supports conversation history
      final model = await getSelectedModel();
      final supportsHistory = ApiConstants.modelSupportsConversationHistory[model] ?? false;
      
      if (!supportsHistory) {
        _logger.i('Selected model does not support conversation history, cannot create server conversation');
        throw 'The selected model does not support conversation history';
      }
      
      // Use the exact endpoint from constants - make sure path is correctly formed
      final uri = Uri.parse('$_jarvisApiUrl${ApiConstants.conversations}');
      
      final requestBody = {
        'title': title.isEmpty ? 'New Chat' : title,
        'assistantModel': 'dify', // Required parameter per API docs
      };
      
      // Add assistant ID if we have a selected model
      if (_selectedModel != null && _selectedModel!.isNotEmpty) {
        requestBody['assistantId'] = _selectedModel!;
      }
      
      // Get headers with token refresh if needed
      final headers = await _getHeaders(forceRefresh: _hasAuthError);
      // Add x-jarvis-guid header
      headers['x-jarvis-guid'] = '';
      
      _logger.i('Creating conversation with URI: $uri');
      _logger.i('Request body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Reset auth error flag on success
        _hasAuthError = false;
        
        final data = jsonDecode(response.body);
        
        return ChatSession(
          id: data['id'] ?? '',
          title: data['title'] ?? 'New Chat',
          createdAt: data['createdAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] * 1000)
              : DateTime.now(),
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _hasAuthError = true;
        
        // Try refreshing the token and retry once
        await _authService.refreshToken();
        
        // Only retry once to avoid infinite loops
        _logger.i('Retrying create conversation with fresh token');
        
        final retryHeaders = await _getHeaders(forceRefresh: true);
        final retryResponse = await http.post(
          uri,
          headers: retryHeaders,
          body: jsonEncode(requestBody),
        );
        
        if (retryResponse.statusCode == 201 || retryResponse.statusCode == 200) {
          _hasAuthError = false;
          final data = jsonDecode(retryResponse.body);
          
          return ChatSession(
            id: data['id'] ?? '',
            title: data['title'] ?? 'New Chat',
            createdAt: data['createdAt'] != null
                ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] * 1000)
                : DateTime.now(),
          );
        }
        
        // If retry also failed, throw error
        throw 'Authentication failed after token refresh';
      } else if (response.statusCode == 404) {
        // API endpoint not found
        _logger.w('Create conversation endpoint not available (404)');
        throw 'API endpoint not available';
      } else {
        _logger.e('Error creating conversation: ${response.body}');
        throw 'Failed to create conversation: ${response.statusCode} ${response.reasonPhrase}';
      }
    } catch (e) {
      _logger.e('Error creating conversation: $e');
      
      // If this is an authentication issue, mark for future requests
      if (e.toString().contains('401') || 
          e.toString().contains('403') || 
          e.toString().contains('Authentication failed')) {
        _hasAuthError = true;
      }
      
      throw 'Failed to create conversation: $e';
    }
  }
  
  /// Check if we have a valid token
  Future<bool> _checkForValidToken() async {
    try {
      final headers = await _getHeaders();
      final hasAuthHeader = headers.containsKey('Authorization') && 
                           headers['Authorization']!.isNotEmpty;
      
      _logger.i('Auth header present: $hasAuthHeader');
      return hasAuthHeader;
    } catch (e) {
      _logger.e('Error checking for token: $e');
      return false;
    }
  }
  
  /// Delete a conversation
  Future<bool> deleteConversation(String conversationId) async {
    try {
      _logger.i('Deleting conversation: $conversationId');
      
      // Use the helper method from constants for the correct path
      final uri = Uri.parse('$_jarvisApiUrl${ApiConstants.conversationMessages(conversationId)}');
      
      final response = await http.delete(
        uri,
        headers: await _getHeaders(),
      );
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      _logger.e('Error deleting conversation: $e');
      return false;
    }
  }
  
  /// Get the available AI models
  Future<List<Map<String, String>>> getAvailableModels() async {
    try {
      _logger.i('Getting available models');
      
      final uri = Uri.parse('$_jarvisApiUrl/api/v1/models');
      
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, String>> models = [];
        
        for (var item in data['items'] ?? []) {
          models.add({
            'id': item['id'] ?? '',
            'name': item['name'] ?? item['id'] ?? 'Unknown Model',
          });
        }
        
        return models;
      } else {
        _logger.e('Error getting models: ${response.body}');
        // Return default models as fallback
        return ApiConstants.modelNames.entries.map((entry) => {
          'id': entry.key,
          'name': entry.value,
        }).toList();
      }
    } catch (e) {
      _logger.e('Error getting models: $e');
      // Return default models as fallback
      return ApiConstants.modelNames.entries.map((entry) => {
        'id': entry.key,
        'name': entry.value,
      }).toList();
    }
  }
  
  /// Set the selected model
  Future<void> setSelectedModel(String modelId) async {
    try {
      _logger.i('Setting selected model: $modelId');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedModel', modelId);
      
      // Update the cached model
      _selectedModel = modelId;
    } catch (e) {
      _logger.e('Error setting selected model: $e');
    }
  }
  
  /// Get the currently selected model
  Future<String?> getSelectedModel() async {
    try {
      // If cached value exists, return it
      if (_selectedModel != null) {
        return _selectedModel;
      }
      
      // Otherwise, try to load from preferences
      final prefs = await SharedPreferences.getInstance();
      final model = prefs.getString('selectedModel');
      
      // Update cached value
      if (model != null && model.isNotEmpty) {
        _selectedModel = model;
      } else {
        // Default to the first model if none is selected
        _selectedModel = ApiConstants.defaultModel;
      }
      
      return _selectedModel;
    } catch (e) {
      _logger.e('Error getting selected model: $e');
      return ApiConstants.defaultModel;
    }
  }
}
