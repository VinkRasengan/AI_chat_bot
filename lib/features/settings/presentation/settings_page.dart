import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/chat/jarvis_chat_service.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../debug/presentation/user_data_viewer_page.dart';
import '../../debug/presentation/windows_user_data_viewer.dart';
import '../../../core/utils/diagnostics/platform_checker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Logger _logger = Logger();
  final AuthService _authService = AuthService();
  late JarvisChatService _chatService;
  String? _selectedModel;
  bool _isDarkMode = false;
  String _languageCode = 'vi';
  late bool _isUsingDirectApi;
  bool _isCacheEnabled = true;
  double _fontSizeAdjustment = 0;
  bool _isLoadingStatus = false;
  Map<String, bool> _apiStatus = {
    'jarvisApi': false,
    'geminiApi': false,
  };

  @override
  void initState() {
    super.initState();
    _chatService = JarvisChatService(_authService);
    _loadSettings();
    _checkApiStatus();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _isDarkMode = prefs.getBool('isDarkMode') ?? false;
        _selectedModel = prefs.getString('selectedModel');
        _languageCode = prefs.getString('languageCode') ?? 'vi';
        _isCacheEnabled = prefs.getBool('isCacheEnabled') ?? true;
        _fontSizeAdjustment = prefs.getDouble('fontSizeAdjustment') ?? 0;
      });

      _isUsingDirectApi = await _chatService.isUsingDirectGeminiApi();
    } catch (e) {
      _logger.e('Error loading settings: $e');
    }
  }

  Future<void> _checkApiStatus() async {
    if (_isLoadingStatus) return;

    setState(() {
      _isLoadingStatus = true;
    });

    try {
      final status = await _chatService.checkAllApiConnections();

      if (!mounted) return;

      setState(() {
        _apiStatus = status;
        _isLoadingStatus = false;
      });
    } catch (e) {
      _logger.e('Error checking API status: $e');

      if (!mounted) return;

      setState(() {
        _apiStatus = {
          'jarvisApi': false,
          'geminiApi': false,
        };
        _isLoadingStatus = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('isDarkMode', _isDarkMode);
      await prefs.setString('selectedModel', _selectedModel ?? '');
      await prefs.setString('languageCode', _languageCode);
      await prefs.setBool('isCacheEnabled', _isCacheEnabled);
      await prefs.setDouble('fontSizeAdjustment', _fontSizeAdjustment);

      _chatService.toggleDirectGeminiApi();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    } catch (e) {
      _logger.e('Error saving settings: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAppInfo(context),
            tooltip: 'App Info',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('API Settings'),

            SwitchListTile(
              title: const Text('Use Direct Gemini API'),
              subtitle: const Text(
                'Use Google Gemini API directly instead of Jarvis API (helpful if Jarvis API is down)',
              ),
              value: _isUsingDirectApi,
              onChanged: (value) {
                setState(() {
                  _isUsingDirectApi = value;
                });
                _saveSettings();
              },
            ),

            _buildApiStatusIndicator(),

            const Divider(height: 32),

            _buildSectionHeader('Display Settings'),

            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Enable dark color theme'),
              value: _isDarkMode,
              onChanged: (value) {
                setState(() {
                  _isDarkMode = value;
                });
                _saveSettings();
              },
            ),

            ListTile(
              title: const Text('Font Size'),
              subtitle: const Text('Adjust the text size'),
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: _fontSizeAdjustment,
                  min: -2,
                  max: 2,
                  divisions: 4,
                  label: _getFontSizeLabel(),
                  onChanged: (value) {
                    setState(() {
                      _fontSizeAdjustment = value;
                    });
                  },
                  onChangeEnd: (value) {
                    _saveSettings();
                  },
                ),
              ),
            ),

            ListTile(
              title: const Text('Language'),
              subtitle: Text('Current: $_languageCode'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showLanguageDialog(context),
            ),

            const Divider(height: 32),

            _buildSectionHeader('Data Settings'),

            SwitchListTile(
              title: const Text('Cache Conversations'),
              subtitle: const Text('Store conversations locally for faster loading'),
              value: _isCacheEnabled,
              onChanged: (value) {
                setState(() {
                  _isCacheEnabled = value;
                });
                _saveSettings();
              },
            ),

            ListTile(
              title: const Text('Clear Cache'),
              subtitle: const Text('Delete locally stored conversation data'),
              trailing: const Icon(Icons.delete_outline),
              onTap: () => _showClearCacheDialog(context),
            ),

            const Divider(height: 32),

            _buildSectionHeader('Advanced Settings'),

            ListTile(
              title: const Text('View User Data'),
              subtitle: const Text('Debug tool for viewing user data'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserDataViewerPage(),
                  ),
                );
              },
            ),

            if (PlatformChecker.isDesktop)
              ListTile(
                title: const Text('Windows User Data'),
                subtitle: const Text('View and manage stored Windows user data'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WindowsUserDataViewer(),
                    ),
                  );
                },
              ),

            const Divider(height: 32),

            _buildDiagnosticSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildApiStatusIndicator() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'API Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: _isLoadingStatus
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _isLoadingStatus ? null : _checkApiStatus,
                  tooltip: 'Refresh API Status',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _apiStatus['jarvisApi'] == true ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Jarvis API'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _apiStatus['geminiApi'] == true ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Gemini API'),
                const Spacer(),
                if (_apiStatus['geminiApi'] == false)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isUsingDirectApi = true;
                      });
                      _saveSettings();
                    },
                    child: const Text('Use Direct API'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticSection() {
    return ExpansionTile(
      title: const Text('API Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
      children: [
        FutureBuilder(
          future: Future.value(_chatService.getDiagnosticInfo()),
          builder: (context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading diagnostics: ${snapshot.error}'),
              );
            }

            final data = snapshot.data ?? {};

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('API Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Using offline mode: ${data['isUsingDirectGeminiApi'] ?? 'unknown'}'),
                  Text('Selected model: ${data['selectedModel'] ?? 'default'}'),
                  Text('Has API errors: ${data['hasApiError'] ?? 'false'}'),
                  Text('Last API failure: ${data['lastApiFailure'] ?? 'none'}'),

                  const SizedBox(height: 16),
                  const Text('Authentication', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('API authenticated: ${data['apiServiceAuthenticated'] ?? 'unknown'}'),

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await _refreshAuthToken(context);
                    },
                    child: const Text('Refresh Auth Token'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _refreshAuthToken(BuildContext context) async {
    final isContextMounted = mounted;
    final success = await _chatService.forceAuthStateUpdate();
    
    if (isContextMounted && mounted) {
      setState(() {});
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auth token refreshed successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refresh auth token')),
        );
      }
    }
  }

  void _showLanguageDialog(BuildContext context) {
    final languages = ['English', 'Tiếng Việt', 'Español', '中文', '日本語'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final language = languages[index];
              final isSelected = language == _languageCode;

              return ListTile(
                title: Text(language),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() {
                    _languageCode = language;
                  });
                  _saveSettings();
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will delete all locally stored conversation data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCache();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final isContextMounted = mounted;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('conversations');

      if (isContextMounted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared')),
        );
      }
    } catch (e) {
      _logger.e('Error clearing cache: $e');

      if (isContextMounted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing cache: $e')),
        );
      }
    }
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Info'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Made with Flutter and ❤️'),
            SizedBox(height: 16),
            Text(
              'This app lets you chat with an AI using the Jarvis API platform.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getFontSizeLabel() {
    switch (_fontSizeAdjustment.toInt()) {
      case -2:
        return 'Very Small';
      case -1:
        return 'Small';
      case 0:
        return 'Normal';
      case 1:
        return 'Large';
      case 2:
        return 'Very Large';
      default:
        return 'Normal';
    }
  }
}