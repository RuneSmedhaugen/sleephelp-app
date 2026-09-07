import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/audio_service.dart' as app_audio;

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // All sounds loaded from sounds.json.
  List<Map<String, dynamic>> _sounds = [];

  // Which sounds have been added to the mixer.
  final Set<String> _selectedSounds = {};

  // Volume for each sound.
  final Map<String, double> _volumes = {};

  StreamSubscription<PlaybackState>? _playbackSubscription;

  bool _isPlaying = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _playbackSubscription = app_audio.audioHandler.playbackState.listen((
      state,
    ) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPlaying = state.playing;
      });
    });

    _loadSounds();
  }

  Future<void> _loadSounds() async {
    try {
      final jsonString = await rootBundle.loadString('assets/sounds.json');

      final List<dynamic> jsonData = jsonDecode(jsonString);

      if (!mounted) {
        return;
      }

      setState(() {
        _sounds = jsonData
            .map((sound) => Map<String, dynamic>.from(sound))
            .toList();

        // Default volume for every sound.
        for (final sound in _sounds) {
          _volumes[sound['file'] as String] = 1.0;
        }

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load sounds: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addSound(Map<String, dynamic> sound) async {
    final file = sound['file'] as String;

    if (_selectedSounds.contains(file)) {
      return;
    }

    setState(() {
      _selectedSounds.add(file);
    });

    try {
      await app_audio.audioHandler.addSound(file);
    } catch (e) {
      debugPrint('Failed to add sound: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedSounds.remove(file);
      });
    }
  }

  Future<void> _removeSound(String file) async {
    await app_audio.audioHandler.removeSound(file);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedSounds.remove(file);
    });
  }

  Future<void> _togglePlayback() async {
    if (_selectedSounds.isEmpty) {
      return;
    }

    if (_isPlaying) {
      await app_audio.audioHandler.pause();
    } else {
      await app_audio.audioHandler.play();
    }
  }

  Future<void> _stopPlayback() async {
    await app_audio.audioHandler.stop();
  }

  Future<void> _changeVolume(String file, double value) async {
    setState(() {
      _volumes[file] = value;
    });

    await app_audio.audioHandler.setSoundVolume(file, value);
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep Sounds')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sounds.isEmpty
          ? const Center(child: Text('No sounds found.'))
          : Column(
              children: [
                const SizedBox(height: 24),

                // Main play button.
                IconButton(
                  onPressed: _selectedSounds.isEmpty ? null : _togglePlayback,
                  iconSize: 90,
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                ),

                const SizedBox(height: 4),

                OutlinedButton.icon(
                  onPressed: _selectedSounds.isEmpty ? null : _stopPlayback,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),

                const SizedBox(height: 8),

                Text(
                  _selectedSounds.isEmpty
                      ? 'Add some sounds'
                      : _isPlaying
                      ? 'Playing'
                      : 'Paused',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 24),

                // Sound list.
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _sounds.length,
                    itemBuilder: (context, index) {
                      final sound = _sounds[index];

                      final file = sound['file'] as String;
                      final name = sound['name'] as String;
                      final icon = sound['icon'] as String;

                      final isSelected = _selectedSounds.contains(file);

                      final volume = _volumes[file] ?? 1.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    icon,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: isSelected
                                        ? () => _removeSound(file)
                                        : () => _addSound(sound),
                                    child: Text(isSelected ? 'Remove' : 'Add'),
                                  ),
                                ],
                              ),

                              if (isSelected) ...[
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    const Icon(Icons.volume_down),
                                    Expanded(
                                      child: Slider(
                                        value: volume,
                                        min: 0,
                                        max: 1,
                                        onChanged: (value) =>
                                            _changeVolume(file, value),
                                      ),
                                    ),
                                    const Icon(Icons.volume_up),
                                  ],
                                ),

                                Text(
                                  '${(volume * 100).round()}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
