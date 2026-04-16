import 'package:flutter/material.dart';
import '../../../main.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return TextButton(
      onPressed: () => SRTBApp.setLocale(
        context,
        isArabic ? const Locale('fr') : const Locale('ar'),
      ),
      child: Text(
        isArabic ? 'Français' : 'العربية',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}