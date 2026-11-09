import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import 'sleep_audio_handler.dart';

Future<SleepAudioHandler> initializeSleepAudio() async {
  final handler = await AudioService.init(
    builder: SleepAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.sleepapp.audio',
      androidNotificationChannelName: 'Sleep Sounds',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration.music());
  return handler;
}
