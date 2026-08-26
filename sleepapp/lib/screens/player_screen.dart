import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // All sounds loaded from sounds.json
  List<Map<String, dynamic>> _sounds = [];

  // Active AudioPlayers, one for each selected sound
  final Map<String, AudioPlayer> _players = {};

  // Volume for each sound
  final Map<String, double> _volumes = {};

  // Whether each sound has been added
  final Set<String> _selectedSounds = {};

  bool _isPlaying = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/sounds.json');

      final List<dynamic> jsonData = jsonDecode(jsonString);

      setState(() {
        _sounds = jsonData
            .map((sound) => Map<String, dynamic>.from(sound))
            .toList();

        // Default volume for every sound
        for (final sound in _sounds) {
          _volumes[sound['file']] = 1.0;
        }

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load sounds: $e');

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

  final player = AudioPlayer();

final audioContext = AudioContextConfig(
  focus: AudioContextConfigFocus.mixWithOthers,
).build();

await player.setAudioContext(audioContext);

  await player.setReleaseMode(ReleaseMode.loop);
  await player.setVolume(_volumes[file] ?? 1.0);

  setState(() {
    _players[file] = player;
    _selectedSounds.add(file);
  });

  if (_isPlaying) {
    await player.play(
      AssetSource('sounds/$file'),
      volume: _volumes[file] ?? 1.0,
    );

    await player.setReleaseMode(ReleaseMode.loop);
  }
}

  Future<void> _removeSound(String file) async {
    final player = _players[file];

    if (player != null) {
      await player.stop();
      await player.dispose();
    }

    setState(() {
      _players.remove(file);
      _selectedSounds.remove(file);
    });
  }

  Future<void> _togglePlayback() async {
    if (_selectedSounds.isEmpty) {
      return;
    }

    if (_isPlaying) {
      for (final player in _players.values) {
        await player.pause();
      }

      setState(() {
        _isPlaying = false;
      });
    } else {
      for (final entry in _players.entries) {
        await entry.value.play(
          AssetSource('sounds/${entry.key}'),
          volume: _volumes[entry.key] ?? 1.0,
        );

        await entry.value.setReleaseMode(ReleaseMode.loop);
      }

      setState(() {
        _isPlaying = true;
      });
    }
  }

  Future<void> _changeVolume(String file, double value) async {
    setState(() {
      _volumes[file] = value;
    });

    final player = _players[file];

    if (player != null) {
      await player.setVolume(value);
    }
  }

  Future<void> _stopAll() async {
    for (final player in _players.values) {
      await player.stop();

      // Reset the source so resume() starts it again
      final file = _players.entries
          .firstWhere(
            (entry) => entry.value == player,
          )
          .key;

      await player.setSource(
        AssetSource('sounds/$file'),
      );

      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_volumes[file] ?? 1.0);
    }

    setState(() {
      _isPlaying = false;
    });
  }

  @override
  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Sounds'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _sounds.isEmpty
              ? const Center(
                  child: Text('No sounds found.'),
                )
              : Column(
                  children: [
                    const SizedBox(height: 24),

                    // Main play button
                    IconButton(
                      onPressed: _selectedSounds.isEmpty
                          ? null
                          : _togglePlayback,
                      iconSize: 90,
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                      ),
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

                    // Sound list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        itemCount: _sounds.length,
                        itemBuilder: (context, index) {
                          final sound = _sounds[index];

                          final file = sound['file'] as String;
                          final name = sound['name'] as String;
                          final icon = sound['icon'] as String;

                          final isSelected =
                              _selectedSounds.contains(file);

                          final volume =
                              _volumes[file] ?? 1.0;

                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        icon,
                                        style: const TextStyle(
                                          fontSize: 32,
                                        ),
                                      ),

                                      const SizedBox(width: 16),

                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      ElevatedButton(
                                        onPressed: isSelected
                                            ? () =>
                                                _removeSound(file)
                                            : () =>
                                                _addSound(sound),
                                        child: Text(
                                          isSelected
                                              ? 'Remove'
                                              : 'Add',
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (isSelected) ...[
                                    const SizedBox(height: 12),

                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.volume_down,
                                        ),

                                        Expanded(
                                          child: Slider(
                                            value: volume,
                                            min: 0,
                                            max: 1,
                                            onChanged: (value) =>
                                                _changeVolume(
                                              file,
                                              value,
                                            ),
                                          ),
                                        ),

                                        const Icon(
                                          Icons.volume_up,
                                        ),
                                      ],
                                    ),

                                    Text(
                                      '${(volume * 100).round()}%',
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
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