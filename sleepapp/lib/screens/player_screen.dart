import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../models/sound.dart';
import '../models/sound_mix.dart';
import '../services/mix_storage.dart';
import '../services/sleep_audio_handler.dart';
import '../widgets/sleep_timer_sheet.dart';
import 'library_view.dart';
import 'saved_mixes_view.dart';
import 'sleep_home_view.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.audio,
    required this.sounds,
    required this.savedMixes,
  });

  final SleepAudioHandler audio;
  final List<Sound> sounds;
  final List<SoundMix> savedMixes;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final MixStorage _mixStorage = MixStorage();
  final Set<String> _busySounds = {};
  late List<SoundMix> _savedMixes;
  StreamSubscription<PlaybackState>? _playbackSubscription;
  int _activeTab = 0;
  bool _isPlaying = false;

  SleepAudioHandler get _audio => widget.audio;
  List<Sound> get _sounds => widget.sounds;

  @override
  void initState() {
    super.initState();
    _savedMixes = widget.savedMixes;
    _isPlaying = _audio.isPlaying;
    _playbackSubscription = _audio.playbackState.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
    });
  }

  Future<void> _toggleSound(Sound sound) async {
    if (_busySounds.contains(sound.file)) return;
    setState(() => _busySounds.add(sound.file));
    try {
      if (_audio.selectedSounds.contains(sound.file)) {
        await _audio.removeSound(sound.file);
      } else {
        await _audio.addSound(sound.file);
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
    if (_audio.selectedSounds.isEmpty) {
      _showMessage('Add a sound to your mix first.');
      return;
    }
    try {
      if (_audio.isPlaying) {
        await _audio.pause();
      } else {
        await _audio.play();
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

  Future<void> _playSavedMix(SoundMix mix) async {
    final availableFiles = _sounds.map((sound) => sound.file).toSet();
    final target = mix.sounds.where(availableFiles.contains).toSet();
    if (target.isEmpty) {
      _showMessage('This mix has no sounds in the current library.');
      return;
    }

    try {
      for (final file in _audio.selectedSounds.difference(target).toList()) {
        await _audio.removeSound(file);
      }
      for (final file in target.difference(_audio.selectedSounds)) {
        await _audio.addSound(file);
      }
      for (final entry in mix.volumes.entries) {
        if (target.contains(entry.key)) {
          await _audio.setSoundVolume(entry.key, entry.value);
        }
      }
      await _audio.play();
      if (mounted) setState(() {});
      _showMessage('Playing “${mix.name}”.');
    } catch (error) {
      debugPrint('Could not load saved mix: $error');
      _showMessage('Could not load this mix.');
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
    if (shouldDelete != true) return;

    final nextMixes = _savedMixes.where((item) => item.id != mix.id).toList();
    try {
      await _mixStorage.save(nextMixes);
      if (mounted) setState(() => _savedMixes = nextMixes);
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
      ),
      SavedMixesView(
        mixes: _savedMixes,
        sounds: _sounds,
        onPlay: (mix) => unawaited(_playSavedMix(mix)),
        onDelete: (mix) => unawaited(_deleteSavedMix(mix)),
        onBrowse: () => setState(() => _activeTab = 1),
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
