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
  
  AiChatService(this._authService);
  
  /// Get a list of conversations for the current user
  Future<List<ChatSession>> getConversations() async {
    try {
      // Simpler query parameters
      final queryParams = {
        'limit': '100',
      };

      // Add assistantId if we have a selected model, but only for supported models
      if (_selectedModel != null && _selectedModel!.isNotEmpty) {
        // Check if the model is Gemini or Claude, which support conversation history
        if (_selectedModel!.contains('gemini') || _selectedModel!.contains('claude')) {
          queryParams['assistantId'] = _selectedModel!;
        }
      }

      // Ensure we're using the exact endpoint
      final uri = Uri.parse('$_jarvisApiUrl/api/v1/ai-chat/conversations')
          .replace(queryParameters: queryParams);

      _logger.i('Getting conversations: $uri');

      final response = await http.get(
        uri,
        headers: _authService.getHeaders(),
      );

      _logger.d('Conversations response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<ChatSession> conversations = [];

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
        // Check for the specific error about assistant not supporting conversation history
        try {
          final data = jsonDecode(response.body);
          final message = data['message'] ?? '';
          
          if (message.contains('assistant does not support conversation history')) {
            _logger.w('This assistant does not support conversation history. Returning empty list.');
            // This is expected for some models
            return [];
          }
        } catch (e) {
          _logger.e('Error parsing 400 response: $e');
        }
        
        _logger.e('Failed to get conversations: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Error fetching conversations';
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _logger.w('Authentication error (${response.statusCode}) when getting conversations, attempting token refresh');

        final refreshSuccess = await _authService.refreshToken();
        if (refreshSuccess) {
          _logger.i('Token refreshed successfully, retrying get conversations');
          return await getConversations(); // Recursive call after refresh
        }

        _logger.e('Failed to get conversations after token refresh');
        throw 'Authentication failed. Please log in again.';
      } else {
        _logger.e('Failed to get conversations: ${response.statusCode}');
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Error fetching conversations';
      }
    } catch (e) {
      _logger.e('Get conversations error: $e');
      throw e.toString();
    }
  }

  /// Get messages for a specific conversation
  Future<List<Message>> getConversationHistory(String conversationId) async {
    try {
      // Validate conversation ID
      if (conversationId.isEmpty || conversationId.startsWith('local_')) {
        _logger.w('Invalid or local conversation ID: $conversationId');
        return [];
      }

      final queryParams = {
        'assistantModel': 'dify',  // Required parameter per API docs
        'limit': '100',
      };

      // Add assistantId if we have a selected model
      if (_selectedModel != null && _selectedModel!.isNotEmpty) {
        queryParams['assistantId'] = _selectedModel!;
      }

      // Use exact endpoint format from API documentation
      final uri = Uri.parse('$_jarvisApiUrl/api/v1/ai-chat/conversations/$conversationId/messages')
          .replace(queryParameters: queryParams);

      _logger.i('Getting conversation history: $uri');

      final response = await http.get(
        uri,
        headers: _authService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Message> messages = [];

        for (var item in data['items'] ?? []) {
          if (item.containsKey('query')) {
            // This is a user message
            messages.add(Message(
              text: item['query'] ?? '',
              isUser: true,
              timestamp: item['createdAt'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(item['createdAt'] * 1000)
                  : DateTime.now(),
            ));
          }

          if (item.containsKey('answer')) {
            // This is an AI message
            messages.add(Message(
              text: item['answer'] ?? '',
              isUser: false,
              timestamp: item['createdAt'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(item['createdAt'] * 1000)
                  : DateTime.now(),
            ));
          }
        }

        return messages;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _logger.w('Authentication error (${response.statusCode}) when getting conversation history');
        
        // Attempt token refresh
        final refreshSuccess = await _authService.refreshToken();
        if (refreshSuccess) {
          _logger.i('Token refreshed successfully, retrying get conversation history');
          return await getConversationHistory(conversationId); // Recursive call after refresh
        }

        _logger.e('Failed to get conversation history after token refresh');
        throw 'Unauthorized: Token may not have proper scopes for accessing conversation history';
      } else {
        _logger.e('Failed to get conversation history: ${response.statusCode}');
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Error fetching conversation history';
      }
    } catch (e) {
      _logger.e('Get conversation history error: $e');
      throw e.toString();
    }
  }

  /// Send a message in a conversation
  Future<Message> sendMessage(String conversationId, String text) async {
    try {
      _logger.i('Sending message to conversation: $conversationId');

      // Get selected model, default to Gemini 1.5 Flash
      String modelId = _selectedModel ?? 'gemini-1.5-flash-latest';
      String modelName = ApiConstants.modelNames[modelId] ?? 'Gemini 1.5 Flash';

      // Prepare the request body
      final requestBody = {
        'content': text,
        'files': [],
        'metadata': {
          'conversation': {
            'id': conversationId,
            'messages': []  // API handles history
          }
        },
        'assistant': {
          'id': modelId,
          'model': 'dify',
          'name': modelName
        }
      };

      // Use the exact endpoint from the API documentation
      final response = await http.post(
        Uri.parse('$_jarvisApiUrl/api/v1/ai-chat/messages'),
        headers: _authService.getHeaders(),
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _logger.i('Message sent successfully, conversation ID: ${data['conversationId']}');

        return Message(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        );
      } else {
        _logger.e('Failed to send message: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');

        try {
          final errorData = jsonDecode(response.body);
          throw errorData['message'] ?? 'Error sending message';
        } catch (e) {
          throw 'Error sending message: ${response.reasonPhrase}';
        }
      }
    } catch (e) {
      _logger.e('Send message error: $e');
      throw e.toString();
    }
  }

  /// Create a new conversation
  Future<ChatSession> createConversation(String title) async {
    try {
      _logger.i('Creating new conversation with title: $title');

      // Get selected model, default to Gemini 1.5 Flash
      String modelId = _selectedModel ?? 'gemini-1.5-flash-latest';
      String modelName = ApiConstants.modelNames[modelId] ?? 'Gemini 1.5 Flash';

      // Create a new conversation by sending the first message
      const initialMessage = 'Hello'; // Initial message to create conversation

      final requestBody = {
        'content': initialMessage,
        'files': [],
        'metadata': {
          'conversation': {
            'messages': []
          }
        },
        'assistant': {
          'id': modelId,
          'model': 'dify',
          'name': modelName
        }
      };

      // Use the exact endpoint from the API documentation
      final response = await http.post(
        Uri.parse('$_jarvisApiUrl/api/v1/ai-chat/messages'),
        headers: _authService.getHeaders(),
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // Extract conversation ID from response
        final String conversationId = responseData['conversationId'] ?? '';

        if (conversationId.isEmpty) {
          throw 'No conversation ID returned from API';
        }

        return ChatSession(
          id: conversationId,
          title: title.isEmpty ? 'New Chat' : title,
          createdAt: DateTime.now(),
        );
      } else {
        _logger.e('Failed to create conversation: ${response.statusCode}');
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Error creating conversation';
      }
    } catch (e) {
      _logger.e('Create conversation error: $e');
      throw e.toString();
    }
  }

  /// Delete a conversation
  Future<bool> deleteConversation(String conversationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_jarvisApiUrl/api/v1/ai-chat/conversations/$conversationId'),
        headers: _authService.getHeaders(),
      );

      return (response.statusCode == 200 || response.statusCode == 204);
    } catch (e) {
      _logger.e('Delete conversation error: $e');
      return false;
    }
  }

  /// Set the selected model
  Future<void> setSelectedModel(String modelId) async {
    _selectedModel = modelId;

    // Store the selection in preferences for persistence
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedModel', modelId);
      _logger.i('Selected model set to: $modelId');
    } catch (e) {
      _logger.e('Error saving selected model: $e');
    }
  }

  /// Get the selected model
  Future<String?> getSelectedModel() async {
    if (_selectedModel != null) {
      return _selectedModel;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedModel = prefs.getString('selectedModel') ?? ApiConstants.defaultModel;
      return _selectedModel;
    } catch (e) {
      _logger.e('Error getting selected model: $e');
      return ApiConstants.defaultModel;
    }
  }

  /// Get available models
  Future<List<Map<String, String>>> getAvailableModels() async {
    try {
      _logger.i('Getting available AI models');
      
      final response = await http.get(
        Uri.parse('$_jarvisApiUrl${ApiConstants.models}'),
        headers: _authService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, String>> models = [];

        for (var item in data['data'] ?? []) {
          models.add({
            'id': item['id'] ?? '',
            'name': item['name'] ?? item['id'] ?? 'Unknown Model',
          });
        }

        return models;
      } else {
        return ApiConstants.modelNames.entries.map((entry) => {
          'id': entry.key,
          'name': entry.value,
        }).toList();
      }
    } catch (e) {
      _logger.e('Get available models error: $e');
      return ApiConstants.modelNames.entries.map((entry) => {
        'id': entry.key,
        'name': entry.value,
      }).toList();
    }
  }
}
