import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';
import '../models/sound.dart';

class SoundIcon extends StatelessWidget {
  const SoundIcon({super.key, required this.sound, this.size = 54});

  final Sound sound;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = RestStyle.of(context).layerAccent(sound.category);

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
