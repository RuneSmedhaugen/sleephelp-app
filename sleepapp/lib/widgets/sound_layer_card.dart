import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';
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
    final style = RestStyle.of(context);
    final accent = style.layerAccent(sound.category);
    final sliderAccent = style.volumeAccent ?? accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: style.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.19)),
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
                      style: TextStyle(
                        color: style.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sound.category,
                      style: TextStyle(color: style.quaternary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove ${sound.name}',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 19),
                color: style.quaternary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                Icons.volume_down_rounded,
                size: 18,
                color: style.quaternary,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: sliderAccent,
                    thumbColor: sliderAccent,
                    overlayColor: sliderAccent.withValues(alpha: 0.15),
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
                  style: TextStyle(
                    color: style.quaternary,
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
