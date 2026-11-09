import 'package:flutter/material.dart';

import '../models/sound.dart';
import 'sound_icon.dart';

class SoundLayerCard extends StatelessWidget {
  const SoundLayerCard({
    super.key,
    required this.sound,
    required this.volume,
    required this.onVolumeChanged,
    required this.onRemove,
  });

  final Sound sound;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF171D2D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SoundIcon(sound: sound, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sound.name,
                      style: const TextStyle(
                        color: Color(0xFFF1F2F7),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sound.category,
                      style: const TextStyle(
                        color: Color(0xFF8994AA),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove ${sound.name}',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 19),
                color: const Color(0xFF929CB0),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Row(
            children: [
              const Icon(
                Icons.volume_down_rounded,
                size: 18,
                color: Color(0xFF8994AA),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: volume.clamp(0.0, 1.0).toDouble(),
                    onChanged: onVolumeChanged,
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${(volume * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xFF9AA4B8),
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}
