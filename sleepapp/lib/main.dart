import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'screens/player_screen.dart';
import 'services/sleep_audio_handler.dart';

late SleepAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  audioHandler = await AudioService.init(
    builder: () => SleepAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.sleepapp.audio',
      androidNotificationChannelName: 'Sleep Sounds',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(const SleepApp());
}

class SleepApp extends StatelessWidget {
  const SleepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SleepApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PlayerScreen(),
    );
  }
}