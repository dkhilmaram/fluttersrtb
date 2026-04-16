import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';             
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'core/theme/app_theme.dart';
import 'core/utils/route_observer.dart';
import 'data/database/local_database.dart';
import 'presentation/pages/login/login_page.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    final database = await LocalDatabase.db;
    print('✓ Database initialized: ${database.path}');
  } catch (e) {
    print('❌ Error initializing database: $e');
  }

  SyncService.startListening();
  runApp(const SRTBApp());
}

class SRTBApp extends StatefulWidget {
  const SRTBApp({super.key});

  // Call this from any widget to switch language
  static void setLocale(BuildContext context, Locale locale) {
    context.findAncestorStateOfType<_SRTBAppState>()?.setLocale(locale);
  }

  @override
  State<SRTBApp> createState() => _SRTBAppState();
}

class _SRTBAppState extends State<SRTBApp> {
  Locale _locale = const Locale('fr'); // default: French

  void setLocale(Locale locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                      'SRTB',
      debugShowCheckedModeBanner: false,
      theme:                      AppTheme.light,
      navigatorObservers:         [appRouteObserver],

      // ── i18n ──────────────────────────────────────────────
      locale: _locale,
      supportedLocales: const [
        Locale('fr'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ── RTL handled automatically for 'ar' ────────────────

      home: const LoginPage(),
    );
  }
}