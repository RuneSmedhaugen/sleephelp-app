import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sleepapp/services/sleep_audio_handler.dart';
import 'package:sleepapp/services/sleep_player.dart';

void main() {
  final handlers = <SleepAudioHandler>[];

  SleepAudioHandler createHandler(
    FakeSleepPlayer player, {
    Duration timerTickInterval = const Duration(milliseconds: 10),
  }) {
    final handler = SleepAudioHandler(
      playerFactory: () => player,
      listenForAudioSessionEvents: false,
      timerTickInterval: timerTickInterval,
    );
    handlers.add(handler);
    return handler;
  }

  tearDown(() async {
    for (final handler in handlers) {
      await handler.dispose();
    }
    handlers.clear();
  });

  test(
    'mixes sound and master volume while play returns for looping audio',
    () async {
      final player = FakeSleepPlayer();
      final handler = createHandler(player);

      await handler.addSound('rain.mp3');
      await handler.setSoundVolume('rain.mp3', 0.4);
      await handler.setMasterVolume(0.5);
      await handler.play().timeout(const Duration(milliseconds: 100));

      expect(player.loadedAsset, 'assets/sounds/rain.mp3');
      expect(handler.selectedSounds, {'rain.mp3'});
      expect(handler.soundVolumes['rain.mp3'], 0.4);
      expect(handler.masterVolume, 0.5);
      expect(player.volume, closeTo(0.2, 0.0001));
      expect(player.playCalls, 1);
      expect(handler.isPlaying, isTrue);

      await handler.pause();
      expect(handler.isPlaying, isFalse);
      expect(player.isPlaying, isFalse);
    },
  );

  test('serializes concurrent adds for the same sound', () async {
    final loadGate = Completer<void>();
    final player = FakeSleepPlayer(loadGate: loadGate);
    final handler = createHandler(player);

    final firstAdd = handler.addSound('rain.mp3');
    final secondAdd = handler.addSound('rain.mp3');
    await Future<void>.delayed(Duration.zero);

    expect(player.loadCalls, 1);
    loadGate.complete();
    await Future.wait([firstAdd, secondAdd]);
    expect(handler.selectedSounds, {'rain.mp3'});
  });

  test('cleans up a player when loading its asset fails', () async {
    final player = FakeSleepPlayer(loadError: StateError('bad asset'));
    final handler = createHandler(player);

    await expectLater(
      handler.addSound('missing.mp3'),
      throwsA(isA<StateError>()),
    );

    expect(player.disposed, isTrue);
    expect(handler.selectedSounds, isEmpty);
  });

  test(
    'removing a sound releases its player and removes it from the mix',
    () async {
      final player = FakeSleepPlayer();
      final handler = createHandler(player);
      await handler.addSound('rain.mp3');
      await handler.play();

      await handler.removeSound('rain.mp3');

      expect(handler.selectedSounds, isEmpty);
      expect(handler.isPlaying, isFalse);
      expect(player.disposed, isTrue);
    },
  );

  test('cleans up a player that fails after playback starts', () async {
    final player = FakeSleepPlayer(playError: StateError('decoder failed'));
    final handler = createHandler(player);
    await handler.addSound('rain.mp3');
    await handler.play();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(handler.selectedSounds, isEmpty);
    expect(handler.isPlaying, isFalse);
    expect(player.disposed, isTrue);
  });

  test('sleep timer fades the mix and stops and rewinds playback', () async {
    final player = FakeSleepPlayer();
    final handler = createHandler(player);
    await handler.addSound('rain.mp3');
    await handler.play();
    await handler.startSleepTimer(
      duration: const Duration(milliseconds: 160),
      fadeOut: const Duration(milliseconds: 160),
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(player.volume, lessThan(1.0));

    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(handler.isPlaying, isFalse);
    expect(handler.sleepTimerState.isCompleted, isTrue);
    expect(player.volume, 0.0);
    expect(player.position, Duration.zero);
  });

  test('sleep timer pauses its countdown with playback', () async {
    final player = FakeSleepPlayer();
    final handler = createHandler(player);
    await handler.addSound('rain.mp3');
    await handler.play();
    await handler.startSleepTimer(
      duration: const Duration(milliseconds: 180),
      fadeOut: Duration.zero,
    );

    await Future<void>.delayed(const Duration(milliseconds: 40));
    await handler.pause();
    final remainingAtPause = handler.sleepTimerState.remaining;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(
      handler.sleepTimerState.remaining.inMilliseconds,
      closeTo(remainingAtPause.inMilliseconds, 2),
    );

    await handler.play();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(handler.sleepTimerState.isCompleted, isTrue);
    expect(player.isPlaying, isFalse);
  });

  test('rejects invalid sleep timer durations', () async {
    final handler = createHandler(FakeSleepPlayer());

    await expectLater(
      handler.startSleepTimer(duration: Duration.zero, fadeOut: Duration.zero),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      handler.startSleepTimer(
        duration: const Duration(seconds: 1),
        fadeOut: const Duration(seconds: 2),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

class FakeSleepPlayer implements SleepPlayer {
  FakeSleepPlayer({this.loadGate, this.loadError, this.playError});

  final Completer<void>? loadGate;
  final Object? loadError;
  final Object? playError;
  final StreamController<bool> _playingChanges =
      StreamController<bool>.broadcast(sync: true);
  final List<double> volumeHistory = [];
  Completer<void>? _playbackCompleter;

  String? loadedAsset;
  Duration position = Duration.zero;
  double volume = 1.0;
  int loadCalls = 0;
  int playCalls = 0;
  bool isPlaying = false;
  bool disposed = false;

  @override
  Stream<bool> get playingStates => _playingChanges.stream;

  @override
  Future<void> loadLoopedAsset(String path) async {
    loadCalls++;
    await loadGate?.future;
    if (loadError != null) throw loadError!;
    loadedAsset = path;
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
    volumeHistory.add(value);
  }

  @override
  Future<void> play() {
    playCalls++;
    if (!isPlaying) {
      isPlaying = true;
      _playingChanges.add(true);
    }
    if (playError != null) return Future<void>.error(playError!);
    _playbackCompleter ??= Completer<void>();
    return _playbackCompleter!.future;
  }

  @override
  Future<void> pause() async {
    _setNotPlaying();
  }

  @override
  Future<void> stop() async {
    _setNotPlaying();
  }

  void _setNotPlaying() {
    if (isPlaying) {
      isPlaying = false;
      _playingChanges.add(false);
    }
    final completion = _playbackCompleter;
    if (completion != null && !completion.isCompleted) completion.complete();
    _playbackCompleter = null;
  }

  @override
  Future<void> seek(Duration value) async {
    position = value;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _setNotPlaying();
    await _playingChanges.close();
  }
}
