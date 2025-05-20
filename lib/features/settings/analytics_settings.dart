import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../../core/constants/app_colors.dart';

class AnalyticsSettings extends StatefulWidget {
  final bool isDarkMode;

  const AnalyticsSettings({
    Key? key,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<AnalyticsSettings> createState() => _AnalyticsSettingsState();
}

class _AnalyticsSettingsState extends State<AnalyticsSettings> {
  static const String ANALYTICS_ENABLED_KEY = 'analytics_enabled';
  static const String CRASH_REPORTING_ENABLED_KEY = 'crash_reporting_enabled';
  
  final Logger _logger = Logger();
  
  bool _analyticsEnabled = true;
  bool _crashReportingEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _analyticsEnabled = prefs.getBool(ANALYTICS_ENABLED_KEY) ?? true;
        _crashReportingEnabled = prefs.getBool(CRASH_REPORTING_ENABLED_KEY) ?? true;
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Error loading analytics preferences: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _saveAnalyticsPreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(ANALYTICS_ENABLED_KEY, value);
      
      _logger.i('Analytics collection set to: $value');
    } catch (e) {
      _logger.e('Error saving analytics preference: $e');
    }
  }
  Future<void> _saveCrashReportingPreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CRASH_REPORTING_ENABLED_KEY, value);
      
      _logger.i('Crash reporting set to: $value');
    } catch (e) {
      _logger.e('Error saving crash reporting preference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.isDarkMode ? AppColors.dark : AppColors.light;
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Data Collection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Enable Analytics'),
            subtitle: const Text(
              'Collects anonymous usage data to help us improve the app',
            ),
            value: _analyticsEnabled,
            onChanged: (value) {
              setState(() {
                _analyticsEnabled = value;
              });
              _saveAnalyticsPreference(value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Enable Crash Reporting'),
            subtitle: const Text(
              'Sends crash reports to help us fix issues',
            ),
            value: _crashReportingEnabled,
            onChanged: (value) {
              setState(() {
                _crashReportingEnabled = value;
              });
              _saveCrashReportingPreference(value);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'About Data Collection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'We collect anonymous usage data to understand how users interact with our app. This helps us improve features and fix issues.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'We never collect or store your conversations with the AI models or any personal information without your explicit consent.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
