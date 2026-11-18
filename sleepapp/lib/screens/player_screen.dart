import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../models/mix_rotation.dart';
import '../models/rest_style.dart';
import '../models/sound.dart';
import '../models/sound_mix.dart';
import '../services/imported_sound_storage.dart';
import '../services/mix_rotation_storage.dart';
import '../services/mix_storage.dart';
import '../services/sleep_audio_handler.dart';
import '../services/wake_alarms.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/mix_rotation_sheet.dart';
import 'library_view.dart';
import 'alarms_view.dart';
import 'saved_mixes_view.dart';
import 'settings_view.dart';
import 'sleep_home_view.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.audio,
    required this.sounds,
    required this.savedMixes,
    required this.rotation,
    required this.lastPlayedId,
  });

  final SleepAudioHandler audio;
  final List<Sound> sounds;
  final List<SoundMix> savedMixes;
  final MixRotation rotation;
  final String? lastPlayedId;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final MixStorage _mixStorage = MixStorage();
  final MixRotationStorage _rotationStorage = MixRotationStorage();
  final ImportedSoundStorage _importedSounds = ImportedSoundStorage();
  final WakeAlarms _wakeAlarms = WakeAlarms();
  final Set<String> _busySounds = {};
  late List<Sound> _sounds;
  late List<SoundMix> _savedMixes;
  late MixRotation _rotation;
  late String? _lastPlayedId;
  late final AppLifecycleListener _lifecycle;
  Timer? _dayChange;
  String? _loadedMixId;
  bool _followRotation = true;
  bool _switchingMix = false;
  bool _refreshRequested = false;
  bool _hadPlaybackSession = false;
  int? _lastAlarmRing;
  StreamSubscription<PlaybackState>? _playbackSubscription;
  int _activeTab = 0;
  bool _isPlaying = false;

  SleepAudioHandler get _audio => widget.audio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final strings = RestStrings.of(context);
    unawaited(_wakeAlarms.syncLanguage(strings));
    _audio.updateMediaTitle(strings.text(L.playbackTitle));
  }

  @override
  void initState() {
    super.initState();
    _sounds = widget.sounds;
    _savedMixes = widget.savedMixes;
    _rotation = widget.rotation;
    _lastPlayedId = widget.lastPlayedId;
    _isPlaying = _audio.isPlaying;
    _hadPlaybackSession = _audio.hasPlaybackSession;
    _audio.refreshAlarmSchedule = _wakeAlarms.refresh;
    _wakeAlarms.addListener(_syncWakeAlarm);
    _playbackSubscription = _audio.playbackState.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.playing && !_switchingMix) _rememberPlayedMix();
      final hasSession = _audio.hasPlaybackSession;
      _wakeAlarms.setPlaybackSession(hasSession);
      final sessionEnded = _hadPlaybackSession && !hasSession;
      _hadPlaybackSession = hasSession;
      if (sessionEnded) unawaited(_refreshDefaultMix());
    });
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _onCalendarCheck();
        _wakeAlarms.resume();
      },
      onHide: _wakeAlarms.pause,
    );
    _wakeAlarms.resume();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onCalendarCheck();
    });
  }

  void _syncWakeAlarm() {
    if (!_wakeAlarms.ready || !mounted) return;
    final ring = _wakeAlarms.lastRing;
    final didRing =
        _lastAlarmRing != null && ring > 0 && ring != _lastAlarmRing;
    _lastAlarmRing = ring;
    unawaited(
      _audio.updateWakeAlarm(
        _wakeAlarms.nextWake,
        ringing: _wakeAlarms.ringingId != null,
        didRing: didRing,
      ),
    );
    setState(() {});
  }

  bool _canStartPlayback() {
    if (!_wakeAlarms.ready) {
      _showMessage(context.t(L.alarmCheckError));
      return false;
    }
    if (_wakeAlarms.ringingId != null) {
      _showLocalized(L.stopOrSnooze);
      return false;
    }
    if (!_audio.hasPlaybackSession && _audio.previewSleepPlan().blocked) {
      _showMessage(context.t(L.beforePlayPastStop));
      return false;
    }
    return true;
  }

  void _onCalendarCheck() {
    _dayChange?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dayChange = Timer(nextDay.difference(now), _onCalendarCheck);
    setState(() {});
    unawaited(_refreshDefaultMix());
  }

  SoundMix? _savedMix(String? id) {
    for (final mix in _savedMixes) {
      if (mix.id == id) return mix;
    }
    return null;
  }

  void _rememberPlayedMix() {
    final id = _loadedMixId;
    if (id == _lastPlayedId || _savedMix(id) == null) return;
    _lastPlayedId = id;
    unawaited(_saveRotationPreferences());
  }

  Future<void> _saveRotationPreferences() async {
    try {
      await _rotationStorage.save(_rotation, _lastPlayedId);
    } catch (error) {
      debugPrint('Could not save mix rotation: $error');
      _showLocalized(L.rotationSaveError);
    }
  }

  Future<void> _editRotation() async {
    final next = await showModalBottomSheet<MixRotation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MixRotationSheet(rotation: _rotation, mixes: _savedMixes),
    );
    if (next == null || !mounted) return;
    setState(() {
      _rotation = next;
      if (_audio.selectedSounds.isEmpty) _followRotation = true;
    });
    await _saveRotationPreferences();
    if (mounted) await _refreshDefaultMix();
  }

  String get _rotationSummary {
    final now = DateTime.now();
    final assigned = _savedMix(_rotation.assignedMixId(now));
    final fallback = _savedMix(_lastPlayedId);
    final name = assigned?.name ?? fallback?.name ?? context.t(L.noMixQueued);
    final slot = switch (_rotation.mode) {
      MixRotationMode.off => context.t(L.off),
      MixRotationMode.daily => context.t(L.today),
      MixRotationMode.weekly => context.t(L.week, [
        _rotation.weekIndex(now) + 1,
      ]),
    };
    return '$slot · $name';
  }

  Future<void> _refreshDefaultMix() async {
    if (!_followRotation ||
        _busySounds.isNotEmpty ||
        _audio.hasPlaybackSession) {
      return;
    }
    if (_switchingMix) {
      _refreshRequested = true;
      return;
    }
    _switchingMix = true;
    try {
      final ids = {_rotation.assignedMixId(DateTime.now()), _lastPlayedId};
      for (final id in ids) {
        final mix = _savedMix(id);
        if (mix == null) continue;
        if (mix.id == _loadedMixId && _audio.selectedSounds.isNotEmpty) return;
        try {
          if (await _loadMix(mix, onlyWhenIdle: true)) return;
        } catch (error) {
          debugPrint('Could not prepare mix ${mix.id}: $error');
        }
      }
      if (_loadedMixId != null &&
          await _audio.replaceMix({}, {}, onlyWhenIdle: true)) {
        _loadedMixId = null;
      }
    } catch (error) {
      debugPrint('Could not refresh the mix rotation: $error');
    } finally {
      _finishMixChange();
    }
  }

  void _finishMixChange() {
    _switchingMix = false;
    if (!mounted) return;
    if (_audio.isPlaying) _rememberPlayedMix();
    setState(() {});
    if (_refreshRequested) {
      _refreshRequested = false;
      unawaited(_refreshDefaultMix());
    }
  }

  Future<bool> _importSound() async {
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t(L.importTitle)),
        content: Text(
          '${context.t(L.importNotice)}\n\n${context.t(L.chooseAudioFormat)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t(L.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t(L.chooseFile)),
          ),
        ],
      ),
    );
    if (shouldImport != true || !mounted) return false;

    try {
      final sound = await _importedSounds.pickAndImport(
        audioFilesLabel: context.t(L.audioFiles),
      );
      if (sound == null || !mounted) return false;
      setState(() => _sounds = [sound, ..._sounds]);
      _showLocalized(L.soundImported, [sound.name]);
      return true;
    } on SoundImportError catch (error) {
      _showLocalized(switch (error) {
        SoundImportError.unsupportedFormat => L.chooseAudioFormat,
        SoundImportError.emptyFile => L.emptyAudio,
        SoundImportError.unreadable => L.unreadableAudio,
      });
    } catch (error) {
      debugPrint('Could not import sound: $error');
      _showLocalized(L.invalidImport);
    }
    return false;
  }

  Future<void> _toggleSound(Sound sound) async {
    if (_switchingMix || _busySounds.contains(sound.file)) return;
    _followRotation = false;
    _loadedMixId = null;
    setState(() => _busySounds.add(sound.file));
    try {
      if (_audio.selectedSounds.contains(sound.file)) {
        await _audio.removeSound(sound.file);
      } else {
        await _audio.addSound(sound.file, localPath: sound.localPath);
      }
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Could not change sound selection: $error');
      _showLocalized(L.loadedSoundError);
    } finally {
      if (mounted) setState(() => _busySounds.remove(sound.file));
    }
  }

  Future<void> _setSoundVolume(String file, double value) async {
    if (_switchingMix) return;
    _followRotation = false;
    _loadedMixId = null;
    try {
      await _audio.setSoundVolume(file, value);
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Could not change sound volume: $error');
      _showLocalized(L.volumeError);
    }
  }

  Future<void> _setMasterVolume(double value) async {
    await _audio.setMasterVolume(value);
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    if (_switchingMix || _busySounds.isNotEmpty) return;
    try {
      if (_audio.isPlaying) {
        await _audio.pause();
      } else {
        await _wakeAlarms.refresh();
        if (!mounted || !_canStartPlayback()) return;
        await _refreshDefaultMix();
        if (!mounted) return;
        if (_audio.selectedSounds.isEmpty) {
          _showLocalized(L.addSoundFirst);
          return;
        }
        await _audio.play();
        _rememberPlayedMix();
      }
    } catch (error) {
      debugPrint('Playback command failed: $error');
      _showLocalized(L.playError);
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _audio.stop();
    } catch (error) {
      debugPrint('Stop command failed: $error');
      _showLocalized(L.stopError);
    }
  }

  Future<void> _saveCurrentMix() async {
    final selected = _audio.selectedSounds.toList();
    if (selected.isEmpty) {
      _showLocalized(L.addBeforeSave);
      return;
    }

    final name = await _askForMixName();
    if (name == null || name.trim().isEmpty) return;

    final mix = SoundMix(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      sounds: selected,
      volumes: {
        for (final file in selected) file: _audio.soundVolumes[file] ?? 1,
      },
      updatedAt: DateTime.now(),
    );
    final nextMixes = [mix, ..._savedMixes];
    try {
      await _mixStorage.save(nextMixes);
      if (!mounted) return;
      setState(() => _savedMixes = nextMixes);
      _showLocalized(L.mixSaved, [mix.name]);
    } catch (error) {
      debugPrint('Could not save mix: $error');
      _showLocalized(L.mixSaveError);
    }
  }

  Future<String?> _askForMixName() async {
    final controller = TextEditingController(text: context.t(L.nightMix));
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t(L.nameMix)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: context.t(L.nameHint)),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t(L.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(context.t(L.saveMix)),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
  }

  Future<bool> _loadMix(SoundMix mix, {required bool onlyWhenIdle}) async {
    final availableSounds = {for (final sound in _sounds) sound.file: sound};
    final sources = {
      for (final file in mix.sounds)
        if (availableSounds.containsKey(file))
          file: availableSounds[file]!.localPath,
    };
    if (sources.isEmpty) return false;
    final loaded = await _audio.replaceMix(
      sources,
      mix.volumes,
      onlyWhenIdle: onlyWhenIdle,
    );
    if (loaded) _loadedMixId = mix.id;
    return loaded;
  }

  Future<void> _playSavedMix(SoundMix mix) async {
    if (_switchingMix || _busySounds.isNotEmpty) return;
    _switchingMix = true;
    try {
      await _wakeAlarms.refresh();
      if (!mounted || !_canStartPlayback()) return;
      if (!await _loadMix(mix, onlyWhenIdle: false)) {
        _showLocalized(L.mixNoSounds);
        return;
      }
      _followRotation = true;
      await _audio.play();
      _rememberPlayedMix();
      _showLocalized(L.playingMix, [mix.name]);
    } catch (error) {
      debugPrint('Could not load saved mix: $error');
      _showLocalized(L.mixLoadError);
    } finally {
      _finishMixChange();
    }
  }

  Future<void> _deleteSavedMix(SoundMix mix) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t(L.deleteMix)),
        content: Text(context.t(L.deleteMixDetail, [mix.name])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t(L.keepMix)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t(L.delete)),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    final nextMixes = _savedMixes.where((item) => item.id != mix.id).toList();
    try {
      await _mixStorage.save(nextMixes);
      if (!mounted) return;
      setState(() => _savedMixes = nextMixes);
      await _refreshDefaultMix();
    } catch (error) {
      debugPrint('Could not delete saved mix: $error');
      _showLocalized(L.mixDeleteError);
    }
  }

  Future<void> _showTimer() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SleepTimerSheet(
        regularDuration: _audio.regularTimerDuration,
        regularFade: _audio.regularTimerFade,
        offersAlarmPlan: _audio.offersAlarmPlan,
        usesRegularTimerTonight: _audio.usesRegularTimerTonight,
        preview: (duration, fade, follow) => _audio.previewSleepPlan(
          duration: duration,
          fade: fade,
          followAlarm: follow,
        ),
        onFollowAlarm: () async {
          await _audio.followWakeAlarm();
          if (mounted) setState(() {});
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        onStart: (duration, fadeOut) async {
          await _audio.startSleepTimer(duration: duration, fadeOut: fadeOut);
          if (mounted) setState(() {});
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        onCancel: () async {
          await _audio.cancelSleepTimer();
          if (mounted) setState(() {});
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _showLocalized(L key, [List<Object> values = const []]) {
    if (mounted) _showMessage(context.t(key, values));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  void dispose() {
    _dayChange?.cancel();
    _lifecycle.dispose();
    _wakeAlarms.dispose();
    _audio.refreshAlarmSchedule = null;
    _playbackSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    final selected = _audio.selectedSounds;
    final pages = [
      SleepHomeView(
        sounds: _sounds,
        selectedSounds: selected,
        volumes: _audio.soundVolumes,
        masterVolume: _audio.masterVolume,
        isPlaying: _isPlaying,
        hasPlaybackSession: _audio.hasPlaybackSession,
        mixName: _savedMix(_loadedMixId)?.name,
        timerState: _audio.sleepTimerState,
        timerStates: _audio.sleepTimerStates,
        plannedTimer: _audio.previewSleepPlan(),
        onPlayPause: _togglePlayback,
        onStop: _stopPlayback,
        onTimer: _showTimer,
        onSaveMix: _saveCurrentMix,
        onBrowse: () => setState(() => _activeTab = 1),
        onVolumeChanged: _setSoundVolume,
        onMasterVolumeChanged: _setMasterVolume,
        onRemoveSound: (file) {
          final sound = _soundForFile(file);
          if (sound != null) unawaited(_toggleSound(sound));
        },
        onAddSound: (sound) => unawaited(_toggleSound(sound)),
      ),
      LibraryView(
        sounds: _sounds,
        selectedSounds: selected,
        onToggleSound: (sound) => unawaited(_toggleSound(sound)),
        onImport: _importSound,
      ),
      SavedMixesView(
        mixes: _savedMixes,
        sounds: _sounds,
        onPlay: (mix) => unawaited(_playSavedMix(mix)),
        onDelete: (mix) => unawaited(_deleteSavedMix(mix)),
        onBrowse: () => setState(() => _activeTab = 1),
        rotationSummary: _rotationSummary,
        onRotation: _editRotation,
      ),
      AlarmsView(alarms: _wakeAlarms),
      const SettingsView(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.15,
            colors: [style.backgroundHighlight, style.background],
          ),
        ),
        child: Column(
          children: [
            RingingAlarmBanner(alarms: _wakeAlarms),
            Expanded(
              child: IndexedStack(index: _activeTab, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _activeTab,
        onDestinationSelected: (index) => setState(() => _activeTab = index),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.nightlight_outlined),
            selectedIcon: Icon(Icons.nightlight_round),
            label: context.t(L.tonight),
          ),
          NavigationDestination(
            icon: Icon(Icons.graphic_eq_outlined),
            selectedIcon: Icon(Icons.graphic_eq_rounded),
            label: context.t(L.sounds),
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: context.t(L.saved),
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm_on_rounded),
            label: context.t(L.alarms),
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: context.t(L.settings),
          ),
        ],
      ),
    );
  }

  Sound? _soundForFile(String file) {
    for (final sound in _sounds) {
      if (sound.file == file) return sound;
    }
    return null;
  }
}
