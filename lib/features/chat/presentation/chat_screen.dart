import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../../core/services/auth/auth_service.dart';
import '../../../core/services/analytics/analytics_service.dart';
import '../services/chat_service.dart';
import '../models/conversation_message.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/bot/services/bot_service.dart';
import '../analytics/chat_analytics.dart';
import '../../../features/prompt/presentation/prompt_selector.dart';
import '../../../features/subscription/widgets/ad_banner_widget.dart';
import '../../../features/subscription/services/ad_manager.dart';
import '../../../features/subscription/services/subscription_service.dart';
import '../../../widgets/typing_indicator.dart';
import '../../../widgets/information.dart'
    show
        SnackBarVariant,
        GlobalSnackBar,
        InformationVariant,
        InformationIndicator;
import 'assistant_selector.dart';
import 'chat_history_drawer.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  // ===== SERVICES =====
  final ChatService _chatService = ChatService();
  final BotService _botService = BotService();
  final SubscriptionService _subscriptionService = SubscriptionService(
    AuthService(),
    Logger(),
  );
  final AdManager _adManager = AdManager();
  final Logger _logger = Logger();
  final AnalyticsService _analytics = AnalyticsService();
  // Chat-specific analytics helper
  late final ChatAnalytics _chatAnalytics;

  // ===== STATE VARIABLES =====
  // Conversation state
  bool _isLoading = true;
  bool _isPro = false;
  bool _isSending = false;
  bool _isTyping = false;
  bool _showPromptSelector = false;
  String _errorMessage = '';
  List<ConversationMessage> _messages = [];
  String? _currentConversationId;
  String _selectedAssistantId = 'gpt-4o';

  // ===== CONTROLLERS =====
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _sendButtonController;  @override
  void initState() {
    super.initState();
    
    // Initialize chat analytics helper
    _chatAnalytics = ChatAnalytics(_analytics);
    
    // Clear the chat cache to ensure we're not showing a previous user's conversations
    _chatService.clearCache();
    
    _fetchConversationHistory();
    _checkSubscriptionStatus();

    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Listen for changes in the message text to detect slash commands
    _messageController.addListener(_handleMessageChanged);
    
    // Log screen view for analytics
    _analytics.logScreenView(
      screenName: 'ChatScreen',
      screenClass: 'ChatScreen',
    );
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _sendButtonController.dispose();
    super.dispose();
  }

  // ===== SUBSCRIPTION & INITIALIZATION METHODS =====
  
  Future<void> _checkSubscriptionStatus() async {
    try {
      final subscription = await _subscriptionService.getCurrentSubscription();
      setState(() {
        _isPro = subscription.isPro;
      });
    } catch (e) {
      _logger.e('Error checking subscription status: $e');
      setState(() {
        _isPro = false; // Default to free user if error
      });
    }
  }

  void _navigateToSubscriptionScreen() async {
    const String pricingUrl = 'https://dev.jarvis.cx/pricing';

    try {
      _logger.i('Opening pricing page: $pricingUrl');

      // Launch the pricing URL in the browser
      final Uri url = Uri.parse(pricingUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Unable to open subscription upgrade page';
      }
    } catch (e) {
      _logger.e('Error opening pricing page: $e');

      // Use the safe method that handles mounted check internally
      GlobalSnackBar.showSafe(
        this,
        message: 'Unable to open upgrade page: $e',
        variant: SnackBarVariant.error,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _handleInsufficientTokensError() {
    if (!mounted) return;

    // Remove the last message that was just sent
    setState(() {
      if (_messages.isNotEmpty) {
        // Remove the last message completely
        _messages.removeLast();
      }
      _isSending = false;
      _isTyping = false;
      _sendButtonController.reverse();
    });

    // Show a detailed error with an action to upgrade
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalSnackBar.show(
        context: context,
        message:
            'You have run out of tokens. Please upgrade your subscription to continue using the AI chat.',
        variant: SnackBarVariant.error,
        duration: const Duration(seconds: 10),
        actionLabel: 'Upgrade',        onActionPressed: () {
          // Navigate to subscription screen
          _navigateToSubscriptionScreen();
          
          // Track subscription event in analytics
          _analytics.logSubscriptionEvent(
            action: 'upgrade_button_clicked',
            plan: 'from_insufficient_tokens',
          );
          
          _logger.i(
              'User clicked upgrade button after seeing insufficient tokens error');
        },
      );
    });
  }

  // ===== CONVERSATION HISTORY METHODS =====
  
  Future<void> _fetchConversationHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Use the shared method from ChatHistoryDrawer to fetch conversation history
        final messages = await ChatHistoryDrawer.fetchConversationHistory(
          _currentConversationId,
          _selectedAssistantId,
          logger: _logger,
        );

        // If the result is empty and we had no prior conversation ID, that's normal for a new user
        if (messages.isEmpty && _currentConversationId == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Update state with the conversation messages
        if (mounted) {
          setState(() {
            _messages = messages;
            _isLoading = false;

            // The conversation ID might have been updated in the fetch method if it was null
            if (messages.isNotEmpty && _currentConversationId == null) {
              // We need to get the latest conversation ID from the service
              _chatService
                  .getConversations(
                assistantId: _selectedAssistantId,
                limit: 1,
              )
                  .then((conversations) {
                if (conversations.isNotEmpty) {
                  setState(() {
                    _currentConversationId = conversations.first['id'];
                  });
                }
              });
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });

          _logger.e('Error fetching conversations: $e');
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });

        _logger.e('Error in _fetchConversationHistory: $e');

        GlobalSnackBar.show(
          context: context,
          message: 'Unable to load conversations: ${e.toString()}',
          variant: SnackBarVariant.error,
          duration: const Duration(seconds: 5),
          actionLabel: _currentConversationId != null ? 'New Chat' : null,
          onActionPressed: _currentConversationId != null
              ? () {
                  setState(() {
                    _currentConversationId = null;
                    _messages = [];
                  });
                  GlobalSnackBar.hideCurrent(context);
                }
              : null,
        );
      }
    }
  }
  Future<void> _loadConversation(String conversationId) async {
    // Track conversation load time
    final startTime = DateTime.now().millisecondsSinceEpoch;
    bool isSuccess = false;
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Use the shared method from ChatHistoryDrawer to fetch history for a specific conversation
      final messages = await ChatHistoryDrawer.fetchConversationHistory(
        conversationId,
        _selectedAssistantId,
        logger: _logger,
      );

      if (mounted) {
        setState(() {
          _currentConversationId = conversationId;
          _messages = messages;
          _isLoading = false;
        });
        isSuccess = true;      }
    } catch (e) {
      _logger.e('Error loading conversation: $e');
      isSuccess = false;

      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load conversation: $e';
          _isLoading = false;
        });

        GlobalSnackBar.show(
          context: context,
          message: 'Error loading conversation: $e',
          variant: SnackBarVariant.error,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      // Log conversation load performance
      final loadTime = DateTime.now().millisecondsSinceEpoch - startTime;
      _chatAnalytics.logConversationLoadTime(
        loadTimeMs: loadTime,
        modelId: _selectedAssistantId,
        isSuccessful: isSuccess,
      );
    }
  }

  // ===== MESSAGING & TEXT INPUT METHODS =====
  
  void _handleMessageChanged() {
    final text = _messageController.text;

    // Check if text starts with a slash and show the prompt selector dialog
    if (text.startsWith('/') && !_showPromptSelector) {
      setState(() {
        _showPromptSelector = true;
      });

      // Show the dialog and reset flag when closed
      PromptSelector.show(context, text, _handlePromptSelected).then((_) {
        setState(() {
          _showPromptSelector = false;
        });
      });
    }
  }
  void _handlePromptSelected(String content) {
    setState(() {
      _messageController.text = content;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: content.length),
      );
    });

    // Track prompt usage in analytics
    _chatAnalytics.logPromptInteraction(
      promptAction: 'selected',
      promptText: content,
    );

    // Focus on the text field
    _messageFocusNode.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getModelDisplayName(String modelId) {
    // Find the model in our assistants list
    // Create an instance since it's no longer a private class
    final assistantState = AssistantSelectorState();
    for (var assistant in assistantState.assistants) {
      if (assistant.id == modelId) {
        return assistant.name;
      }
    }

    // Fallback if not found - just format the ID nicely
    return modelId.toUpperCase().replaceAll('-', ' ');
  }

  // ===== MESSAGE SENDING METHODS =====
  
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Hide keyboard when sending a message
    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
      _isTyping = true;
      _sendButtonController.forward();
    });

    try {
      _messageController.clear();

      final userMessage = ConversationMessage(
        query: message,
        answer: '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        files: [],
      );

      setState(() {
        _messages = [..._messages, userMessage];
      });

      // Scroll to bottom after adding user message
      _scrollToBottom();

      // Check if this is a new conversation
      if (_currentConversationId == null) {
        _logger.i(
            'No conversation ID found - creating a new conversation automatically');
      }

      // Check if we're using a custom bot
      bool isCustomBot = false;
      // Create an instance since it's no longer a private class
      final assistantState = AssistantSelectorState();
      for (final assistant in assistantState.assistants) {
        if (assistant.id == _selectedAssistantId && assistant.isCustomBot) {
          isCustomBot = true;
          break;
        }
      }

      _logger.i(
          'Sending message to ${isCustomBot ? "custom bot" : "AI model"}: $_selectedAssistantId');

      if (isCustomBot) {
        await _sendMessageToCustomBot(message);
      } else {
        await _sendMessageToAIModel(message);
      }
    } catch (e) {
      _handleGenericSendError(e, message);
    }
  }
  Future<void> _sendMessageToCustomBot(String message) async {
    try {      // Log message sent to analytics
      _chatAnalytics.logMessageSent(
        modelId: _selectedAssistantId,
        isCustomBot: true,
        conversationId: _currentConversationId,
        message: message,
      );
      
      // Set typing indicator to true
      setState(() {
        _isTyping = true;
      });
      
      final botResponse = await _botService.askBot(
        botId: _selectedAssistantId,
        message: message,
      );

      _logger.i('Received bot response');

      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty) {
            _messages[_messages.length - 1] = ConversationMessage(
              query: message,
              answer: botResponse,
              createdAt: _messages[_messages.length - 1].createdAt,
              files: [],
            );
          }
          _isSending = false;
          _isTyping = false;
          _sendButtonController.reverse();
        });

        // Show an ad occasionally for free users
        if (!_isPro) {
          _adManager.maybeShowInterstitialAd(context);
        }
      }
    } catch (e) {
      _logger.e('Error sending message to custom bot: $e');
        // Log error to analytics
      _chatAnalytics.logMessageError(
        errorType: 'custom_bot_error',
        errorMessage: e.toString(),
        modelId: _selectedAssistantId,
        conversationId: _currentConversationId,
      );

      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty) {
            _messages[_messages.length - 1] = ConversationMessage(
              query: message,
              answer: 'Error: ${e.toString()}',
              createdAt: _messages[_messages.length - 1].createdAt,
              files: [],
            );
          }
          _isSending = false;
          _isTyping = false;
          _sendButtonController.reverse();
        });

        // Show error message
        GlobalSnackBar.show(
          context: context,
          message: 'Error with bot: ${e.toString()}',
          variant: SnackBarVariant.error,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }
  Future<void> _sendMessageToAIModel(String message) async {
    _logger.i('Sending message with conversation ID: $_currentConversationId');
      // Log message sent event for analytics
    _chatAnalytics.logMessageSent(
      modelId: _selectedAssistantId,
      isCustomBot: false,
      conversationId: _currentConversationId,
      message: message,
    );

    // Set typing indicator to true
    setState(() {
      _isTyping = true;
    });

    // Always send message - conversation ID will be null for new conversations
    // which will automatically create a new conversation on the server
    Map<String, dynamic> response;
    try {
      response = await _chatService.sendMessage(
        content: message,
        assistantId: _selectedAssistantId,
        conversationId: _currentConversationId,
      );

      _logger.i('Received response: ${jsonEncode(response)}');
      _handleSuccessfulAIResponse(response, message);
    } catch (e) {
      _logger.e('Error sending message (first attempt): $e');
        // Log error to analytics
      _chatAnalytics.logMessageError(
        errorType: 'ai_model_error',
        errorMessage: e.toString(),
        modelId: _selectedAssistantId,
        conversationId: _currentConversationId,
      );

      // Check for token-related errors
      if (e.toString().toLowerCase().contains('insufficient') ||
          e.toString().toLowerCase().contains('token') ||
          e.toString().toLowerCase().contains('quota') ||
          e.toString().toLowerCase().contains('limit')) {
        // Handle insufficient tokens error
        _handleInsufficientTokensError();
        return;
      }

      // If the message fails, try to create a new conversation
      if (_currentConversationId != null) {
        await _retryWithNewConversation(message);
      } else {
        // For new conversations that fail on first attempt
        if (mounted) {
          setState(() {
            if (_messages.isNotEmpty) {
              _messages[_messages.length - 1] = ConversationMessage(
                query: message,
                answer: 'Error: ${e.toString()}',
                createdAt: _messages[_messages.length - 1].createdAt,
                files: [],
              );
            }
            _isSending = false;
            _isTyping = false;
            _sendButtonController.reverse();
          });
        }
      }
    }
  }

  Future<void> _retryWithNewConversation(String message) async {
    try {
      _currentConversationId = null;
      final response = await _chatService.sendMessage(
        content: message,
        assistantId: _selectedAssistantId,
        conversationId: null, // Force creating a new conversation
      );

      _logger.i('Retry successful, received response: ${jsonEncode(response)}');
      _handleSuccessfulAIResponse(response, message);
    } catch (e2) {
      _logger.e('Error sending message (retry attempt): $e2');

      // Check if this is also a token error
      if (e2.toString().toLowerCase().contains('insufficient') ||
          e2.toString().toLowerCase().contains('token') ||
          e2.toString().contains('quota') ||
          e2.toString().contains('limit')) {
        // Handle insufficient tokens error
        _handleInsufficientTokensError();
        return;
      }

      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty) {
            _messages[_messages.length - 1] = ConversationMessage(
              query: message,
              answer: 'Error: ${e2.toString()}',
              createdAt: _messages[_messages.length - 1].createdAt,
              files: [],
            );
          }
          _isSending = false;
          _isTyping = false;
          _sendButtonController.reverse();
        });
      }
    }
  }

  void _handleSuccessfulAIResponse(Map<String, dynamic> response, String message) {
    if (!mounted) return;
    
    String answer = '';
    String? newConversationId = _currentConversationId;
    int? remainingUsage;

    // Extract conversation ID from different possible locations in response
    if (response.containsKey('conversation_id')) {
      newConversationId = response['conversation_id'];
    }

    // Get remaining usage if available
    if (response.containsKey('remaining_usage')) {
      remainingUsage = response['remaining_usage'];
      _logger.i('Remaining tokens: $remainingUsage');

      // If tokens are running low, show a warning
      if (remainingUsage != null && remainingUsage < 10) {
        // Show a warning once the message is processed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            GlobalSnackBar.show(
              context: context,
              message:
                  'You are running low on tokens. Your remaining usage: $remainingUsage tokens.',
              variant: SnackBarVariant.warning,
              duration: const Duration(seconds: 5),
              actionLabel: 'Upgrade',
              onActionPressed: () {
                // Navigate to subscription screen
                _navigateToSubscriptionScreen();
                _logger.i(
                    'User clicked upgrade button from low tokens warning');
              },
            );
          }
        });
      }
    }

    // Update conversation ID if we got a new one
    if (newConversationId != null &&
        (_currentConversationId == null ||
            _currentConversationId != newConversationId)) {
      _currentConversationId = newConversationId;
      _logger.i('Updated conversation ID to: $_currentConversationId');

      // Clear the conversation cache to ensure the drawer shows the new conversation
      _chatService.clearCache();
    }

    // Extract answer text
    if (response.containsKey('answers') &&
        response['answers'] is List &&
        (response['answers'] as List).isNotEmpty) {
      answer = (response['answers'] as List<dynamic>).first.toString();
    }

    setState(() {
      if (_messages.isNotEmpty) {
        _messages[_messages.length - 1] = ConversationMessage(
          query: message,
          answer: answer,
          createdAt: _messages[_messages.length - 1].createdAt,
          files: [],
        );
      }
      _isSending = false;
      _isTyping = false;
      _sendButtonController.reverse();
    });

    // Scroll to bottom after receiving AI response
    _scrollToBottom();

    // Show an ad occasionally for free users
    if (!_isPro) {
      _adManager.maybeShowInterstitialAd(context);
    }
  }

  void _handleGenericSendError(dynamic e, String message) {
    _logger.e('Error sending message: $e');

    String errorMessage = e.toString();

    // Check if the error might be related to conversation ID issues
    if (errorMessage.contains('500') ||
        errorMessage.contains('conversation') ||
        errorMessage.contains('context')) {
      // Reset conversation ID to force starting a new conversation next time
      _currentConversationId = null;
      errorMessage =
          'Error with conversation. Starting a new chat on next message.';
      _logger.i('Reset conversation ID due to error');
    }

    // Check for token-related errors
    else if (errorMessage.toLowerCase().contains('insufficient') ||
        errorMessage.toLowerCase().contains('token') ||
        errorMessage.toLowerCase().contains('quota') ||
        errorMessage.toLowerCase().contains('limit')) {
      // Handle insufficient tokens error
      _handleInsufficientTokensError();
      return;
    }

    setState(() {
      if (_messages.isNotEmpty) {
        _messages[_messages.length - 1] = ConversationMessage(
          query: message,
          answer: 'Error: $errorMessage',
          createdAt: _messages[_messages.length - 1].createdAt,
          files: [],
        );
      }
      _isSending = false;
      _isTyping = false;
      _sendButtonController.reverse();
    });

    // Use the safe method that handles mounted check internally
    GlobalSnackBar.showSafe(
      this,
      message: 'Error sending message: $errorMessage',
      variant: SnackBarVariant.error,
      duration: const Duration(seconds: 5),
      actionLabel: _currentConversationId != null ? 'New Chat' : null,
      onActionPressed: _currentConversationId != null
          ? () {
              setState(() {
                _currentConversationId = null;
                _messages = [];
              });
              GlobalSnackBar.hideCurrent(context);
            }
          : null,
    );
  }

  // ===== UI BUILDING METHODS =====
  
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final colors = isDarkMode ? AppColors.dark : AppColors.light;

    return Scaffold(
      drawer: _buildChatHistoryDrawer(theme, isDarkMode),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: Icon(Icons.menu, color: colors.foreground.withAlpha(204)),
              tooltip: 'Chat History',
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
        ),
        title: AssistantSelector(
          selectedAssistantId: _selectedAssistantId,          onSelect: (id) {
            if (id != _selectedAssistantId) {
              _logger.i('Switching model from $_selectedAssistantId to $id');
                // Track model change in analytics
              _chatAnalytics.logModelSwitched(
                fromModel: _selectedAssistantId,
                toModel: id,
              );
              
              setState(() {
                _selectedAssistantId = id;

                // Reset conversation ID when changing models to avoid thinking state problems
                _currentConversationId = null;

                // Remove any messages with empty answers that might be in the typing state
                _messages = _messages
                    .where((message) => message.answer.isNotEmpty)
                    .toList();

                // Reset loading states
                _isSending = false;
                _isTyping = false;
                _sendButtonController.reverse();
              });

              // Show a small confirmation
              GlobalSnackBar.show(
                context: context,
                message: 'Switched to ${_getModelDisplayName(id)}',
                variant: SnackBarVariant.info,
                duration: const Duration(seconds: 1),
              );
            }
          },
        ),
        centerTitle: true,
        actions: [
          // New chat button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: Icon(
                Icons.edit_document,
                color: colors.foreground.withAlpha(204),
              ),
              tooltip: 'New conversation',              onPressed: () {
                setState(() {
                  _currentConversationId = null;
                  _messages = [];
                });
                
                // Track new chat creation
                _chatAnalytics.logNewChat(modelId: _selectedAssistantId);
              },
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Show ad banner for free users
            if (!_isPro) const AdBannerWidget(),

            _buildChatMessages(theme, colors),

            _buildMessageInputArea(theme, isDarkMode, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHistoryDrawer(ThemeData theme, bool isDarkMode) {
    return ChatHistoryDrawer(
      selectedAssistantId: _selectedAssistantId,
      currentConversationId: _currentConversationId,
      onNewChat: () {
        setState(() {
          _currentConversationId = null;
          _messages = [];
        });
      },
      onConversationSelected: (conversationId) {
        _loadConversation(conversationId);
        Navigator.pop(context); // Close the drawer
      },
      onDeleteConversation: (conversationId) {
        // This will be handled inside the ChatHistoryDrawer
      },
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildChatMessages(ThemeData theme, dynamic colors) {
    if (_isLoading) {
      return Expanded(
        child: InformationIndicator(
          variant: InformationVariant.loading,
        ),
      );
    }

    if (_errorMessage.isNotEmpty && _messages.isEmpty) {
      return Expanded(
        child: InformationIndicator(
          variant: InformationVariant.error,
          message: _errorMessage,
          buttonText: 'Retry',
          onButtonPressed: _fetchConversationHistory,
        ),
      );
    }

    if (_messages.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 64,
                color: colors.muted.withAlpha(128),
              ),
              const SizedBox(height: 20),
              if (!_isPro)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Free users have limited messages. Upgrade for unlimited access.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        reverse: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final isUserMessage = message.query.isNotEmpty;
          final messageText = isUserMessage ? message.query : message.answer;

          // Display both query and answer for each message
          if (isUserMessage) {
            return Padding(
              // Add padding to the bottom of the message
              padding: const EdgeInsets.only(bottom: 28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User question bubble
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(13),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SelectableText(
                            message.query,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // AI answer - simplified, no bubble UI
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Only hide the answer if this is the last message and we're currently typing
                        if (!(_isTyping && index == _messages.length - 1)) ...[
                          MarkdownBody(
                            data: message.answer,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                                color: theme.colorScheme.onSurface,
                              ),
                              h1: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              h2: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              h3: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              listBullet: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.muted,
                                height: 1.5,
                              ),
                              blockquote: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(204),
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: theme.colorScheme.primary.withAlpha(128),
                                    width: 4.0,
                                  ),
                                ),
                              ),
                              blockquotePadding: const EdgeInsets.only(left: 16.0),
                              code: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                                color: theme.colorScheme.onSurface,
                                backgroundColor: colors.input,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: colors.input,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              codeblockPadding: const EdgeInsets.all(8.0),
                              tableHead: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              tableBody: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                              tableBorder: TableBorder.all(
                                color: theme.colorScheme.outline.withAlpha(128),
                                width: 1.0,
                              ),
                              tableCellsPadding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              a: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                              listIndent: 24.0,
                              orderedListAlign: WrapAlignment.start,
                              unorderedListAlign: WrapAlignment.start,
                            ),
                            onTapLink: (text, href, title) {
                              if (href != null) {
                                launchUrl(Uri.parse(href), 
                                  mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                          if (message.answer.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                icon: Icon(
                                  Icons.copy,
                                  size: 18,
                                  color: colors.muted,
                                ),
                                tooltip: 'Copy to clipboard',
                                padding: const EdgeInsets.only(left: 0),
                                visualDensity: const VisualDensity(
                                    horizontal: -4.0, vertical: 0),
                                onPressed: () {
                                  // Copy message to clipboard
                                  Clipboard.setData(
                                      ClipboardData(text: message.answer));

                                  // Show a snackbar confirmation
                                  GlobalSnackBar.show(
                                    context: context,
                                    message: 'Response copied to clipboard',
                                    variant: SnackBarVariant.success,
                                    duration: const Duration(seconds: 2),
                                  );
                                },
                              ),
                            ),
                        ],
                        // Show typing indicator for the last message when typing
                        if (_isTyping && index == _messages.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                            child: TypingIndicator(isTyping: true),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(bottom: 32.0, left: 8, right: 16),
              child: MarkdownBody(
                data: messageText,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                  ),
                  h1: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  h2: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  h3: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  listBullet: TextStyle(
                    color: colors.muted,
                    height: 1.5,
                  ),
                  blockquote: TextStyle(
                    color: theme.colorScheme.onSurface.withAlpha(204),
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary.withAlpha(128),
                        width: 4.0,
                      ),
                    ),
                  ),
                  blockquotePadding: const EdgeInsets.only(left: 16.0),
                  code: TextStyle(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurface,
                    backgroundColor: colors.input,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: colors.input,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  codeblockPadding: const EdgeInsets.all(8.0),
                  a: TextStyle(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                  listIndent: 24.0,
                  orderedListAlign: WrapAlignment.start,
                  unorderedListAlign: WrapAlignment.start,
                ),
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrl(Uri.parse(href), 
                      mode: LaunchMode.externalApplication);
                  }
                },
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMessageInputArea(
      ThemeData theme, bool isDarkMode, dynamic colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          children: [
            // Message text field row
            TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              cursorColor: colors.inputForeground,
              decoration: InputDecoration(
                fillColor: colors.input,
                filled: true,
                hintText: 'Type a message or / for prompts...',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                isDense: true,
                hintStyle: TextStyle(
                  color: colors.muted,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              onChanged: (text) {
                setState(() {
                  // This forces the send button to update
                });
              },
            ),

            // Buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Voice input button
                    IconButton(
                      icon: Icon(
                        Icons.mic_none,
                        color: colors.muted,
                      ),
                      onPressed: () {
                        GlobalSnackBar.show(
                          context: context,
                          message: 'Voice input coming soon',
                          variant: SnackBarVariant.info,
                        );
                      },
                    ),

                    // Image upload button
                    IconButton(
                      icon: Icon(
                        Icons.image_outlined,
                        color: colors.muted,
                      ),
                      onPressed: () {
                        GlobalSnackBar.show(
                          context: context,
                          message: 'Image upload coming soon',
                          variant: SnackBarVariant.info,
                        );
                      },
                    ),

                    // Prompt selector
                    IconButton(
                      icon: Icon(
                        Icons.format_quote,
                        color: colors.muted,
                      ),
                      onPressed: () {
                        // Show the prompt selector dialog directly with empty query
                        PromptSelector.show(context, '', _handlePromptSelected);
                      },
                    ),
                  ],
                ),

                // Send button
                AnimatedBuilder(
                  animation: _sendButtonController,
                  builder: (context, child) {
                    final bool showLoading = _sendButtonController.status ==
                            AnimationStatus.forward ||
                        _sendButtonController.status ==
                            AnimationStatus.completed;
                    final bool isDisabled =
                        _messageController.text.trim().isEmpty || _isSending;

                    return Material(
                      color: isDisabled
                          ? colors.muted.withAlpha(30)
                          : colors.inputForeground,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: isDisabled ? null : _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: showLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colors.muted,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_upward,
                                  color: isDisabled
                                      ? colors.muted.withAlpha(128)
                                      : colors.input,
                                  size: 24,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
