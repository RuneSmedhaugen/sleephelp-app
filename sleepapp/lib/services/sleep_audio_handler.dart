import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'sleep_player.dart';

/// The single source of truth for the active sound mix and its playback.
///
/// Calls to [play] return once playback has been requested. A looping
/// AudioPlayer's play future otherwise remains pending for the whole session.
class SleepAudioHandler extends BaseAudioHandler {
  SleepAudioHandler({
    SleepPlayer Function()? playerFactory,
    bool listenForAudioSessionEvents = true,
    this._timerTickInterval = const Duration(seconds: 1),
  }) : _playerFactory = playerFactory ?? JustAudioSleepPlayer.new {
    mediaItem.add(
      const MediaItem(id: 'sleep-mix', title: 'Sleep Sounds', album: 'REST'),
    );
    _publishPlaybackState();
    if (listenForAudioSessionEvents) {
      unawaited(_listenForAudioSessionEvents());
    }
  }

  final SleepPlayer Function() _playerFactory;
  final Duration _timerTickInterval;
  final Map<String, SleepPlayer> _players = {};
  final Map<String, double> _soundVolumes = {};
  final Map<String, StreamSubscription<bool>> _playerSubscriptions = {};
  final Map<String, Future<void>> _addOperations = {};
  final StreamController<SleepTimerState> _timerStates =
      StreamController<SleepTimerState>.broadcast();

  final Stopwatch _timerStopwatch = Stopwatch();
  Future<void> _transportTail = Future<void>.value();
  Future<void> _volumeTail = Future<void>.value();
  Timer? _timerTicker;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;

  bool _playIntent = false;
  bool _isPlaying = false;
  bool _hasPlaybackSession = false;
  bool _disposed = false;
  bool _pauseRequested = false;
  bool _resumeAfterInterruption = false;
  double _masterVolume = 1.0;
  double _fadeGain = 1.0;
  Duration? _timerDuration;
  Duration _timerBaseElapsed = Duration.zero;
  Duration _fadeDuration = Duration.zero;
  bool _timerCompleted = false;
  bool _timerTickInProgress = false;
  String? _lastError;

  bool get isPlaying => _isPlaying;
  // A paused mix is still a session and can be resumed from the lock screen.
  bool get hasPlaybackSession => _hasPlaybackSession;
  double get masterVolume => _masterVolume;
  Set<String> get selectedSounds => Set.unmodifiable(_players.keys);
  Map<String, double> get soundVolumes => Map.unmodifiable(_soundVolumes);
  Stream<SleepTimerState> get sleepTimerStates => _timerStates.stream;
  SleepTimerState get sleepTimerState => _currentTimerState();

  /// Add one looped sound. Concurrent requests for the same sound share one
  /// load operation, and a failed load always releases its player.
  Future<void> addSound(String file, {String? localPath}) {
    if (_disposed) {
      return Future.error(StateError('The audio handler has been disposed.'));
    }
    if (_players.containsKey(file)) return Future<void>.value();
    return _addOperations
        .putIfAbsent(file, () async {
          final player = _playerFactory();
          try {
            if (localPath == null) {
              await player.loadLoopedAsset('assets/sounds/$file');
            } else {
              await player.loadLoopedFile(localPath);
            }
            await player.setVolume(_effectiveVolume(file, 1.0));

            if (_disposed) {
              throw StateError('The audio handler has been disposed.');
            }

            _players[file] = player;
            _soundVolumes[file] = 1.0;
            _playerSubscriptions[file] = player.playingStates.listen(
              (_) => _syncPlaybackState(),
              onError: (Object error) =>
                  unawaited(_retirePlayer(file, player, error)),
            );

            await _applyVolumesToAll();
            if (!identical(_players[file], player)) return;
            if (_playIntent) _requestPlay(player, file);
            _lastError = null;
            _publishPlaybackState();
          } catch (_) {
            await _ignorePlayerError(player.dispose);
            rethrow;
          }
        })
        .whenComplete(() => _addOperations.remove(file));
  }

  Future<void> removeSound(String file) =>
      _enqueueTransport(() => _removeSound(file));

  /// Replace the layers as one transport operation so media controls cannot
  /// start or resume audio halfway through an automatic mix change.
  Future<bool> replaceMix(
    Map<String, String?> sources,
    Map<String, double> volumes, {
    required bool onlyWhenIdle,
  }) => _enqueueTransport(() async {
    if (_disposed || (onlyWhenIdle && _hasPlaybackSession)) return false;
    final previous = selectedSounds;
    final target = sources.keys.toSet();
    try {
      for (final file in target.difference(previous)) {
        await addSound(file, localPath: sources[file]);
      }
      if (!_players.keys.toSet().containsAll(target)) {
        throw StateError('One or more mix layers could not be loaded.');
      }
    } catch (_) {
      for (final file in selectedSounds.difference(previous)) {
        await _removeSound(file);
      }
      rethrow;
    }
    for (final file in previous.difference(target)) {
      await _removeSound(file);
    }
    for (final file in target) {
      await setSoundVolume(file, volumes[file] ?? 1);
    }
    return true;
  });

  Future<void> _removeSound(String file) async {
    final addOperation = _addOperations[file];
    if (addOperation != null) {
      try {
        await addOperation;
      } catch (_) {
        return;
      }
    }

    final player = _players.remove(file);
    _soundVolumes.remove(file);
    await _playerSubscriptions.remove(file)?.cancel();
    if (player != null) {
      await _ignorePlayerError(player.stop);
      await _ignorePlayerError(player.dispose);
    }

    if (_players.isEmpty) {
      _playIntent = false;
      _isPlaying = false;
      _hasPlaybackSession = false;
      _cancelSleepTimer(resetFade: true);
    }
    _publishPlaybackState();
  }

  Future<void> setSoundVolume(String file, double volume) async {
    final player = _players[file];
    if (player == null) return;

    final clamped = _clampVolume(volume);
    _soundVolumes[file] = clamped;
    await _enqueueVolumeUpdate(() async {
      if (!identical(_players[file], player)) return;
      try {
        await player.setVolume(
          _effectiveVolume(file, _soundVolumes[file] ?? clamped),
        );
      } catch (error) {
        await _retirePlayer(file, player, error);
        rethrow;
      }
    });
    _publishPlaybackState();
  }

  Future<void> setMasterVolume(double volume) async {
    _masterVolume = _clampVolume(volume);
    await _applyVolumesToAll();
    _publishPlaybackState();
  }

  /// Start a timer whose duration includes its fade-out period.
  /// The clock runs only while sound is playing and pauses with playback.
  Future<void> startSleepTimer({
    required Duration duration,
    required Duration fadeOut,
  }) => _enqueueTransport(
    () => _startSleepTimer(duration: duration, fadeOut: fadeOut),
  );

  Future<void> _startSleepTimer({
    required Duration duration,
    required Duration fadeOut,
  }) async {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'Must be positive.');
    }
    if (fadeOut < Duration.zero || fadeOut > duration) {
      throw ArgumentError.value(
        fadeOut,
        'fadeOut',
        'Must be between zero and the timer duration.',
      );
    }

    _timerTicker?.cancel();
    _timerStopwatch
      ..stop()
      ..reset();
    _timerBaseElapsed = Duration.zero;
    _timerDuration = duration;
    _fadeDuration = fadeOut;
    _timerCompleted = false;
    await _setFadeGain(1.0);
    if (_isPlaying) _resumeTimerClock();
    _publishTimerState();
  }

  Future<void> cancelSleepTimer() =>
      _enqueueTransport(_cancelSleepTimerAndApplyVolume);

  Future<void> _cancelSleepTimerAndApplyVolume() async {
    _cancelSleepTimer(resetFade: true);
    await _applyVolumesToAll();
  }

  @override
  Future<void> play() => _enqueueTransport(_play);

  Future<void> _play() async {
    if (_disposed || _players.isEmpty) return;

    if (_timerCompleted) {
      _cancelSleepTimer(resetFade: true);
      await _applyVolumesToAll();
    }

    _lastError = null;
    _resumeAfterInterruption = false;
    _pauseRequested = false;
    _playIntent = true;
    _isPlaying = true;
    _hasPlaybackSession = true;
    _resumeTimerClock();
    _publishPlaybackState();

    for (final entry in _players.entries.toList()) {
      _requestPlay(entry.value, entry.key);
    }
  }

  @override
  Future<void> pause() {
    _resumeAfterInterruption = false;
    return _enqueueTransport(_pausePlayback);
  }

  Future<void> _pausePlayback() async {
    _pauseRequested = true;
    _playIntent = false;
    _isPlaying = false;
    _pauseTimerClock();
    _publishPlaybackState();
    await _runForAll((_, player) => player.pause());
    _pauseRequested = false;
    _isPlaying = false;
    _pauseTimerClock();
    _publishPlaybackState();
  }

  @override
  Future<void> stop() => _enqueueTransport(_stopPlayback);

  Future<void> _stopPlayback() async {
    _resumeAfterInterruption = false;
    _pauseRequested = true;
    _playIntent = false;
    _isPlaying = false;
    _hasPlaybackSession = false;
    _cancelSleepTimer(resetFade: true);
    await _applyVolumesToAll();
    await _runForAll((_, player) => _stopAndRewind(player));
    _pauseRequested = false;
    await super.stop();
    _publishPlaybackState();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelSleepTimer(resetFade: false);
    try {
      await _transportTail;
      await _volumeTail;
    } catch (_) {
      // Cleanup below still releases any remaining players.
    }
    await Future.wait(
      _addOperations.values.map((operation) async {
        try {
          await operation;
        } catch (_) {
          // A pending load owns its own cleanup path.
        }
      }),
    );
    await _interruptionSubscription?.cancel();
    await _becomingNoisySubscription?.cancel();
    for (final subscription in _playerSubscriptions.values) {
      await subscription.cancel();
    }
    for (final player in _players.values) {
      await _ignorePlayerError(player.stop);
      await _ignorePlayerError(player.dispose);
    }
    _players.clear();
    _soundVolumes.clear();
    await _timerStates.close();
  }

  void _requestPlay(SleepPlayer player, String file) {
    // just_audio's play future completes when playback ends. Do not await a
    // future that is expected to remain pending for a looping sound.
    unawaited(
      player.play().catchError((Object error) async {
        await _retirePlayer(file, player, error);
      }),
    );
  }

  Future<void> _runForAll(
    Future<void> Function(String, SleepPlayer) action,
  ) async {
    await Future.wait(
      _players.entries.map((entry) async {
        try {
          await action(entry.key, entry.value);
        } catch (error) {
          await _retirePlayer(entry.key, entry.value, error);
        }
      }),
    );
  }

  Future<T> _enqueueTransport<T>(Future<T> Function() operation) {
    final result = _transportTail.then((_) => operation());
    _transportTail = result.then<void>(
      (_) {},
      onError: (Object error) => debugPrint('Audio command failed: $error'),
    );
    return result;
  }

  Future<void> _enqueueVolumeUpdate(Future<void> Function() operation) {
    final result = _volumeTail.then((_) => operation());
    _volumeTail = result.catchError((Object error) {
      debugPrint('Audio volume update failed: $error');
    });
    return result;
  }

  Future<void> _retirePlayer(
    String file,
    SleepPlayer player,
    Object error,
  ) async {
    if (!identical(_players[file], player)) return;
    _lastError = 'Could not play $file: $error';
    _players.remove(file);
    _soundVolumes.remove(file);
    await _playerSubscriptions.remove(file)?.cancel();
    await _ignorePlayerError(player.stop);
    await _ignorePlayerError(player.dispose);
    if (_players.isEmpty) {
      _hasPlaybackSession = false;
      _playIntent = false;
      _isPlaying = false;
      _cancelSleepTimer(resetFade: true);
    }
    _publishPlaybackState();
  }

  Future<void> _ignorePlayerError(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      debugPrint('Audio player cleanup failed: $error');
    }
  }

  Future<void> _stopAndRewind(SleepPlayer player) async {
    await player.stop();
    await player.seek(Duration.zero);
  }

  void _syncPlaybackState() {
    if (_disposed) return;
    final anyPlayerPlaying = _players.values.any((player) => player.isPlaying);
    if (anyPlayerPlaying && !_pauseRequested) {
      _isPlaying = true;
      _playIntent = true;
      _resumeTimerClock();
    } else if (!anyPlayerPlaying || _pauseRequested) {
      _isPlaying = false;
      _pauseTimerClock();
    }
    _publishPlaybackState();
  }

  Future<void> _listenForAudioSessionEvents() async {
    try {
      final session = await AudioSession.instance;
      if (_disposed) return;
      _interruptionSubscription = session.interruptionEventStream.listen(
        _handleInterruption,
        onError: (Object error) =>
            debugPrint('Audio interruption error: $error'),
      );
      _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
        if (_isPlaying) unawaited(pause());
      });
    } catch (error) {
      debugPrint('Audio session event setup failed: $error');
    }
  }

  void _handleInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      if (event.type == AudioInterruptionType.duck) {
        unawaited(_applyInterruptionGain(0.25));
      } else {
        _resumeAfterInterruption = _isPlaying;
        if (_resumeAfterInterruption) {
          unawaited(_enqueueTransport(_pausePlayback));
        }
      }
      return;
    }

    if (event.type == AudioInterruptionType.duck) {
      unawaited(_applyInterruptionGain(1.0));
    } else if (event.type == AudioInterruptionType.pause &&
        _resumeAfterInterruption) {
      _resumeAfterInterruption = false;
      unawaited(play());
    } else {
      _resumeAfterInterruption = false;
    }
  }

  double _interruptionGain = 1.0;

  Future<void> _applyInterruptionGain(double gain) async {
    _interruptionGain = gain;
    await _applyVolumesToAll();
  }

  double _effectiveVolume(String file, double volume) =>
      volume * _masterVolume * _fadeGain * _interruptionGain;

  double _clampVolume(double value) => value.clamp(0.0, 1.0).toDouble();

  Future<void> _applyVolumesToAll() async {
    await _enqueueVolumeUpdate(
      () => _runForAll((file, player) {
        return player.setVolume(
          _effectiveVolume(file, _soundVolumes[file] ?? 1.0),
        );
      }),
    );
  }

  Future<void> _setFadeGain(double gain) async {
    _fadeGain = _clampVolume(gain);
    await _applyVolumesToAll();
  }

  void _resumeTimerClock() {
    if (_timerDuration == null ||
        _timerCompleted ||
        _timerStopwatch.isRunning) {
      return;
    }
    _timerStopwatch.start();
    _timerTicker ??= Timer.periodic(
      _timerTickInterval,
      (_) => unawaited(_tickSleepTimer()),
    );
    _publishTimerState();
  }

  void _pauseTimerClock() {
    if (!_timerStopwatch.isRunning) return;
    _timerBaseElapsed += _timerStopwatch.elapsed;
    _timerStopwatch
      ..stop()
      ..reset();
    _timerTicker?.cancel();
    _timerTicker = null;
    _publishTimerState();
  }

  Future<void> _tickSleepTimer() async {
    if (_timerTickInProgress) return;
    final duration = _timerDuration;
    if (duration == null || _timerCompleted || !_timerStopwatch.isRunning) {
      return;
    }

    _timerTickInProgress = true;
    try {
      final elapsed = _elapsedTimer();
      final remaining = duration - elapsed;
      if (remaining <= Duration.zero) {
        await _completeSleepTimer();
        return;
      }

      if (_fadeDuration > Duration.zero && remaining <= _fadeDuration) {
        final progress =
            remaining.inMicroseconds / _fadeDuration.inMicroseconds;
        await _setFadeGain(progress * progress);
      }
      _publishTimerState();
    } finally {
      _timerTickInProgress = false;
    }
  }

  Future<void> _completeSleepTimer() =>
      _enqueueTransport(_completeSleepTimerNow);

  Future<void> _completeSleepTimerNow() async {
    final duration = _timerDuration;
    if (duration == null || _timerCompleted || _elapsedTimer() < duration) {
      return;
    }
    _timerTicker?.cancel();
    _timerTicker = null;
    _timerStopwatch
      ..stop()
      ..reset();
    _timerBaseElapsed = _timerDuration ?? Duration.zero;
    _timerCompleted = true;
    _playIntent = false;
    _isPlaying = false;
    _hasPlaybackSession = false;
    await _setFadeGain(0.0);
    await _runForAll((_, player) => _stopAndRewind(player));
    await super.stop();
    _publishPlaybackState();
    _publishTimerState();
  }

  Duration _elapsedTimer() => _timerBaseElapsed + _timerStopwatch.elapsed;

  SleepTimerState _currentTimerState() {
    final duration = _timerDuration;
    if (duration == null) return const SleepTimerState.inactive();
    final remaining = duration - _elapsedTimer();
    return SleepTimerState(
      duration: duration,
      remaining: remaining.isNegative ? Duration.zero : remaining,
      fadeOut: _fadeDuration,
      isRunning: _timerStopwatch.isRunning,
      isCompleted: _timerCompleted,
    );
  }

  void _publishTimerState() {
    if (!_timerStates.isClosed) _timerStates.add(_currentTimerState());
  }

  void _cancelSleepTimer({required bool resetFade}) {
    _timerTicker?.cancel();
    _timerTicker = null;
    _timerStopwatch
      ..stop()
      ..reset();
    _timerDuration = null;
    _timerBaseElapsed = Duration.zero;
    _fadeDuration = Duration.zero;
    _timerCompleted = false;
    if (resetFade) _fadeGain = 1.0;
    _publishTimerState();
  }

  void _publishPlaybackState() {
    playbackState.add(
      PlaybackState(
        controls: [
          if (_isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        processingState: _lastError == null || _players.isNotEmpty
            ? AudioProcessingState.ready
            : AudioProcessingState.error,
        playing: _isPlaying,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
        errorMessage: _lastError,
      ),
    );
  }
}

/// Observable sleep timer state for the future player views.
class SleepTimerState {
  const SleepTimerState({
    required this.duration,
    required this.remaining,
    required this.fadeOut,
    required this.isRunning,
    required this.isCompleted,
  });

  const SleepTimerState.inactive()
    : duration = null,
      remaining = Duration.zero,
      fadeOut = Duration.zero,
      isRunning = false,
      isCompleted = false;

  final Duration? duration;
  final Duration remaining;
  final Duration fadeOut;
  final bool isRunning;
  final bool isCompleted;

  bool get isActive => duration != null;
}
