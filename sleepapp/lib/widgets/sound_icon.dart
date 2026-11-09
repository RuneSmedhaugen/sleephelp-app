import 'package:flutter/material.dart';

import '../models/sound.dart';

class SoundIcon extends StatelessWidget {
  const SoundIcon({super.key, required this.sound, this.size = 54});

  final Sound sound;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = switch (sound.category) {
      'Nature' => const Color(0xFF9CC9B3),
      'Warmth' => const Color(0xFFE3A884),
      'Water' => const Color(0xFF8EBDE1),
      _ => const Color(0xFFB4A5E8),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(sound.icon, color: color, size: size * 0.43),
    );
  }
}
