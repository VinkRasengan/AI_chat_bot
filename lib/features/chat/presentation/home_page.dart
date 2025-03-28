import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../core/models/chat/chat_session.dart';
import '../../../core/services/chat/jarvis_chat_service.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../../widgets/ai/model_selector_widget.dart';
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
  final JarvisChatService _chatService = JarvisChatService();
  final AuthService _authService = AuthService();
  
  List<ChatSession> _chatSessions = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _selectedModel = 'gemini-1.5-flash-latest';
  String _userEmail = '';
  String _userName = '';
  
  @override
  void initState() {
    super.initState();
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
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      // Check if token needs refreshing first
      final authService = AuthService();
      if (!await authService.isLoggedIn()) {
        _logger.w('User not logged in or token expired, forcing authentication update');
        final refreshed = await authService.forceAuthStateUpdate();
        if (!refreshed) {
          _logger.w('Failed to refresh authentication, redirecting to login');
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
          return;
        }
      }
      
      final isUsingGemini = _chatService.isUsingDirectGeminiApi();
      final sessions = await _chatService.getUserChatSessions();
      
      if (!mounted) return;
      
      setState(() {
        _chatSessions = sessions;
        _isLoading = false;
        if (isUsingGemini && sessions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Using offline mode. Some features may be limited.')),
          );
        }
      });
    } catch (e) {
      _logger.e('Error loading chat sessions: $e');
      
      if (!mounted) return;
      
      // Check if it's an authentication error
      if (e.toString().contains('Authentication failed') || 
          e.toString().contains('Unauthorized') ||
          e.toString().contains('401')) {
        
        _logger.w('Authentication error, attempting to refresh token');
        final refreshed = await _authService.forceAuthStateUpdate();
        
        if (!refreshed && mounted) {
          _logger.w('Token refresh failed, redirecting to login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Please log in again.')),
          );
          Navigator.of(context).pushReplacementNamed('/login');
          return;
        }
        
        // Try loading sessions again after successful token refresh
        if (refreshed && mounted) {
          _logger.i('Token refreshed, retrying loading sessions');
          _loadChatSessions();
          return;
        }
      }
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chats: $e')),
        );
      }
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
      final newChat = await _chatService.createChatSession('New Chat');
      
      if (newChat != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(chatSession: newChat),
          ),
        ).then((_) => _loadChatSessions());
      }
    } catch (e) {
      _logger.e('Error creating new chat: $e');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create new chat: $e')),
      );
    }
  }
  
  Future<void> _deleteChat(ChatSession session) async {
    try {
      final success = await _chatService.deleteChatSession(session.id);
      
      if (!mounted) return;
      
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
    } catch (e) {
      _logger.e('Error deleting chat: $e');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model updated to $model')),
      );
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
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName.isNotEmpty ? _userName : 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _userEmail.isNotEmpty ? _userEmail : 'Not signed in',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
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
      
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withAlpha(13),
          border: Border(
            top: BorderSide(
              color: Colors.grey.withAlpha(77),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavButton(
              icon: Icons.account_circle,
              label: 'Account',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountManagementPage(),
                  ),
                );
              },
            ),
            _buildNavButton(
              icon: Icons.settings,
              label: 'Settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ),
                ).then((_) => _loadChatSessions());
              },
            ),
            _buildNavButton(
              icon: Icons.help_outline,
              label: 'Help',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpFeedbackPage(),
                  ),
                );
              },
            ),
            _buildNavButton(
              icon: Icons.logout,
              label: 'Sign Out',
              onTap: _signOut,
            ),
          ],
        ),
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChat,
        tooltip: 'New Chat',
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
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
        return ListTile(
          title: Text(session.title),
          subtitle: Text(
            'Tạo lúc: ${_formatDate(session.createdAt)}',
          ),
          leading: const CircleAvatar(
            child: Icon(Icons.chat),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteChat(session),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(chatSession: session),
              ),
            ).then((_) => _loadChatSessions());
          },
        );
      },
    );
  }
  
  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}