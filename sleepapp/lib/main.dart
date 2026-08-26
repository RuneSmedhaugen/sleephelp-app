import 'package:flutter/material.dart';
import 'screens/player_screen.dart';

void main() {
  runApp(const SleepSoundsApp());
}

class SleepSoundsApp extends StatelessWidget {
  const SleepSoundsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleep Sounds',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const PlayerScreen(),
    );
  }
}