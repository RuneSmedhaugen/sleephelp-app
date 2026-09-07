import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class SleepAudioHandler extends BaseAudioHandler {
  final Map<String, AudioPlayer> _players = {};
  final Map<String, double> _volumes = {};

  bool _isPlaying = false;

  SleepAudioHandler() {
    // Tell Android/iOS what our app is currently doing.
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.play,
          MediaControl.pause,
          MediaControl.stop,
        ],
        processingState: AudioProcessingState.ready,
        playing: false,
      ),
    );
  }

  /// Add a sound to the mixer.
  Future<void> addSound(String file) async {
    if (_players.containsKey(file)) {
      return;
    }

    final player = AudioPlayer();

    await player.setAsset('assets/sounds/$file');

    // Each individual sound loops forever.
    await player.setLoopMode(LoopMode.one);

    // Start at full volume unless changed later.
    await player.setVolume(1.0);

    _players[file] = player;
    _volumes[file] = 1.0;
  }

  /// Remove a sound from the mixer.
  Future<void> removeSound(String file) async {
    final player = _players.remove(file);

    if (player != null) {
      await player.stop();
      await player.dispose();
    }

    _volumes.remove(file);

    // If there are no sounds left, we're not playing.
    if (_players.isEmpty) {
      _isPlaying = false;
      _updatePlaybackState();
    }
  }

  /// Change the volume of one sound.
  Future<void> setSoundVolume(String file, double volume) async {
    final player = _players[file];

    if (player == null) {
      return;
    }

    final clampedVolume = volume.clamp(0.0, 1.0).toDouble();

    _volumes[file] = clampedVolume;

    await player.setVolume(clampedVolume);
  }

  /// Play every selected sound simultaneously.
  @override
  Future<void> play() async {
    if (_players.isEmpty) {
      return;
    }

    _isPlaying = true;
    _updatePlaybackState();

    await Future.wait(
      _players.values.map((player) => player.play()),
    );
  }

  /// Pause every selected sound.
  @override
  Future<void> pause() async {
    _isPlaying = false;

    await Future.wait(
      _players.values.map((player) => player.pause()),
    );

    _updatePlaybackState();
  }

  /// Stop every selected sound and reset them to the beginning.
  @override
  Future<void> stop() async {
    _isPlaying = false;

    await Future.wait(
      _players.values.map((player) => player.stop()),
    );

    _updatePlaybackState();

    await super.stop();
  }

  void _updatePlaybackState() {
    playbackState.add(
      PlaybackState(
        controls: [
          if (_isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        processingState: AudioProcessingState.ready,
        playing: _isPlaying,
      ),
    );
  }

  /// Clean everything up when the audio service shuts down.
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }

    _players.clear();
    _volumes.clear();
  }
}