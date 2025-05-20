import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import 'analytics_settings.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  final bool isDarkMode;

  const PrivacyPolicyScreen({
    Key? key,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = isDarkMode ? AppColors.dark : AppColors.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AnalyticsSettings(
                    isDarkMode: isDarkMode,
                  ),
                ),
              );
            },
            child: const Text('Analytics Settings'),
          ),
        ],
      ),
      body: Markdown(
        data: _privacyPolicyText,
        styleSheet: MarkdownStyleSheet(
          h1: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colors.foreground,
          ),
          h2: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colors.foreground,
          ),
          h3: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.foreground,
          ),
          p: TextStyle(
            fontSize: 16,
            color: colors.foreground,
            height: 1.5,
          ),
          listBullet: TextStyle(color: colors.muted),
          blockquote: TextStyle(
            color: colors.muted,
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
        ),
        onTapLink: (text, href, title) {
          if (href != null) {
            launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }

  final String _privacyPolicyText = '''
# Privacy Policy

_Last Updated: May 11, 2025_

## Introduction

Thank you for using AI Chat Bot. This Privacy Policy explains how we collect, use, and share information about you when you use our app and services.

## Information We Collect

### Information You Provide

- **Account Information**: When you create an account, we collect your email address and password.
- **Payment Information**: If you subscribe to our premium service, we collect payment information.
- **Conversation Data**: The content of your conversations with the AI.

### Information Collected Automatically

- **Usage Data**: We collect information about how you interact with the app, including the features you use and the time spent.
- **Device Information**: We collect information about your device, including device type, operating system, and unique identifiers.
- **Analytics Data**: We collect anonymous usage statistics to improve the app.

## How We Use Your Information

We use your information to:

- Provide, maintain, and improve our services
- Process transactions and manage your account
- Send you updates and notifications
- Understand how users interact with our app
- Protect against fraud and abuse

## Data Sharing and Disclosure

We may share your information with:

- **Service Providers**: Companies that provide services on our behalf
- **Legal Requests**: If required by law, court order, or governmental authority
- **Business Transfers**: If our company is sold, merged, or acquired

## Your Rights and Choices

### Analytics Opt-Out

You can disable analytics collection in the app settings. Go to Settings → Privacy Settings → Analytics Settings to manage your preferences.

### Data Access and Deletion

You can request access to or deletion of your data by contacting us at support@aichatbot.example.com.

## Data Security

We implement reasonable security measures to protect your personal information. However, no security system is impenetrable.

## Children's Privacy

Our service is not directed to children under 13, and we do not knowingly collect information from children under 13.

## Changes to This Policy

We may update this Privacy Policy from time to time. We will notify you of any significant changes.

## Contact Us

If you have questions about this Privacy Policy, please contact us at privacy@aichatbot.example.com.
''';
}
