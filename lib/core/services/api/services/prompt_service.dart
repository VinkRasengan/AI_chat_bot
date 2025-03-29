import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../../../models/prompt/prompt_model.dart';
import '../../../models/prompt/prompt_pagination_result.dart';
import '../../../constants/api_constants.dart';
import '../../auth/auth_service.dart';

/// Service for prompt-related operations
class PromptService {
  final Logger _logger = Logger();
  final AuthService _authService;
  
  /// Valid prompt categories according to API documentation
  static const List<String> validCategories = [
    'business', 'career', 'chatbot', 'coding', 'education',
    'fun', 'marketing', 'productivity', 'seo', 'writing', 'other'
  ];
  
  PromptService(this._authService);
  
  /// Create a new prompt
  Future<PromptModel?> createPrompt(PromptModel prompt) async {
    try {
      _logger.i('Creating new prompt: ${prompt.title}');
      
      final headers = _authService.getHeaders();
      headers['x-jarvis-guid'] = '';
      
      final response = await http.post(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.prompts}'),
        headers: headers,
        body: jsonEncode(prompt.toRequestBody()),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _logger.i('Prompt created successfully: ${data['_id']}');
        return PromptModel.fromMap(data);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to refresh token and retry
        final refreshed = await _authService.refreshToken();
        
        if (refreshed) {
          return await createPrompt(prompt);
        } else {
          _logger.w('Failed to refresh token, cannot create prompt');
          return null;
        }
      } else {
        _logger.e('Error creating prompt: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Error creating prompt: $e');
      return null;
    }
  }
  
  /// Get a list of prompts with advanced filtering and pagination
  /// 
  /// Parameters:
  /// - query: Optional search keyword
  /// - offset: Pagination offset (default: 0)
  /// - limit: Number of items per page (default: 20)
  /// - category: Filter by prompt category
  /// - isFavorite: Filter by favorite status
  /// - isPublic: Filter by public status
  /// - onlyMine: Show only user's own prompts
  Future<PromptPaginationResult> getPromptsWithPagination({
    String? query,
    int offset = 0,
    int limit = 20,
    String? category,
    bool? isFavorite,
    bool? isPublic,
    bool onlyMine = false,
  }) async {
    try {
      _logger.i('Getting prompts list with pagination');
      
      // Build query parameters
      final queryParams = <String, String>{
        'offset': offset.toString(),
        'limit': limit.toString(),
      };
      
      // Add optional filters if provided
      if (query != null && query.isNotEmpty) {
        queryParams['query'] = query;
      }
      
      if (category != null && validCategories.contains(category)) {
        queryParams['category'] = category;
      }
      
      if (isFavorite != null) {
        queryParams['isFavorite'] = isFavorite.toString();
      }
      
      if (isPublic != null) {
        queryParams['isPublic'] = isPublic.toString();
      }
      
      if (onlyMine) {
        queryParams['owner'] = 'me';
      }
      
      final uri = Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.prompts}')
          .replace(queryParameters: queryParams);
      
      _logger.d('GET prompts URI: ${uri.toString()}');
      
      final headers = _authService.getHeaders();
      headers['x-jarvis-guid'] = '';
      
      final response = await http.get(
        uri,
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Parse paginated response
        return PromptPaginationResult.fromMap(data);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to refresh token and retry
        final refreshed = await _authService.refreshToken();
        
        if (refreshed) {
          return await getPromptsWithPagination(
            query: query,
            offset: offset,
            limit: limit,
            category: category,
            isFavorite: isFavorite,
            isPublic: isPublic,
            onlyMine: onlyMine,
          );
        } else {
          _logger.w('Failed to refresh token, returning empty result');
          return PromptPaginationResult(
            hasNext: false,
            offset: offset,
            limit: limit,
            total: 0,
            items: [],
          );
        }
      } else {
        _logger.e('Error getting prompts: ${response.statusCode}');
        return PromptPaginationResult(
          hasNext: false,
          offset: offset,
          limit: limit,
          total: 0,
          items: [],
        );
      }
    } catch (e) {
      _logger.e('Error getting prompts with pagination: $e');
      return PromptPaginationResult(
        hasNext: false,
        offset: offset,
        limit: limit,
        total: 0,
        items: [],
      );
    }
  }
  
  /// Get a list of prompts (legacy method, extracts items from pagination result)
  Future<List<PromptModel>> getPrompts({
    String? query,
    String? category,
    bool? isFavorite,
    bool? isPublic,
    bool onlyMine = false,
    int limit = 100,
  }) async {
    try {
      final result = await getPromptsWithPagination(
        query: query,
        category: category,
        isFavorite: isFavorite,
        isPublic: isPublic,
        onlyMine: onlyMine,
        limit: limit,
      );
      
      return result.items;
    } catch (e) {
      _logger.e('Error getting prompts: $e');
      return [];
    }
  }
  
  /// Get favorite prompts
  Future<List<PromptModel>> getFavoritePrompts({int limit = 20}) async {
    return getPrompts(isFavorite: true, limit: limit);
  }
  
  /// Get user's own prompts
  Future<List<PromptModel>> getMyPrompts({int limit = 20}) async {
    return getPrompts(onlyMine: true, limit: limit);
  }
  
  /// Get prompts by category
  Future<List<PromptModel>> getPromptsByCategory(String category, {int limit = 20}) async {
    if (!validCategories.contains(category)) {
      _logger.w('Invalid category: $category');
      return [];
    }
    
    return getPrompts(category: category, limit: limit);
  }
  
  /// Get a specific prompt by ID
  Future<PromptModel?> getPromptById(String id) async {
    try {
      _logger.i('Getting prompt by ID: $id');
      
      final headers = _authService.getHeaders();
      headers['x-jarvis-guid'] = '';
      
      final response = await http.get(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.prompts}/$id'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PromptModel.fromMap(data);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to refresh token and retry
        final refreshed = await _authService.refreshToken();
        
        if (refreshed) {
          return await getPromptById(id);
        } else {
          _logger.w('Failed to refresh token, cannot get prompt');
          return null;
        }
      } else {
        _logger.e('Error getting prompt: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Error getting prompt: $e');
      return null;
    }
  }
  
  /// Update an existing prompt
  Future<PromptModel?> updatePrompt(String id, PromptModel prompt, {
    bool updateContent = true,
    bool updateTitle = true,
  }) async {
    try {
      _logger.i('Updating prompt: $id');
      
      // Validate required fields
      if (prompt.description.isEmpty) {
        _logger.e('Cannot update prompt: description is required');
        return null;
      }
      
      final headers = _authService.getHeaders();
      headers['x-jarvis-guid'] = '';
      
      // Use the new toUpdateRequestBody method to ensure correct fields
      final requestBody = prompt.toUpdateRequestBody(
        includeContent: updateContent,
        includeTitle: updateTitle,
      );
      
      _logger.d('Update prompt request body: $requestBody');
      
      final response = await http.patch(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.prompts}/$id'),
        headers: headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        _logger.i('Prompt updated successfully');
        final data = jsonDecode(response.body);
        return PromptModel.fromMap(data);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to refresh token and retry
        final refreshed = await _authService.refreshToken();
        
        if (refreshed) {
          return await updatePrompt(id, prompt, 
            updateContent: updateContent, 
            updateTitle: updateTitle
          );
        } else {
          _logger.w('Failed to refresh token, cannot update prompt');
          return null;
        }
      } else {
        _logger.e('Error updating prompt: ${response.statusCode} ${response.body}');
        // Try to parse error response for more details
        try {
          final errorData = jsonDecode(response.body);
          _logger.e('Error details: $errorData');
        } catch (_) {}
        return null;
      }
    } catch (e) {
      _logger.e('Error updating prompt: $e');
      return null;
    }
  }
  
  /// Delete a prompt
  Future<bool> deletePrompt(String id, {int retryCount = 0}) async {
    try {
      _logger.i('Deleting prompt: $id');
      
      final headers = _authService.getHeaders();
      headers['x-jarvis-guid'] = '';
      
      final response = await http.delete(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.prompts}/$id'),
        headers: headers,
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        _logger.i('Prompt deleted successfully');
        return true;
      } else if ((response.statusCode == 401 || response.statusCode == 403) && retryCount < 1) {
        // Try to refresh token and retry once
        _logger.w('Authorization error (${response.statusCode}), attempting to refresh token');
        final refreshed = await _authService.refreshToken();
        
        if (refreshed) {
          _logger.i('Token refreshed, retrying prompt deletion');
          return await deletePrompt(id, retryCount: retryCount + 1);
        } else {
          _logger.w('Failed to refresh token, cannot delete prompt');
          return false;
        }
      } else {
        // Log detailed error information
        _logger.e('Error deleting prompt: ${response.statusCode} ${response.reasonPhrase}');
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            _logger.e('Error details: $errorData');
          }
        } catch (e) {
          // Ignore JSON parsing errors
        }
        return false;
      }
    } catch (e) {
      _logger.e('Error deleting prompt: $e');
      return false;
    }
  }
  
  /// Toggle favorite status for a prompt
  Future<bool> toggleFavorite(String promptId) async {
    try {
      _logger.i('Toggling favorite status for prompt: $promptId');
      
      final headers = _authService.getHeaders();
      headers['x-jarvis-guid'] = '';
      
      final response = await http.post(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.prompts}/$promptId/favorite'),
        headers: headers,
      );
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      _logger.e('Error toggling favorite status: $e');
      return false;
    }
  }
  
  /// Add a prompt to favorites
  Future<bool> addFavorite(String promptId) async {
    try {
      _logger.i('Adding prompt to favorites: $promptId');
      
      final headers = _authService.getHeaders();
      headers['x-jarvis-guid'] = '';
      
      final response = await http.post(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.prompts}/$promptId/favorite'),
        headers: headers,
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        _logger.i('Prompt added to favorites successfully');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to refresh token and retry
        final refreshed = await _authService.refreshToken();
        
        if (refreshed) {
          return await addFavorite(promptId);
        } else {
          _logger.w('Failed to refresh token, cannot add to favorites');
          return false;
        }
      } else {
        _logger.e('Error adding prompt to favorites: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Error adding prompt to favorites: $e');
      return false;
    }
  }
  
  /// Remove a prompt from favorites
  Future<bool> removeFavorite(String promptId) async {
    try {
      _logger.i('Removing prompt from favorites: $promptId');
      
      final headers = _authService.getHeaders();
      headers['x-jarvis-guid'] = '';
      
      final response = await http.delete(
        Uri.parse('${ApiConstants.jarvisApiUrl}${ApiConstants.prompts}/$promptId/favorite'),
        headers: headers,
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        _logger.i('Prompt removed from favorites successfully');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to refresh token and retry
        final refreshed = await _authService.refreshToken();
        
        if (refreshed) {
          return await removeFavorite(promptId);
        } else {
          _logger.w('Failed to refresh token, cannot remove from favorites');
          return false;
        }
      } else {
        _logger.e('Error removing prompt from favorites: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Error removing prompt from favorites: $e');
      return false;
    }
  }
}
