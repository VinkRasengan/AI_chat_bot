import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/models/chat/chat_session.dart';
import '../../../core/services/chat/jarvis_chat_service.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../../widgets/ai/model_selector_widget.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/exceptions/api_exceptions.dart';
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
    _chatService = JarvisChatService(_authService);
    _checkAuthAndLoadData();
  }
  
  Future<void> _checkAuthAndLoadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (!isLoggedIn) {
        final refreshed = await _authService.forceAuthStateUpdate();
        if (!refreshed && mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
          return;
        }
      }
      
      await _loadUserInfo();
      await _loadChatSessions();
      await _loadSelectedModel();
    } catch (e) {
      _logger.e('Error in initial data loading: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
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
  
  Future<void> _loadUserInfo() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        await _authService.forceAuthStateUpdate();
        final refreshedUser = _authService.currentUser;
        setState(() {
          _userEmail = refreshedUser?.email ?? 'Not signed in';
          _userName = refreshedUser?.name ?? 'Guest';
        });
      } else {
        setState(() {
          _userEmail = user.email;
          _userName = user.name ?? 'User';
        });
      }
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
      final model = await _chatService.getSelectedModel();
      final supportsHistory = ApiConstants.modelSupportsConversationHistory[model ?? ''] ?? false;
      
      if (!supportsHistory && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current model does not support conversation history. Using local chat mode.'),
              duration: Duration(seconds: 6),
            ),
          );
        });
      }
      
      final chatSessions = await _chatService.getUserChatSessions();
      if (!mounted) return;
      
      setState(() {
        _chatSessions = chatSessions;
        _isLoading = false;
        _noConversationsYet = _chatSessions.isEmpty;
      });
    } catch (e) {
      _logger.e('Error loading chat sessions: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _error = 'Failed to load conversations. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error ?? 'Unknown error')),
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
    try {
      setState(() {
        _isLoading = true;
      });
      
      final newChat = await _chatService.createChatSession('New Chat');
      setState(() {
        _isLoading = false;
      });
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatSession: newChat,
            chatService: _chatService,
          ),
        ),
      );
      
      _refreshChatSessions();
    } on InsufficientTokensException catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showInsufficientTokensDialog(e.message);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating new chat: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
  
  void _showInsufficientTokensDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usage Limit Reached'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.orange,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(message),
            const SizedBox(height: 12),
            const Text(
              'You have reached your usage limit for this period. '
              'Please try again later or upgrade your subscription for more tokens.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Upgrade Plan'),
          ),
        ],
      ),
    );
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
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
  
  Future<void> _updateSelectedModel(String model) async {
    try {
      setState(() {
        _selectedModel = model;
      });
      await _chatService.updateSelectedModel(model);
      if (!mounted) return;
      
      final supportsHistory = ApiConstants.modelSupportsConversationHistory[model] ?? false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Model updated to ${ApiConstants.modelNames[model] ?? model}${supportsHistory ? '' : ' (Local chat mode - history not saved on server)'}'),
          duration: const Duration(seconds: 4),
        ),
      );
      _loadChatSessions();
    } catch (e) {
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
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
  
  Future<void> _checkAndFixApiIssues() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _chatService.forceUseApiMode(true);
      await _loadChatSessions();
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API connection restored. Chat history should now be saved.'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not restore API connection: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forceUseApiMode() async {
    try {
      await _chatService.forceUseApiMode(true);
      await _authService.forceAuthStateUpdate();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _refreshChatSessions() {
    _loadChatSessions();
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
                Navigator.pop(context);
                _createNewChat();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Account'),
              onTap: () {
                Navigator.pop(context);
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
                Navigator.pop(context);
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
                Navigator.pop(context);
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
                Navigator.pop(context);
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
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Đã xảy ra lỗi khi tải danh sách trò chuyện',
            style: TextStyle(fontWeight: FontWeight.bold),
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
          const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Chưa có cuộc trò chuyện nào',
            style: TextStyle(fontWeight: FontWeight.bold),
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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              _formatChatTitle(session.title),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
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
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                    ),
                  ),
                Expanded(
                  child: Text(
                    'Created: ${_formatDate(session.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                  builder: (context) => ChatScreen(
                    chatSession: session,
                    chatService: _chatService,
                  ),
                ),
              ).then((_) => _loadChatSessions());
            },
          ),
        );
      },
    );
  }
  
  String _formatChatTitle(String title) {
    if (title.length <= 40) return title;
    final questionIndex = title.indexOf('?');
    if (questionIndex > 0 && questionIndex < 60) {
      return title.substring(0, questionIndex + 1);
    }
    return '${title.substring(0, 37)}...';
  }
  
  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    return '$day/$month/$year';
  }
  
  Color _getAvatarColor(String title) {
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
}