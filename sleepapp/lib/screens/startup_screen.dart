import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/mix_rotation.dart';
import '../models/sound.dart';
import '../models/sound_mix.dart';
import '../services/audio_service.dart';
import '../services/imported_sound_storage.dart';
import '../services/mix_rotation_storage.dart';
import '../services/mix_storage.dart';
import '../services/sleep_audio_handler.dart';
import '../widgets/rest_intro.dart';
import 'player_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

typedef _StartupData = (
  SleepAudioHandler,
  List<Sound>,
  List<SoundMix>,
  (MixRotation, String?),
);

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late final Future<_StartupData> _startup;

  @override
  void initState() {
    super.initState();
    _intro =
        AnimationController(
          vsync: this,
          duration: const Duration(seconds: 5),
          animationBehavior: AnimationBehavior.preserve,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) setState(() {});
        });
    _startup = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro.forward();
    });
  }

  Future<_StartupData> _load() async {
    try {
      return await (
        initializeSleepAudio(),
        _loadSounds(),
        _loadSavedMixes(),
        _loadRotation(),
      ).wait;
    } catch (error) {
      debugPrint('Could not start REST: $error');
      rethrow;
    }
  }

  Future<List<Sound>> _loadSounds() async {
    final json = await rootBundle.loadString('assets/sounds.json');
    final sounds = (jsonDecode(json) as List<dynamic>)
        .map((item) => Sound.fromJson(item as Map<String, dynamic>))
        .toList();
    try {
      sounds.addAll(await ImportedSoundStorage().load());
    } catch (error) {
      debugPrint('Imported sounds are unavailable: $error');
    }
    return sounds;
  }

  Future<List<SoundMix>> _loadSavedMixes() async {
    try {
      return await MixStorage().load();
    } catch (error) {
      debugPrint('Saved mixes are unavailable: $error');
      return [];
    }
  }

  Future<(MixRotation, String?)> _loadRotation() async {
    try {
      return await MixRotationStorage().load();
    } catch (error) {
      debugPrint('Mix rotation is unavailable: $error');
      return (const MixRotation(), null);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupData>(
      future: _startup,
      builder: (context, snapshot) {
        Widget screen = RestIntro(progress: _intro);
        if (_intro.isCompleted) {
          final data = snapshot.data;
          if (data != null) {
            final (audio, sounds, mixes, (rotation, lastPlayedId)) = data;
            screen = PlayerScreen(
              audio: audio,
              sounds: sounds,
              savedMixes: mixes,
              rotation: rotation,
              lastPlayedId: lastPlayedId,
            );
          } else if (snapshot.hasError) {
            screen = const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'REST couldn’t start. Close and reopen the app to try again.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
        }

        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          child: screen,
        );
      },
    );
  }
}
