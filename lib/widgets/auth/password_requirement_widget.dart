import 'package:flutter/material.dart';

/// A widget that displays password requirements with visual indicators
/// for each requirement's status
class PasswordRequirementWidget extends StatelessWidget {
  final String password;
  final bool isVisible;
  
  const PasswordRequirementWidget({
    super.key, 
    required this.password,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    
    // Requirements
    final hasLength = password.length >= 8;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password must:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          _buildRequirementItem(
            context,
            'Have at least 8 characters',
            hasLength,
          ),
          _buildRequirementItem(
            context,
            'Include uppercase letter',
            hasUppercase,
          ),
          _buildRequirementItem(
            context,
            'Include lowercase letter',
            hasLowercase,
          ),
          _buildRequirementItem(
            context,
            'Include a number',
            hasDigit,
          ),
          _buildRequirementItem(
            context,
            'Include a special character (!@#\$...)',
            hasSpecial,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRequirementItem(BuildContext context, String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 18,
            width: 18,
            decoration: BoxDecoration(
              color: isValid ? Colors.green : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isValid ? Colors.green : Colors.grey.shade500,
                width: 1.5,
              ),
            ),
            child: isValid
                ? const Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isValid ? Colors.green.shade800 : Colors.grey.shade700,
                fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget that shows a password strength indicator
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final String strengthText;
  final double strength;
  
  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    required this.strengthText,
    required this.strength,
  });
  
  @override
  Widget build(BuildContext context) {
    Color getColor() {
      if (strength < 0.3) return Colors.red;
      if (strength < 0.6) return Colors.orange;
      if (strength < 0.8) return Colors.yellow.shade700;
      return Colors.green;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: strength,
              minHeight: 4,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(getColor()),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strengthText,
              style: TextStyle(
                fontSize: 12,
                color: getColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (password.isNotEmpty) 
              Text(
                '${password.length} characters',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
