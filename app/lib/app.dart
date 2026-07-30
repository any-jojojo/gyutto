import 'package:flutter/material.dart';

class GyuttoApp extends StatelessWidget {
  const GyuttoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ぎゅっと',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F80ED),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F80ED),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ぎゅっと')),
      body: const SafeArea(child: Center(child: Text('家族のチャットをはじめましょう'))),
    );
  }
}
