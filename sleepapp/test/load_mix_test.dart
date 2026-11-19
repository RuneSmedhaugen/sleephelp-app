import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sleepapp/l10n/rest_strings.dart';
import 'package:sleepapp/models/mix_rotation.dart';
import 'package:sleepapp/models/sound.dart';
import 'package:sleepapp/models/sound_mix.dart';
import 'package:sleepapp/screens/player_screen.dart';
import 'package:sleepapp/services/sleep_audio_handler.dart';

import 'sleep_audio_handler_test.dart' show FakeSleepPlayer;

void main() {
  testWidgets(
    'Load stops the previous mix, restores the timer and opens Tonight silently',
    (tester) async {
      const alarms = MethodChannel('rest/alarms');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        alarms,
        (call) async => call.method == 'status'
            ? {
                'alarms': [],
                'permissions': ['unsupported'],
              }
            : null,
      );
      final players = <FakeSleepPlayer>[];
      final handler = SleepAudioHandler(
        playerFactory: () {
          final player = FakeSleepPlayer();
          players.add(player);
          return player;
        },
        listenForAudioSessionEvents: false,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(handler.dispose);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          alarms,
          null,
        );
      });
      await handler.addSound('birds.mp3');
      await handler.play();
      final mix = SoundMix(
        id: 'overnight',
        name: 'Overnight',
        sounds: ['ocean.mp3'],
        volumes: {'ocean.mp3': 0.4},
        updatedAt: DateTime(2026, 11, 18),
        timer: const MixTimerSettings(
          duration: Duration(hours: 8),
          fade: Duration(minutes: 10),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: [
            RestStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: PlayerScreen(
            audio: handler,
            sounds: const [
              Sound(
                file: 'birds.mp3',
                name: 'Birds',
                category: 'Nature',
                icon: Icons.forest,
              ),
              Sound(
                file: 'ocean.mp3',
                name: 'Ocean',
                category: 'Water',
                icon: Icons.waves,
              ),
            ],
            savedMixes: [mix],
            rotation: const MixRotation(),
            lastPlayedId: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final restored = handler.sleepTimerStates.firstWhere(
          (_) => handler.regularTimerDuration == const Duration(hours: 8),
        );
        await tester.tap(find.byTooltip('Load Overnight'));
        for (
          var frame = 0;
          frame < 50 && handler.selectedSounds.contains('birds.mp3');
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await restored.timeout(const Duration(seconds: 3));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(handler.selectedSounds, {'ocean.mp3'});
      expect(handler.regularTimerDuration, const Duration(hours: 8));
      expect(handler.regularTimerFade, const Duration(minutes: 10));
      expect(handler.isPlaying, isFalse);
      expect(handler.hasPlaybackSession, isFalse);
      expect(
        players.fold<int>(0, (count, player) => count + player.playCalls),
        1,
      );
      expect(handler.previewSleepPlan().playFor!.inSeconds, closeTo(28800, 1));
      expect(tester.takeException(), isNull);
    },
  );
}
