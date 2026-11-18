import 'package:material_ui/material_ui.dart';

import '../models/sound.dart';
import 'rest_strings.dart';

extension SoundTranslation on BuildContext {
  String soundName(Sound sound) => switch (sound.file) {
    'birds.mp3' => t(L.birds),
    'fire.mp3' => t(L.fire),
    'ocean.mp3' => t(L.ocean),
    'water.mp3' => t(L.water),
    _ => sound.name,
  };

  String soundCategory(String category) => switch (category) {
    'All' => t(L.all),
    'Nature' => t(L.nature),
    'Water' => t(L.water),
    'Warmth' => t(L.warmth),
    'Ambient' => t(L.ambient),
    Sound.importedCategory => t(L.imported),
    _ => category,
  };
}
