import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'pages/login_page.dart';
import 'local_database.dart';
import 'sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Initialize sqflite for desktop (Windows/Linux/macOS) ──
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ── Initialize DB — all tables including agent_cache ──
  try {
    final database = await LocalDatabase.db;
    print('✓ Database initialized successfully');
    print('📊 Database path: ${database.path}');
  } catch (e) {
    print('❌ Error initializing database: $e');
  }

  // ── Start connectivity watcher for auto-sync ──
  SyncService.startListening();

  runApp(const SRTBApp());
}

class SRTBApp extends StatelessWidget {
  const SRTBApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SRTB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: const Color(0xFF1A3F7A)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}