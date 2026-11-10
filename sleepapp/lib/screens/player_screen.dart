import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../models/mix_rotation.dart';
import '../models/sound.dart';
import '../models/sound_mix.dart';
import '../services/imported_sound_storage.dart';
import '../services/mix_rotation_storage.dart';
import '../services/mix_storage.dart';
import '../services/sleep_audio_handler.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/mix_rotation_sheet.dart';
import 'library_view.dart';
import 'saved_mixes_view.dart';
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
  StreamSubscription<PlaybackState>? _playbackSubscription;
  int _activeTab = 0;
  bool _isPlaying = false;

  SleepAudioHandler get _audio => widget.audio;

  @override
  void initState() {
    super.initState();
    _sounds = widget.sounds;
    _savedMixes = widget.savedMixes;
    _rotation = widget.rotation;
    _lastPlayedId = widget.lastPlayedId;
    _isPlaying = _audio.isPlaying;
    _hadPlaybackSession = _audio.hasPlaybackSession;
    _playbackSubscription = _audio.playbackState.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.playing && !_switchingMix) _rememberPlayedMix();
      final hasSession = _audio.hasPlaybackSession;
      final sessionEnded = _hadPlaybackSession && !hasSession;
      _hadPlaybackSession = hasSession;
      if (sessionEnded) unawaited(_refreshDefaultMix());
    });
    _lifecycle = AppLifecycleListener(onResume: _onCalendarCheck);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onCalendarCheck();
    });
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
      _showMessage('Could not save mix preferences on this device.');
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
    final name = assigned?.name ?? fallback?.name ?? 'No mix queued';
    final slot = switch (_rotation.mode) {
      MixRotationMode.off => 'Off',
      MixRotationMode.daily => 'Today',
      MixRotationMode.weekly => 'Week ${_rotation.weekIndex(now) + 1}',
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
        title: const Text('Import a sound'),
        content: const Text(
          'Only import audio you own or have permission to use. '
          'You’re responsible for the files you choose. REST keeps a copy '
          'on this device and doesn’t share it.\n\n'
          'Choose an MP3, M4A, or WAV file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (shouldImport != true || !mounted) return false;

    try {
      final sound = await _importedSounds.pickAndImport();
      if (sound == null || !mounted) return false;
      setState(() => _sounds = [sound, ..._sounds]);
      _showMessage('“${sound.name}” added to Imported.');
      return true;
    } on FormatException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      debugPrint('Could not import sound: $error');
      _showMessage('Could not import this sound. Try another file.');
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
      _showMessage('That sound could not be loaded. Try another one.');
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
      _showMessage('Volume could not be changed.');
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
        await _refreshDefaultMix();
        if (!mounted) return;
        if (_audio.selectedSounds.isEmpty) {
          _showMessage('Add a sound to your mix first.');
          return;
        }
        await _audio.play();
        _rememberPlayedMix();
      }
    } catch (error) {
      debugPrint('Playback command failed: $error');
      _showMessage('Playback could not be started.');
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _audio.stop();
    } catch (error) {
      debugPrint('Stop command failed: $error');
      _showMessage('Playback could not be stopped.');
    }
  }

  Future<void> _saveCurrentMix() async {
    final selected = _audio.selectedSounds.toList();
    if (selected.isEmpty) {
      _showMessage('Add a sound before saving a mix.');
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
      _showMessage('“${mix.name}” saved on this device.');
    } catch (error) {
      debugPrint('Could not save mix: $error');
      _showMessage('Could not save this mix on your device.');
    }
  }

  Future<String?> _askForMixName() async {
    final controller = TextEditingController(text: 'My night mix');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A2031),
        title: const Text('Name this mix'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'A name you’ll remember'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save mix'),
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
      if (!await _loadMix(mix, onlyWhenIdle: false)) {
        _showMessage('This mix has no sounds in the current library.');
        return;
      }
      _followRotation = true;
      await _audio.play();
      _rememberPlayedMix();
      _showMessage('Playing “${mix.name}”.');
    } catch (error) {
      debugPrint('Could not load saved mix: $error');
      _showMessage('Could not load this mix.');
    } finally {
      _finishMixChange();
    }
  }

  Future<void> _deleteSavedMix(SoundMix mix) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A2031),
        title: const Text('Delete saved mix?'),
        content: Text('“${mix.name}” will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
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
      _showMessage('Could not delete this mix.');
    }
  }

  Future<void> _showTimer() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111726),
      barrierColor: Colors.black.withValues(alpha: 0.62),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SleepTimerSheet(
        initialState: _audio.sleepTimerState,
        onStart: (duration, fadeOut) async {
          await _audio.startSleepTimer(duration: duration, fadeOut: fadeOut);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        onCancel: () async {
          await _audio.cancelSleepTimer();
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF293149),
        ),
      );
  }

  @override
  void dispose() {
    _dayChange?.cancel();
    _lifecycle.dispose();
    _playbackSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1220),
      body: IndexedStack(index: _activeTab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _activeTab,
        onDestinationSelected: (index) => setState(() => _activeTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.nightlight_outlined),
            selectedIcon: Icon(Icons.nightlight_round),
            label: 'Tonight',
          ),
          NavigationDestination(
            icon: Icon(Icons.graphic_eq_outlined),
            selectedIcon: Icon(Icons.graphic_eq_rounded),
            label: 'Sounds',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Saved',
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
