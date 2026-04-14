import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'core/theme/app_theme.dart';
import 'core/utils/route_observer.dart';
import 'data/database/local_database.dart';
import 'presentation/pages/login/login_page.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Initialize sqflite for desktop (Windows / Linux / macOS) ──
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ── Initialize DB ──
  try {
    final database = await LocalDatabase.db;
    print('✓ Database initialized: ${database.path}');
  } catch (e) {
    print('❌ Error initializing database: $e');
  }

  // ── Start connectivity watcher + auto-sync ──
  SyncService.startListening();

  runApp(const SRTBApp());
}

class SRTBApp extends StatelessWidget {
  const SRTBApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    'SRTB',
      debugShowCheckedModeBanner: false,
      theme:                    AppTheme.light,
      navigatorObservers:       [appRouteObserver],
      home:                     const LoginPage(),
    );
  }
}