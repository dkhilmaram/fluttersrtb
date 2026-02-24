import 'package:flutter/material.dart';
import 'pages/login_page.dart';

void main() {
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A3F7A)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}