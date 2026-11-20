import 'dart:async';

import 'sleep_player.dart';

class DemoSleepPlayer implements SleepPlayer {
  final _states = StreamController<bool>.broadcast();
  bool _playing = false;
  @override
  bool get isPlaying => _playing;
  @override
  Stream<bool> get playingStates => _states.stream;
  void _set(bool value) {
    _playing = value;
    _states.add(value);
  }

  @override
  Future<void> loadLoopedAsset(String path) async {}
  @override
  Future<void> loadLoopedFile(String path) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> play() async => _set(true);
  @override
  Future<void> pause() async => _set(false);
  @override
  Future<void> stop() async => _set(false);
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> dispose() => _states.close();
}
