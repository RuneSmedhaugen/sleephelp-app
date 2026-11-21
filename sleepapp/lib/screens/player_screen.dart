import 'dart:async';

import 'package:flutter/foundation.dart';

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
import '../widgets/rest_artwork.dart';
import '../widgets/mix_name_dialog.dart';
import '../widgets/mix_editor_sheet.dart';
import '../widgets/mix_rotation_sheet.dart';
import 'library_view.dart';
import 'alarms_view.dart';
import 'saved_mixes_view.dart';
import 'bedside_preview.dart';
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
    this.demoMode = false,
  });

  final SleepAudioHandler audio;
  final List<Sound> sounds;
  final List<SoundMix> savedMixes;
  final MixRotation rotation;
  final String? lastPlayedId;
  final bool demoMode;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final MixStorage _mixStorage = MixStorage();
  final MixRotationStorage _rotationStorage = MixRotationStorage();
  final ImportedSoundStorage _importedSounds = ImportedSoundStorage();
  final WakeAlarms _wakeAlarms = WakeAlarms();
  Future<void> _mixWriteTail = Future<void>.value();
  final Set<String> _busySounds = {};
  late List<Sound> _sounds;
  late List<SoundMix> _savedMixes;
  late MixRotation _rotation;
  late String? _lastPlayedId;
  late final AppLifecycleListener _lifecycle;
  Timer? _dayChange;
  String? _loadedMixId;
  DateTime? _loadedMixUpdatedAt;
  bool _followRotation = true;
  bool _switchingMix = false;
  bool _refreshRequested = false;
  bool _hadPlaybackSession = false;
  int? _lastAlarmRing;
  StreamSubscription<PlaybackState>? _playbackSubscription;
  int _activeTab = 0;
  bool _isPlaying = false;

  SleepAudioHandler get _audio => widget.audio;

  bool get _currentMixChanged {
    final saved = _savedMix(_loadedMixId);
    final selected = _audio.selectedSounds;
    if (saved == null) return selected.isNotEmpty;
    return !setEquals(selected, saved.sounds.toSet()) ||
        selected.any(
          (file) =>
              (_audio.soundVolumes[file] ?? 1) != (saved.volumes[file] ?? 1),
        );
  }

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
    if (_savedMix(id) == null || _currentMixChanged) return;
    _followRotation = true;
    if (id == _lastPlayedId) return;
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
        if (mix.id == _loadedMixId &&
            mix.updatedAt == _loadedMixUpdatedAt &&
            _audio.selectedSounds.isNotEmpty) {
          return;
        }
        try {
          if (await _loadMix(mix, onlyWhenIdle: true)) return;
        } catch (error) {
          debugPrint('Could not prepare mix ${mix.id}: $error');
        }
      }
      if (_loadedMixId != null &&
          await _audio.replaceMix(
            {},
            {},
            onlyWhenIdle: true,
            restoreTimer: true,
          )) {
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

  Future<String?> _askForMixName({
    String? initialName,
    L title = L.nameMix,
    L confirmLabel = L.saveMix,
  }) => showDialog<String>(
    context: context,
    builder: (dialogContext) => MixNameDialog(
      initialName: initialName ?? dialogContext.t(L.nightMix),
      title: title,
      confirmLabel: confirmLabel,
    ),
  );

  Future<void> _changeSavedMixes(
    List<SoundMix> Function(List<SoundMix>) change,
  ) {
    final write = _mixWriteTail.then((_) async {
      final next = change(_savedMixes);
      await _mixStorage.save(next);
      if (mounted) setState(() => _savedMixes = next);
    });
    _mixWriteTail = write.catchError((Object _) {});
    return write;
  }

  Future<void> _storeMix(SoundMix mix) => _changeSavedMixes((current) {
    final index = current.indexWhere((item) => item.id == mix.id);
    final next = [...current];
    if (index < 0) {
      next.insert(0, mix);
    } else {
      next[index] = mix;
    }
    return next;
  });

  Future<void> _renameSavedMix(SoundMix mix) async {
    final name = await _askForMixName(
      initialName: mix.name,
      title: L.renameMix,
      confirmLabel: L.save,
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    try {
      final current = _savedMix(mix.id);
      if (current == null) return;
      final renamed = current.copyWith(
        name: name.trim(),
        updatedAt: DateTime.now(),
      );
      await _storeMix(renamed);
      _showLocalized(L.mixUpdated, [renamed.name]);
    } catch (error) {
      debugPrint('Could not rename mix: $error');
      _showLocalized(L.mixSaveError);
    }
  }

  Future<void> _duplicateSavedMix(SoundMix mix) async {
    final suffixLength = context.t(L.copyName, ['']).characters.length;
    final baseName = mix.name.characters.take(32 - suffixLength).toString();
    final name = await _askForMixName(
      initialName: context.t(L.copyName, [baseName]),
      title: L.duplicateMix,
      confirmLabel: L.saveAsNewMix,
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    try {
      final copy = mix.copyWith(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        updatedAt: DateTime.now(),
      );
      await _storeMix(copy);
      _showLocalized(L.mixSaved, [copy.name]);
    } catch (error) {
      debugPrint('Could not duplicate mix: $error');
      _showLocalized(L.mixSaveError);
    }
  }

  Future<void> _editSavedMix(SoundMix mix) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => MixEditorSheet(
      mix: mix,
      sounds: _sounds,
      suggestedTimer: MixTimerSettings(
        duration: _audio.regularTimerDuration,
        fade: _audio.regularTimerFade,
      ),
      requestName: (initialName) => _askForMixName(initialName: initialName),
      onSave: (draft, saveAsNew) async {
        final saved = saveAsNew
            ? draft.copyWith(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
              )
            : draft;
        try {
          await _storeMix(saved);
          _showLocalized(saveAsNew ? L.mixSaved : L.mixUpdated, [saved.name]);
          return true;
        } catch (error) {
          debugPrint('Could not save edited mix: $error');
          return false;
        }
      },
    ),
  );

  Future<bool> _unloadCurrentMix() async {
    if (_switchingMix || _busySounds.isNotEmpty) return false;
    _switchingMix = true;
    _followRotation = false;
    try {
      await _audio.stop();
      final cleared = await _audio.replaceMix(
        {},
        {},
        onlyWhenIdle: true,
        restoreTimer: true,
      );
      if (!cleared) return false;
      _loadedMixId = null;
      _loadedMixUpdatedAt = null;
      _showLocalized(L.mixUnloaded);
      return true;
    } catch (error) {
      debugPrint('Could not unload current mix: $error');
      return false;
    } finally {
      _finishMixChange();
    }
  }

  Future<void> _openMixer() async {
    if (_switchingMix) return;
    _followRotation = false;
    final original = _savedMix(_loadedMixId);
    final timer = MixTimerSettings(
      duration: _audio.regularTimerDuration,
      fade: _audio.regularTimerFade,
    );
    final current = SoundMix(
      id: original?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: original?.name ?? context.t(L.yourSoundMix),
      sounds: _audio.selectedSounds.toList(),
      volumes: _audio.soundVolumes,
      updatedAt: DateTime.now(),
      timer: original?.timer,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MixEditorSheet(
        mix: current,
        originalMix: original,
        isSavedMix: original != null,
        sounds: _sounds,
        suggestedTimer: timer,
        requestName: (initialName) => _askForMixName(initialName: initialName),
        onUnload: _unloadCurrentMix,
        onSoundToggle: (sound) async {
          await _toggleSound(sound);
          return _audio.selectedSounds.contains(sound.file);
        },
        onVolumeChanged: (file, value) async {
          await _setSoundVolume(file, value);
          return _audio.soundVolumes[file] ?? 1;
        },
        onSave: (draft, saveAsNew) async {
          final saved = saveAsNew || original == null
              ? draft.copyWith(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                )
              : draft;
          try {
            await _storeMix(saved);
            if (!mounted) return true;
            setState(() {
              _loadedMixId = saved.id;
              _loadedMixUpdatedAt = saved.updatedAt;
            });
            if (_audio.isPlaying) _rememberPlayedMix();
            _showLocalized(L.mixSaved, [saved.name]);
            return true;
          } catch (error) {
            debugPrint('Could not save current mixer: $error');
            return false;
          }
        },
      ),
    );
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
      timer: mix.timer,
      restoreTimer: true,
    );
    if (loaded) {
      _loadedMixId = mix.id;
      _loadedMixUpdatedAt = mix.updatedAt;
    }
    return loaded;
  }

  Future<void> _loadSavedMix(SoundMix mix) async {
    if (_switchingMix || _busySounds.isNotEmpty) return;
    _switchingMix = true;
    _followRotation = false;
    try {
      await _wakeAlarms.refresh();
      if (!mounted) return;
      await _audio.stop();
      if (!await _loadMix(mix, onlyWhenIdle: true)) {
        _showLocalized(L.mixNoSounds);
        return;
      }
      if (mounted) setState(() => _activeTab = 0);
      _showLocalized(L.mixLoaded, [mix.name]);
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

    try {
      await _changeSavedMixes(
        (current) => current.where((item) => item.id != mix.id).toList(),
      );
      if (!mounted) return;
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
        preview: (duration, fade) =>
            _audio.previewSleepPlan(duration: duration, fade: fade),
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
        selectedSoundCount: selected.length,
        masterVolume: _audio.masterVolume,
        isPlaying: _isPlaying,
        hasPlaybackSession: _audio.hasPlaybackSession,
        mixName: _savedMix(_loadedMixId)?.name,
        hasUnsavedChanges: _currentMixChanged,
        timerState: _audio.sleepTimerState,
        timerStates: _audio.sleepTimerStates,
        plannedTimer: _audio.previewSleepPlan(),
        onPlayPause: _togglePlayback,
        onStop: _stopPlayback,
        onTimer: _showTimer,
        onOpenMixer: _openMixer,
        onMasterVolumeChanged: _setMasterVolume,
      ),
      LibraryView(
        sounds: _sounds,
        selectedSounds: selected,
        onToggleSound: (sound) => unawaited(_toggleSound(sound)),
        onImport: widget.demoMode ? null : _importSound,
      ),
      SavedMixesView(
        mixes: _savedMixes,
        sounds: _sounds,
        onLoad: (mix) => unawaited(_loadSavedMix(mix)),
        onDelete: (mix) => unawaited(_deleteSavedMix(mix)),
        onEdit: (mix) => unawaited(_editSavedMix(mix)),
        onRename: (mix) => unawaited(_renameSavedMix(mix)),
        onDuplicate: (mix) => unawaited(_duplicateSavedMix(mix)),
        onBrowse: () => setState(() => _activeTab = 1),
        rotationSummary: _rotationSummary,
        onRotation: _editRotation,
      ),
      AlarmsView(alarms: _wakeAlarms),
      const SettingsView(),
      if (widget.demoMode)
        BedsidePreview(
          visible: _activeTab == 5,
          isPlaying: _isPlaying,
          onPlayPause: _togglePlayback,
          onStop: _stopPlayback,
          mixName: _savedMix(_loadedMixId)?.name,
          alarmAt: _wakeAlarms.nextWake?.ringsAt,
        ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RestArtworkPanel(
        style: style,
        fullScene: true,
        child: Column(
          children: [
            if (widget.demoMode)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    switch (Localizations.localeOf(context).languageCode) {
                      'nb' => 'Nettleserdemo: ingen lyd. Alarmer vises bare mens siden er åpen.',
                      'fr' => 'Démo web : sans son. Les alarmes fonctionnent uniquement lorsque la page est ouverte.',
                      'es' => 'Demo web: sin sonido. Las alarmas solo funcionan con la página abierta.',
                      'de' => 'Webdemo: ohne Ton. Wecker funktionieren nur bei geöffneter Seite.',
                      _ => 'Browser demo: no sound. Alarms work only while this page is open.',
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(color: style.text, fontSize: 11),
                  ),
                ),
              ),
            RingingAlarmBanner(alarms: _wakeAlarms),
            Expanded(
              child: IndexedStack(index: _activeTab, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _activeTab,
        labelBehavior: widget.demoMode
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
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
          if (widget.demoMode)
            NavigationDestination(
              icon: const Icon(Icons.bedtime_outlined),
              selectedIcon: const Icon(Icons.bedtime_rounded),
              label: context.t(L.bedsideView),
            ),
        ],
      ),
    );
  }
}
