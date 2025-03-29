import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'core/services/auth/auth_service.dart';
import 'core/services/chat/jarvis_chat_service.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/chat/presentation/home_page.dart';
import 'features/auth/presentation/google_auth_handler_page.dart';
import 'features/auth/presentation/signup_page.dart';

// Create global services
final Logger logger = Logger();
final AuthService authService = AuthService();
final JarvisChatService jarvisChatService = JarvisChatService(authService);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services before running the app
  try {
    await authService.initialize();
    await jarvisChatService.initialize();
    logger.i('Services initialized successfully');
  } catch (e) {
    logger.e('Error initializing services: $e');
  }
  
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
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Handle Google auth callback
        if (settings.name?.startsWith('/auth/google/callback') == true) {
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
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const LoginPage();
          } else {
            return snapshot.data ?? const LoginPage();
          }
        },
      ),
    );
  }

  Future<Widget> _handleStartup() async {
    try {
      // Check if user is logged in
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