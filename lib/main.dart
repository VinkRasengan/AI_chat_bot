import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'features/splash/splash_screen.dart';
import 'features/subscription/services/ad_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize AdManager
  await AdManager().initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isDarkMode = false;
  String _themeMode = 'system';
  static const String _themePreferenceKey = 'theme_preference';
  // final AnalyticsService _analyticsService = AnalyticsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreference();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangePlatformBrightness() {
    // Only update if we're using system theme
    if (_themeMode == 'system') {
      _updateThemeBasedOnSystem();
    }
    super.didChangePlatformBrightness();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeMode = prefs.getString(_themePreferenceKey);

      // If there's a saved preference, use it
      if (savedThemeMode != null) {
        setState(() {
          _themeMode = savedThemeMode;
          
          // Set dark mode based on the theme mode
          if (_themeMode == 'dark') {
            _isDarkMode = true;
          } else if (_themeMode == 'light') {
            _isDarkMode = false;
          } else {
            // System mode - use platform brightness
            _updateThemeBasedOnSystem();
          }
        });
      } else {
        // Otherwise, use the device preference (system mode)
        setState(() {
          _themeMode = 'system';
          _updateThemeBasedOnSystem();
        });
      }
    } catch (e) {
      // If there's an error, default to system preference
      setState(() {
        _themeMode = 'system';
        _updateThemeBasedOnSystem();
      });
    }
  }
  
  void _updateThemeBasedOnSystem() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    setState(() {
      _isDarkMode = brightness == Brightness.dark;
    });
  }

  Future<void> _saveThemePreference(String themeMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePreferenceKey, themeMode);
    } catch (e) {
      // Silently handle error
    }
  }
  void toggleTheme() {
    setState(() {
      if (_themeMode == 'system') {
        // If in system mode, switching will go to explicit dark/light mode
        _themeMode = _isDarkMode ? 'light' : 'dark';
        _isDarkMode = !_isDarkMode;
      } else if (_themeMode == 'dark') {
        // Toggle from dark to light
        _themeMode = 'light';
        _isDarkMode = false;
      } else {
        // Toggle from light to dark
        _themeMode = 'dark';
        _isDarkMode = true;
      }
      
      _saveThemePreference(_themeMode);
        // Track theme change in analytics
      // _analyticsService.setUserProperty(
      //   name: 'theme_preference',
      //   value: _themeMode,
      // );
    });
  }
  
  void setThemeMode(String themeMode) {
    if (_themeMode == themeMode) {
      return; // No change needed
    }
    
    setState(() {
      _themeMode = themeMode;
      
      if (_themeMode == 'dark') {
        _isDarkMode = true;
      } else if (_themeMode == 'light') {
        _isDarkMode = false;
      } else {
        // System mode - use platform brightness
        _updateThemeBasedOnSystem();
      }
      
      _saveThemePreference(_themeMode);
    });
  }
  @override
  Widget build(BuildContext context) {    return MaterialApp(
        title: 'AI Chat Bot',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(isDark: _isDarkMode),        
        home: SplashScreen(
          toggleTheme: toggleTheme,
          setThemeMode: setThemeMode,
          currentThemeMode: _themeMode,
        ),
    );
  }

  ThemeData _buildTheme({required bool isDark}) {
    final theme = Theme.of(context);
    final AppColors colors = isDark ? AppColors.dark : AppColors.light;
    final overlayColor = isDark ? colors.foreground.withAlpha(128) : colors.foreground.withAlpha(100);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: colors.background,

      // Card theme
      cardTheme: CardTheme(
        elevation: 2,
        color: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            width: 1,
          ),
        ),
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.primary,
          foregroundColor: colors.primaryForeground,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          overlayColor: overlayColor,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          overlayColor: overlayColor,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.input,
        foregroundColor: colors.inputForeground,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: colors.border.withAlpha(120),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 1,
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.cardForeground.withAlpha(128),
          side: BorderSide(color: colors.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          overlayColor: overlayColor,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          overlayColor: overlayColor,
        ),
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: colors.card,
        surfaceTintColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: colors.cardForeground,
        ),
        contentTextStyle: TextStyle(
          fontSize: 16,
          color: colors.cardForeground,
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: colors.card,
        labelStyle: TextStyle(color: colors.cardForeground),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.card,
        contentTextStyle: TextStyle(color: colors.cardForeground),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border),
        ),
      ),

      // App bar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        surfaceTintColor: colors.background,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: colors.cardForeground,
        ),
      ),

      fontFamily: 'Inter',

      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: colors.cardForeground,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: colors.cardForeground,
          fontFamily: 'Geist',
        ),
        displaySmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: colors.cardForeground,
          fontFamily: 'Geist',
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: colors.cardForeground,
          fontFamily: 'Geist',
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: colors.cardForeground,
          fontFamily: 'Geist',
        ),
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.cardForeground,
          fontFamily: 'Geist',
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: colors.cardForeground,
          fontFamily: 'Geist',
        ),
        titleMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: colors.cardForeground,
          fontFamily: 'Geist',
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: colors.cardForeground,
          fontFamily: 'Geist',
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: colors.cardForeground,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: colors.cardForeground,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: colors.cardForeground,
        ),
      ),

      hintColor: colors.muted,
      colorScheme: (isDark ? ColorScheme.dark() : ColorScheme.light()).copyWith(
        primary: colors.primary,
        onPrimary: colors.primaryForeground,
        secondary: colors.secondary,
        onSecondary: colors.secondaryForeground,
        surface: colors.card,
        surfaceDim: colors.input,
        surfaceContainer: colors.background,
        onSurface: colors.cardForeground,
        error: colors.red,
        onError: colors.redForeground,
        tertiary: colors.green,
        outline: colors.border,
      ),
    );
  }
}
