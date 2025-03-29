import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpFeedbackPage extends StatefulWidget {
  const HelpFeedbackPage({super.key});

  @override
  State<HelpFeedbackPage> createState() => _HelpFeedbackPageState();
}

class _HelpFeedbackPageState extends State<HelpFeedbackPage> {
  final Logger _logger = Logger();
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSendingFeedback = false;
  bool _showThankYou = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback')),
      );
      return;
    }

    setState(() {
      _isSendingFeedback = true;
    });

    try {
      // Here you would typically send the feedback to your backend
      // For now, we'll just simulate a successful submission
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _isSendingFeedback = false;
        _showThankYou = true;
        _feedbackController.clear();
      });

      // Reset thank you message after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showThankYou = false;
          });
        }
      });
    } catch (e) {
      _logger.e('Error sending feedback: $e');
      if (!mounted) return;

      setState(() {
        _isSendingFeedback = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending feedback: $e')),
      );
    }
  }

  void _viewFAQ() {
    // In a real app, you would navigate to a FAQ page
    // For now, we'll just show a dialog with some sample FAQs
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Frequently Asked Questions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Q: How do I create a new chat?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('A: Tap the "+" button on the home screen to start a new chat.'),
              SizedBox(height: 12),

              Text('Q: How do I change the AI model?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('A: Tap the model selector in the top-right corner of the screen and choose your preferred model.'),
              SizedBox(height: 12),

              Text('Q: How do I delete a chat?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('A: Swipe left on a chat or tap the delete icon next to it.'),
              SizedBox(height: 12),

              Text('Q: Is my data secure?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('A: Yes, we encrypt all communications and do not store your chat data permanently.'),
              SizedBox(height: 12),

              Text('Q: How do I reset my password?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('A: Go to the login screen and tap "Forgot Password" to receive a password reset link.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: null, // Will be overridden in context
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch URL')),
        );
      }
    } catch (e) {
      _logger.e('Error launching URL: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showLiveChatInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Chat Information'),
        content: const Text('Our live chat is available 24/7 to assist you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Feedback'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Help Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Need Help?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                      leading: const Icon(Icons.question_answer),
                      title: const Text('View FAQ'),
                      onTap: _viewFAQ,
                    ),

                    const Divider(),

                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('Email'),
                      subtitle: const Text('support@example.com'),
                      onTap: () => _launchUrl('mailto:support@example.com'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.chat),
                      title: const Text('Live Chat'),
                      subtitle: const Text('Available 24/7'),
                      onTap: () => _showLiveChatInfo(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Feedback Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send Feedback',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Help us improve by sharing your experience or reporting issues',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _feedbackController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your feedback here...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                    ),

                    const SizedBox(height: 16),

                    if (_showThankYou)
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.green.shade100,
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Thank you for your feedback!',
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSendingFeedback ? null : _sendFeedback,
                        child: _isSendingFeedback
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Submit Feedback'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // App Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About App',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const ListTile(
                      leading: Icon(Icons.info),
                      title: Text('Version'),
                      subtitle: Text('1.0.0'),
                    ),

                    const Divider(),

                    ListTile(
                      leading: const Icon(Icons.description),
                      title: const Text('Terms of Service'),
                      onTap: () {
                        // Navigate to Terms of Service
                      },
                    ),

                    const Divider(),

                    ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text('Privacy Policy'),
                      onTap: () {
                        // Navigate to Privacy Policy
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}