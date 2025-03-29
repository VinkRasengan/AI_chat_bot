import 'package:flutter/material.dart';
// Note: We can't create provider.dart or theme_config.dart since we don't have their content
// For this demo, we'll comment out the problematic imports
// import 'package:provider/provider.dart';
// import 'core/utils/config/theme_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

import 'core/services/auth/auth_service.dart';
import 'core/services/chat/jarvis_chat_service.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/chat/presentation/home_page.dart';
import 'features/auth/presentation/google_auth_handler_page.dart';
import 'features/auth/presentation/signup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat Bot',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Handle routes for authentication
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Handle Google auth callback
        if (settings.name?.startsWith('/auth/google/callback') == true) {
          // Extract query parameters
          final uri = Uri.parse(settings.name!);
          final params = uri.queryParameters;

          return MaterialPageRoute(
            builder: (context) => GoogleAuthHandlerPage(params: params),
          );
        }

        // Default routes
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (context) => const LoginPage());
          case '/home':
            return MaterialPageRoute(builder: (context) => const HomePage());
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginPage());
          case '/signup':
            return MaterialPageRoute(builder: (context) => const SignupPage());
          default:
            return MaterialPageRoute(builder: (context) => const LoginPage());
        }
      },
      home: FutureBuilder<Widget>(
        future: _handleStartup(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return const LoginPage();
          } else {
            return snapshot.data ?? const LoginPage();
          }
        },
      ),
    );
  }

  Future<void> _initializeServices() async {
    final logger = Logger();
    try {
      // Initialize services in sequence
      await dotenv.load(fileName: '.env');

      final authService = AuthService();
      await authService.initialize();

      final chatService = JarvisChatService(authService);
      await chatService.initialize();

      logger.i('Services initialized successfully');
    } catch (e) {
      logger.e('Error initializing services: $e');
    }
  }

  Future<Widget> _handleStartup() async {
    final logger = Logger();
    try {
      // Wait for initialization to complete
      await _initializeServices();

      // Check if user is logged in
      final authService = AuthService();
      final isLoggedIn = await authService.isLoggedIn();

      if (isLoggedIn) {
        logger.i('User is logged in, navigating to HomePage');
        return const HomePage();
      } else {
        logger.i('User is not logged in, navigating to LoginPage');
        return const LoginPage();
      }
    } catch (e) {
      logger.e('Error during startup: $e');
      return const LoginPage();
    }
  }
}

// AuthCheckPage class remains unchanged...
class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> {
  final AuthService _authService = AuthService();
  final Logger _logger = Logger();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      _logger.i('Checking authentication status...');

      setState(() {
        _isLoading = true;
      });

      final isLoggedIn = await _authService.isLoggedIn();

      if (!mounted) return;

      if (isLoggedIn) {
        _logger.i('User is authenticated, navigating to home page');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        _logger.i('User is not authenticated, navigating to login page');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      _logger.e('Error checking auth status: $e');

      if (!mounted) return;

      // Fallback to login page on error
      _logger.i('Navigating to login page due to error');
      Navigator.pushReplacementNamed(context, '/login');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : const Text('Checking authentication status...'),
      ),
    );
  }
}