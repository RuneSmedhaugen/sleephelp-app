import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class SleepAudioHandler extends BaseAudioHandler {
  final Map<String, AudioPlayer> _players = {};
  final Map<String, double> _volumes = {};

  bool _isPlaying = false;
  double _masterVolume = 1.0;

  double get masterVolume => _masterVolume;

  SleepAudioHandler() {
    // The notification/lock screen represents the whole mixer
    // as one media item.
    mediaItem.add(
      const MediaItem(
        id: 'sleep-mix',
        title: 'Sleep Sounds',
        album: 'SleepApp',
      ),
    );

    _updatePlaybackState();
  }

  // Add a sound to the mixer.
  Future<void> addSound(String file) async {
    if (_players.containsKey(file)) {
      return;
    }

    final player = AudioPlayer();

    await player.setAsset('assets/sounds/$file');
    await player.setLoopMode(LoopMode.one);

    _players[file] = player;
    _volumes[file] = 1.0;

    await player.setVolume(_masterVolume);

    // If the mixer is already playing, the newly added sound
    // should start immediately.
    if (_isPlaying) {
      await player.play();
    }
  }

  // Remove a sound from the mixer.
  Future<void> removeSound(String file) async {
    final player = _players.remove(file);

    if (player != null) {
      await player.stop();
      await player.dispose();
    }

    _volumes.remove(file);

    if (_players.isEmpty) {
      _isPlaying = false;
      _updatePlaybackState();
    }
  }

  // Change the volume of one sound.
  Future<void> setSoundVolume(
    String file,
    double volume,
  ) async {
    final player = _players[file];

    if (player == null) {
      return;
    }

    final clampedVolume = volume.clamp(0.0, 1.0).toDouble();

    _volumes[file] = clampedVolume;

    await player.setVolume(
      clampedVolume * _masterVolume,
    );
  }

  // Change the volume of the entire mix.
  Future<void> setMasterVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0).toDouble();

    await Future.wait(
      _players.entries.map(
        (entry) {
          final soundVolume = _volumes[entry.key] ?? 1.0;

          return entry.value.setVolume(
            soundVolume * _masterVolume,
          );
        },
      ),
    );
  }

  // Play every selected sound simultaneously.
  @override
  Future<void> play() async {
    if (_players.isEmpty) {
      return;
    }

    _isPlaying = true;
    _updatePlaybackState();

    await Future.wait(
      _players.values.map(
        (player) => player.play(),
      ),
    );
  }

  // Pause every selected sound.
  @override
  Future<void> pause() async {
    _isPlaying = false;

    await Future.wait(
      _players.values.map(
        (player) => player.pause(),
      ),
    );

    _updatePlaybackState();
  }

  // Stop every selected sound and reset them.
  @override
  Future<void> stop() async {
    _isPlaying = false;

    await Future.wait(
      _players.values.map(
        (player) => player.stop(),
      ),
    );

    _updatePlaybackState();

    await super.stop();
  }

  void _updatePlaybackState() {
    playbackState.add(
      PlaybackState(
        controls: [
          if (_isPlaying)
            MediaControl.pause
          else
            MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        processingState: AudioProcessingState.ready,
        playing: _isPlaying,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
      ),
    );
  }

  // Clean everything up when the audio service shuts down.
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }

    _players.clear();
    _volumes.clear();
  }
}