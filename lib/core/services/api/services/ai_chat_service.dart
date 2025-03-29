import 'package:logger/logger.dart';
import '../../../models/chat/chat_session.dart';
import '../../../models/chat/message.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/chat/jarvis_chat_service.dart';

/// Service for AI chat operations - now just a wrapper for JarvisChatService
/// @deprecated Use JarvisChatService directly instead
class AiChatService {
  final Logger _logger = Logger();
  final JarvisChatService _chatService;
  
  AiChatService(AuthService authService) : 
    _chatService = JarvisChatService(authService) {
    _logger.w('AiChatService is deprecated. Use JarvisChatService directly.');
  }
  
  /// Get a list of conversations for the current user
  Future<List<ChatSession>> getConversations() => _chatService.getUserChatSessions();
  
  /// Get conversation history/messages for a specific conversation
  Future<List<Message>> getConversationHistory(String conversationId) => 
      _chatService.getMessages(conversationId);
  
  /// Send a message to a conversation
  Future<Message> sendMessage(String conversationId, String text) async {
    final result = await _chatService.sendMessage(conversationId, text);
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      metadata: result,
    );
  }
  
  /// Create a new conversation
  Future<ChatSession> createConversation(String title) => 
      _chatService.createChatSession(title);
  
  /// Delete a conversation
  Future<bool> deleteConversation(String conversationId) => 
      _chatService.deleteChatSession(conversationId);
  
  /// Set the selected model
  Future<void> setSelectedModel(String modelId) => 
      _chatService.updateSelectedModel(modelId);
  
  /// Get the currently selected model
  Future<String?> getSelectedModel() => _chatService.getSelectedModel();
}
