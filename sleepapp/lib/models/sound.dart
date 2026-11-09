import 'package:flutter/material.dart';

class Sound {
  const Sound({
    required this.file,
    required this.name,
    required this.icon,
    required this.category,
  });

  final String file;
  final String name;
  final IconData icon;
  final String category;

  factory Sound.fromJson(Map<String, dynamic> json) {
    final file = json['file'] as String;
    final name = json['name'] as String;
    return Sound(
      file: file,
      name: name,
      icon: _iconFor(file),
      category: _categoryFor(file),
    );
  }

  static IconData _iconFor(String file) => switch (file) {
    'birds.mp3' => Icons.forest_rounded,
    'fire.mp3' => Icons.local_fire_department_rounded,
    'ocean.mp3' => Icons.waves_rounded,
    'water.mp3' => Icons.water_drop_rounded,
    _ => Icons.graphic_eq_rounded,
  };

  static String _categoryFor(String file) => switch (file) {
    'birds.mp3' => 'Nature',
    'fire.mp3' => 'Warmth',
    'ocean.mp3' || 'water.mp3' => 'Water',
    _ => 'Ambient',
  };
}
