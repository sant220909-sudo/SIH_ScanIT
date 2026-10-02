import 'package:flutter/material.dart';
import 'package:cyber_nova/utils/app_theme.dart';

class LegalDisclaimerNote extends StatelessWidget {
  const LegalDisclaimerNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Text(
        'AI-assisted preliminary inspection. Final compliance determination requires verification against applicable rules and authorized inspection procedures.',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          height: 1.45,
        ),
      ),
    );
  }
}
