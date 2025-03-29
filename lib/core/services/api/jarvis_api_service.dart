import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/user_model.dart';
import '../../models/chat/chat_session.dart';
import '../../models/chat/message.dart';
import '../../models/prompt/prompt_model.dart';
import '../../models/prompt/prompt_pagination_result.dart'; // Add this import
import '../../constants/api_constants.dart';
import 'api_service.dart';
import 'services/user_service.dart';
import 'services/prompt_service.dart'; // Add import for prompt service
import '../auth/auth_service.dart';
import '../chat/jarvis_chat_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class JarvisApiService implements ApiService {
  static final JarvisApiService _instance = JarvisApiService._internal();
  factory JarvisApiService() => _instance;

  final Logger _logger = Logger();
  
  // Service instances
  late final AuthService _authService;
  late final UserService _userService;
  late final JarvisChatService _chatService;
  late final PromptService _promptService; // Add prompt service
  
  // Configuration variables 
  String? _apiKey;
  bool _isInitialized = false;

  JarvisApiService._internal() {
    _authService = AuthService();
    _userService = UserService(_authService);
    _chatService = JarvisChatService(_authService);
    _promptService = PromptService(_authService); // Initialize prompt service
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Try to load .env but don't fail if it doesn't exist
      try {
        await dotenv.load(fileName: '.env');
        _apiKey = dotenv.env['JARVIS_API_KEY'] ?? ApiConstants.defaultApiKey;
      } catch (e) {
        _logger.w('Could not load .env file: $e. Using default API key.');
        _apiKey = ApiConstants.defaultApiKey;
      }
      
      // Initialize auth service with error handling - remove the parameter
      try {
        await _authService.initialize();
        _logger.i('Auth service initialized successfully');
      } catch (e) {
        _logger.e('Error initializing auth service: $e');
        _logger.i('Will retry initialization on the next API call');
      }
      
      _logger.i('Initialized Jarvis API service with auth, user, and chat services');
      _isInitialized = true;
    } catch (e) {
      _logger.e('Error initializing Jarvis API service: $e');
      // Still mark as initialized to prevent repeated initialization attempts
      _isInitialized = true;
    }
  }

  // Authentication Methods - delegated to AuthService
  
  Future<Map<String, dynamic>> signUp(String email, String password, {String? name}) async {
    await _ensureInitialized();
    return await _authService.signUp(email, password, name: name);
  }

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    await _ensureInitialized();
    return await _authService.signIn(email, password);
  }

  Future<bool> refreshToken() async {
    await _ensureInitialized();
    return await _authService.refreshToken();
  }
  
  Future<bool> forceTokenRefresh() async {
    try {
      _logger.i('Forcing token refresh via API service');
      
      // Check if refresh token is available directly before attempting refresh
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(ApiConstants.refreshTokenKey);
      
      if (refreshToken == null || refreshToken.isEmpty) {
        _logger.w('Cannot force token refresh: No refresh token available in storage');
        return false;
      }

      // Call AuthService directly instead of refreshToken()
      // This avoids circular calls between services
      return await _authService.refreshToken();
    } catch (e) {
      _logger.e('Force token refresh error: $e');
      return false;
    }
  }

  Future<bool> logout() async {
    await _ensureInitialized();
    return await _authService.logout();
  }
  
  bool isAuthenticated() {
    return _authService.isAuthenticated();
  }
  
  String? getUserId() {
    return _authService.getUserId();
  }
  
  Future<bool> verifyTokenValid() async {
    await _ensureInitialized();
    return await _authService.verifyTokenValid();
  }
  
  Future<bool> verifyTokenHasScopes(List<String> requiredScopes) async {
    await _ensureInitialized();
    return await _authService.verifyTokenHasScopes(requiredScopes);
  }

  // User Methods - delegated to UserService
  
  Future<UserModel?> getCurrentUser() async {
    await _ensureInitialized();
    return await _userService.getCurrentUser();
  }

  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    await _ensureInitialized();
    return await _userService.updateUserProfile(data);
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    await _ensureInitialized();
    return await _userService.changePassword(currentPassword, newPassword);
  }
  
  Future<bool> updateUserClientMetadata(Map<String, dynamic> metadata) async {
    await _ensureInitialized();
    return await _userService.updateUserMetadata(metadata, 'client');
  }
  
  Future<bool> updateUserServerMetadata(Map<String, dynamic> metadata) async {
    await _ensureInitialized();
    return await _userService.updateUserMetadata(metadata, 'server');
  }
  
  Future<bool> updateUserClientReadOnlyMetadata(Map<String, dynamic> metadata) async {
    await _ensureInitialized();
    return await _userService.updateUserMetadata(metadata, 'client_read_only');
  }
  
  Future<Map<String, dynamic>?> checkEmailVerificationStatus() async {
    await _ensureInitialized();
    return await _userService.checkEmailVerificationStatus();
  }

  // AI Chat Methods - now delegated to JarvisChatService
  
  Future<List<ChatSession>> getConversations() async {
    await _ensureInitialized();
    return await _chatService.getUserChatSessions();
  }

  Future<List<Message>> getConversationHistory(String conversationId) async {
    await _ensureInitialized();
    return await _chatService.getMessages(conversationId);
  }

  Future<Message> sendMessage(String conversationId, String text) async {
    await _ensureInitialized();
    final result = await _chatService.sendMessage(conversationId, text);
    // Convert response map to Message object
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      metadata: result,
    );
  }

  Future<ChatSession> createConversation(String title) async {
    await _ensureInitialized();
    return await _chatService.createChatSession(title);
  }

  Future<bool> deleteConversation(String conversationId) async {
    await _ensureInitialized();
    return await _chatService.deleteChatSession(conversationId);
  }

  Future<void> setSelectedModel(String modelId) async {
    await _ensureInitialized();
    await _chatService.updateSelectedModel(modelId);
  }

  Future<String?> getSelectedModel() async {
    await _ensureInitialized();
    return await _chatService.getSelectedModel();
  }
  
  Future<List<Map<String, String>>> getAvailableModels() async {
    await _ensureInitialized();
    // Use the hardcoded model list since JarvisChatService doesn't have this method
    return ApiConstants.modelNames.entries.map((entry) => {
      'id': entry.key,
      'name': entry.value,
    }).toList();
  }

  // Prompt operations
  Future<PromptModel?> createPrompt(PromptModel prompt) async {
    await _ensureInitialized();
    return await _promptService.createPrompt(prompt);
  }

  Future<List<PromptModel>> getPrompts({
    String? query,
    String? category,
    bool? isFavorite,
    bool? isPublic,
    bool onlyMine = false,
    int limit = 100,
  }) async {
    await _ensureInitialized();
    return await _promptService.getPrompts(
      query: query,
      category: category,
      isFavorite: isFavorite,
      isPublic: isPublic,
      onlyMine: onlyMine,
      limit: limit,
    );
  }
  
  Future<PromptPaginationResult> getPromptsWithPagination({
    String? query,
    int offset = 0,
    int limit = 20,
    String? category,
    bool? isFavorite,
    bool? isPublic,
    bool onlyMine = false,
  }) async {
    await _ensureInitialized();
    return await _promptService.getPromptsWithPagination(
      query: query,
      offset: offset,
      limit: limit,
      category: category,
      isFavorite: isFavorite,
      isPublic: isPublic,
      onlyMine: onlyMine,
    );
  }
  
  Future<List<PromptModel>> getFavoritePrompts({int limit = 20}) async {
    await _ensureInitialized();
    return await _promptService.getFavoritePrompts(limit: limit);
  }
  
  Future<List<PromptModel>> getMyPrompts({int limit = 20}) async {
    await _ensureInitialized();
    return await _promptService.getMyPrompts(limit: limit);
  }
  
  Future<List<PromptModel>> getPromptsByCategory(String category, {int limit = 20}) async {
    await _ensureInitialized();
    return await _promptService.getPromptsByCategory(category, limit: limit);
  }

  Future<PromptModel?> getPromptById(String id) async {
    await _ensureInitialized();
    return await _promptService.getPromptById(id);
  }

  Future<PromptModel?> updatePrompt(
    String id, 
    PromptModel prompt, {
    bool updateContent = true,
    bool updateTitle = true,
  }) async {
    await _ensureInitialized();
    return await _promptService.updatePrompt(
      id, 
      prompt,
      updateContent: updateContent,
      updateTitle: updateTitle,
    );
  }

  Future<bool> deletePrompt(String id, {int retryCount = 0}) async {
    await _ensureInitialized();
    return await _promptService.deletePrompt(id, retryCount: retryCount);
  }
  
  Future<bool> togglePromptFavorite(String promptId) async {
    await _ensureInitialized();
    return await _promptService.toggleFavorite(promptId);
  }
  
  Future<bool> addPromptToFavorites(String promptId) async {
    await _ensureInitialized();
    return await _promptService.addFavorite(promptId);
  }
  
  Future<bool> removePromptFromFavorites(String promptId) async {
    await _ensureInitialized();
    return await _promptService.removeFavorite(promptId);
  }

  // API Status Methods
  
  @override
  Future<bool> checkApiStatus() async {
    try {
      await _ensureInitialized();
      
      // Use a simpler endpoint for API status check
      final response = await http.get(
        Uri.parse('${ApiConstants.jarvisApiUrl}/api/v1/status'),
        headers: _authService.getHeaders(),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 401;
    } catch (e) {
      _logger.e('API status check failed: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile() async {
    await _ensureInitialized();
    try {
      final user = await _userService.getCurrentUser();
      if (user != null) {
        return {
          'id': user.id,
          'email': user.email,
          'name': user.name,
          'isEmailVerified': user.isEmailVerified
        };
      }
      return null;
    } catch (e) {
      _logger.e('Error getting user profile: $e');
      return null;
    }
  }

  @override
  Map<String, String> getApiConfig() {
    return {
      'authApiUrl': ApiConstants.authApiUrl,
      'jarvisApiUrl': ApiConstants.jarvisApiUrl,
      'knowledgeApiUrl': ApiConstants.knowledgeApiUrl,
      'isAuthenticated': _authService.isAuthenticated() ? 'Yes' : 'No',
      'hasApiKey': _apiKey != null && _apiKey!.isNotEmpty ? 'Yes' : 'No',
    };
  }
  
  @override
  Future<Map<String, dynamic>> get(String endpoint, {bool requiresAuth = true}) async {
    try {
      await _ensureInitialized();
      
      final headers = requiresAuth ? getAuthHeaders() : getHeaders();
      
      final response = await http.get(
        Uri.parse(endpoint),
        headers: headers,
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        _logger.e('API GET error: [${response.statusCode}] ${response.reasonPhrase}');
        throw 'API error: ${response.statusCode} ${response.reasonPhrase}';
      }
    } catch (e) {
      _logger.e('API GET exception: $e');
      rethrow;
    }
  }
  
  @override
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data, {bool requiresAuth = true}) async {
    try {
      await _ensureInitialized();
      
      final headers = requiresAuth ? getAuthHeaders() : getHeaders();
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(data),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        _logger.e('API POST error: [${response.statusCode}] ${response.reasonPhrase}');
        throw 'API error: ${response.statusCode} ${response.reasonPhrase}';
      }
    } catch (e) {
      _logger.e('API POST exception: $e');
      rethrow;
    }
  }
  
  @override
  Map<String, String> getAuthHeaders() {
    return _authService.getAuthHeaders();
  }
  
  @override
  Map<String, String> getHeaders() {
    return _authService.getHeaders();
  }
  
  // Ensure the service is initialized before use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}
