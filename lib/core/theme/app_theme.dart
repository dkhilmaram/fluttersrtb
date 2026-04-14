import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Brand colours ──────────────────────────────────────────
  static const Color navyDark  = Color(0xFF0D1B3E);
  static const Color navyMid   = Color(0xFF1A3260);
  static const Color navyLight = Color(0xFF1E4080);
  static const Color goldLight     = Color(0xFFF5A623);
  static const Color goldDark      = Color(0xFFD48A0E);
  static const Color offWhite      = Color(0xFFF4F6FB);
  static const Color greyLight     = Color(0xFFE0E6F0);
  static const Color greyMid       = Color(0xFF8A9BB5);
  static const Color errorRed      = Color(0xFFD32F2F);
  static const Color successGreen  = Color(0xFF2E7D32);

  // ── Semantic aliases (used by feature pages) ───────────────
  static const Color surface   = offWhite;            // Scaffold background
  static const Color cardWhite = Color(0xFFFFFFFF);   // Card/panel background

  // ── App-wide ThemeData ──────────────────────────────────────
  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: navyDark),
    useMaterial3: true,
    scaffoldBackgroundColor: offWhite,
    appBarTheme: const AppBarTheme(
      backgroundColor: navyDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: navyDark,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    ),
  );
}