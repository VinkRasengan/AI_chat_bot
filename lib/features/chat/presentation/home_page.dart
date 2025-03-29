import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/models/chat/chat_session.dart';
import '../../../core/services/chat/jarvis_chat_service.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../../widgets/ai/model_selector_widget.dart';
import '../../../core/constants/api_constants.dart'; // Add this import
import '../../settings/presentation/settings_page.dart';
import '../../account/presentation/account_management_page.dart';
import '../../support/presentation/help_feedback_page.dart';
import 'chat_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Logger _logger = Logger();
  final AuthService _authService = AuthService();
  late final JarvisChatService _chatService;
  
  List<ChatSession> _chatSessions = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _selectedModel = 'gemini-1.5-flash-latest';
  String _userEmail = '';
  String _userName = '';
  String? _error;
  bool _noConversationsYet = false;
  
  @override
  void initState() {
    super.initState();
    _chatService = JarvisChatService(_authService); // Fix constructor
    _checkAuthAndLoadData();
  }
  
  Future<void> _checkAuthAndLoadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      // Check authentication status and force update if needed
      final isLoggedIn = await _authService.isLoggedIn();
      
      if (!isLoggedIn) {
        _logger.w('User not logged in, trying to refresh authentication state');
        final refreshed = await _authService.forceAuthStateUpdate();
        
        if (!refreshed) {
          _logger.w('Authentication refresh failed, navigating to login');
          
          if (!mounted) return;
          
          // Navigate back to login page
          Navigator.of(context).pushReplacementNamed('/login');
          return;
        }
      }
      
      // Load user info and chat sessions
      await _loadUserInfo();
      await _loadChatSessions();
      await _loadSelectedModel();
      
    } catch (e) {
      _logger.e('Error in initial data loading: $e');
      
      if (!mounted) return;
      
      setState(() {
        _hasError = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadUserInfo() async {
    try {
      final user = _authService.currentUser;
      
      if (user == null) {
        _logger.w('No user found in AuthService');
        
        // Try to force auth state update
        await _authService.forceAuthStateUpdate();
        
        // Check again after update
        final refreshedUser = _authService.currentUser;
        
        if (refreshedUser == null) {
          _logger.w('Still no user after auth state update');
          setState(() {
            _userEmail = 'Not signed in';
            _userName = 'Guest';
          });
          return;
        }
        
        // Use refreshed user
        setState(() {
          _userEmail = refreshedUser.email;
          _userName = refreshedUser.name ?? 'User';
        });
      } else {
        // Use current user
        setState(() {
          _userEmail = user.email;
          _userName = user.name ?? 'User';
        });
      }
      
      _logger.i('User info loaded: $_userName ($_userEmail)');
    } catch (e) {
      _logger.e('Error loading user info: $e');
      setState(() {
        _userEmail = 'Error loading user';
        _userName = 'Unknown';
      });
    }
  }
  
  Future<void> _loadChatSessions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _chatSessions = [];
      _error = null;
    });
    
    try {
      _logger.i('Loading chat sessions');
      
      // Check if selected model supports conversation history
      final model = await _chatService.getSelectedModel();
      final supportsHistory = ApiConstants.modelSupportsConversationHistory[model ?? ''] ?? false;
      
      if (!supportsHistory && mounted) {
        // Show message about model limitation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Current model does not support conversation history. Using local chat mode.'),
                duration: const Duration(seconds: 6),
              ),
            );
          }
        });
      }
      
      final chatSessions = await _chatService.getUserChatSessions();
      
      if (!mounted) return;
      
      setState(() {
        _chatSessions = chatSessions;
        _isLoading = false;
        
        // If there are no sessions, show the "no conversations" state
        if (_chatSessions.isEmpty) {
          _noConversationsYet = true;
        } else {
          _noConversationsYet = false;
        }
      });
    } catch (e) {
      _logger.e('Error loading chat sessions: $e');
      
      if (!mounted) return;
      
      // Special case for conversation history limitation
      if (e.toString().toLowerCase().contains('does not support conversation history') ||
          e.toString().toLowerCase().contains('400 bad request')) {
        setState(() {
          _isLoading = false;
          _noConversationsYet = true;
        });
        
        // Show a more helpful message about the model limitation
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('The selected model ($_selectedModel) does not support conversation history. Chat history will be stored locally.'),
                duration: const Duration(seconds: 6),
              ),
            );
          });
        }
        return;
      }
      
      setState(() {
        _isLoading = false;
        _error = 'Failed to load conversations. Please try again.';
      });
      
      // Show a snackbar with the error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error ?? 'Unknown error'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  Future<void> _loadSelectedModel() async {
    try {
      final model = await _chatService.getSelectedModel();
      if (model != null && mounted) {
        setState(() {
          _selectedModel = model;
        });
      }
    } catch (e) {
      _logger.e('Error loading selected model: $e');
    }
  }
  
  Future<void> _createNewChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newSession = await _chatService.createChatSession('New Chat');
      
      if (mounted) {
        setState(() {
          _chatSessions.add(newSession);
          _isLoading = false;
        });
        
        // Navigate to the new chat session
        _navigateToChatScreen(newSession);
      }
    } catch (e) {
      _logger.e('Error creating chat session: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating chat: $e')),
        );
      }
    }
  }
  
  Future<void> _deleteChat(ChatSession session) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _chatService.deleteChatSession(session.id);
      
      if (mounted) {
        if (success) {
          setState(() {
            _chatSessions.removeWhere((s) => s.id == session.id);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat deleted')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete chat')),
          );
        }
        
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Error deleting chat session: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
  
  Future<void> _updateSelectedModel(String model) async {
    try {
      setState(() {
        _selectedModel = model;
      });
      
      await _chatService.updateSelectedModel(model);
      
      if (!mounted) return;
      
      // Check if the selected model supports conversation history
      final supportsHistory = ApiConstants.modelSupportsConversationHistory[model] ?? false;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Model updated to $model${supportsHistory ? '' : ' (Local chat mode - history not saved on server)'}'),
          duration: const Duration(seconds: 4),
        ),
      );
      
      // Reload sessions after model change
      _loadChatSessions();
    } catch (e) {
      _logger.e('Error updating model: $e');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update model: $e')),
      );
    }
  }
  
  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _logger.e('Error signing out: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
  
  /// Check and fix API issues
  Future<void> _checkAndFixApiIssues() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      _logger.i('Checking and fixing API issues');
      
      // Store a local copy of the context
      final currentContext = context;
      
      // Call forceUseApiMode without trying to use its result as a boolean
      await _chatService.forceUseApiMode(true);
      
      if (!mounted) return;
      
      // Reload sessions after trying to fix API
      await _loadChatSessions();
      
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
          content: Text('API connection restored. Chat history should now be saved.'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      _logger.e('Error checking API issues: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not restore API connection: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Force API mode and reload data
  Future<void> _forceUseApiMode() async {
    try {
      // Fix the parameter
      await _chatService.forceUseApiMode(true);
      await _authService.forceAuthStateUpdate();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        actions: [
          ModelSelectorWidget(
            currentModel: _selectedModel,
            onModelChanged: _updateSelectedModel,
          ),
          IconButton(
            icon: const Icon(Icons.sync_problem),
            tooltip: 'Fix API Issues',
            onPressed: _checkAndFixApiIssues,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: 'Force Online Mode',
            onPressed: _forceUseApiMode,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userName.isNotEmpty ? _userName : 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    _userEmail.isNotEmpty ? _userEmail : 'Not signed in',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Chat'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _createNewChat();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Account'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountManagementPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ),
                ).then((_) => _loadChatSessions());
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpFeedbackPage(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _signOut();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? _buildErrorView()
                    : _chatSessions.isEmpty
                        ? _buildEmptyView()
                        : _buildChatList(),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChat,
        tooltip: _noConversationsYet ? 'Create first chat' : 'New Chat',
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Đã xảy ra lỗi khi tải danh sách trò chuyện',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Vui lòng kiểm tra kết nối mạng và thử lại',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadChatSessions,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có cuộc trò chuyện nào',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bắt đầu trò chuyện mới bằng cách nhấn nút "+" bên dưới',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _createNewChat,
            child: const Text('Tạo cuộc trò chuyện mới'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChatList() {
    return ListView.builder(
      itemCount: _chatSessions.length,
      itemBuilder: (context, index) {
        final session = _chatSessions[index];
        final isLocalSession = session.id.startsWith('local_');
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              _formatChatTitle(session.title),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                if (isLocalSession)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Local',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    'Created: ${_formatDate(session.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            leading: CircleAvatar(
              backgroundColor: _getAvatarColor(session.title),
              child: Icon(
                isLocalSession ? Icons.offline_bolt : Icons.chat,
                color: Colors.white,
                size: 20,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteChat(session),
              color: Colors.grey[700],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(chatSession: session),
                ),
              ).then((_) => _loadChatSessions());
            },
          ),
        );
      },
    );
  }
  
  String _formatChatTitle(String title) {
    // Try to make the title more readable
    if (title.length <= 40) return title;
    
    // If it's too long, check if it contains a question
    final questionIndex = title.indexOf('?');
    if (questionIndex > 0 && questionIndex < 60) {
      return title.substring(0, questionIndex + 1);
    }
    
    // Otherwise, truncate and add ellipsis
    return '${title.substring(0, 37)}...';
  }
  
  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    return '$day/$month/$year';
  }
  
  Color _getAvatarColor(String title) {
    // Generate a consistent color based on the title
    final colorSeed = title.codeUnits.fold(0, (prev, element) => prev + element);
    final colors = [
      Colors.blue[700]!,
      Colors.purple[700]!,
      Colors.green[700]!,
      Colors.orange[800]!,
      Colors.teal[700]!,
      Colors.pink[700]!,
    ];
    
    return colors[colorSeed % colors.length];
  }
  
  void _navigateToChatScreen(ChatSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(chatSession: session),
      ),
    ).then((_) => _loadChatSessions());
  }
}