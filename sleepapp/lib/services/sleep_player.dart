import 'package:just_audio/just_audio.dart';

/// Small audio port that lets the mixer be exercised without native plugins.
abstract interface class SleepPlayer {
  bool get isPlaying;
  Stream<bool> get playingStates;

  Future<void> loadLoopedAsset(String path);
  Future<void> setVolume(double volume);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class JustAudioSleepPlayer implements SleepPlayer {
  JustAudioSleepPlayer() : _player = AudioPlayer(handleInterruptions: false);

  final AudioPlayer _player;

  @override
  bool get isPlaying => _player.playing;

  @override
  Stream<bool> get playingStates => _player.playingStream;

  @override
  Future<void> loadLoopedAsset(String path) async {
    await _player.setAsset(path);
    await _player.setLoopMode(LoopMode.one);
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
