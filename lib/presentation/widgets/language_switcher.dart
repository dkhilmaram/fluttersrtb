import 'package:flutter/material.dart';
import '../../../main.dart';
import '../../../core/theme/app_theme.dart';

/// A pill-shaped FR | AR toggle that fits into the navy gradient header.
/// Active language is highlighted in gold; inactive is ghost/white.
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangOption(
            label: 'FR',
            isActive: !isArabic,
            onTap: () => SRTBApp.setLocale(context, const Locale('fr')),
          ),
          // Thin divider between options
          Container(width: 1, height: 16, color: Colors.white.withOpacity(0.2)),
          _LangOption(
            label: 'AR',
            isActive: isArabic,
            onTap: () => SRTBApp.setLocale(context, const Locale('ar')),
          ),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LangOption({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.goldLight : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.navyDark : Colors.white.withOpacity(0.85),
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}