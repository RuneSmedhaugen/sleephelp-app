import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../l10n/sound_strings.dart';
import '../models/rest_style.dart';
import '../models/sound.dart';
import '../models/sound_mix.dart';
import '../widgets/sound_icon.dart';

class SavedMixesView extends StatelessWidget {
  const SavedMixesView({
    super.key,
    required this.mixes,
    required this.sounds,
    required this.onPlay,
    required this.onDelete,
    required this.onBrowse,
    required this.rotationSummary,
    required this.onRotation,
  });

  final List<SoundMix> mixes;
  final List<Sound> sounds;
  final ValueChanged<SoundMix> onPlay;
  final ValueChanged<SoundMix> onDelete;
  final VoidCallback onBrowse;
  final String rotationSummary;
  final VoidCallback onRotation;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
            sliver: SliverList.list(
              children: [
                Text(
                  context.t(L.savedForLater),
                  style: TextStyle(
                    color: style.text,
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t(L.savedDescription),
                  style: TextStyle(color: style.quaternary, fontSize: 13),
                ),
                const SizedBox(height: 22),
                if (mixes.isEmpty)
                  _EmptySaved(onBrowse: onBrowse)
                else ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    color: style.panel,
                    child: ListTile(
                      leading: const Icon(Icons.event_repeat_rounded),
                      title: Text(context.t(L.mixRotation)),
                      subtitle: Text(rotationSummary),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: onRotation,
                    ),
                  ),
                  for (final mix in mixes)
                    _SavedMixCard(
                      mix: mix,
                      sounds: sounds,
                      onPlay: () => onPlay(mix),
                      onDelete: () => onDelete(mix),
                    ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: style.panel,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: style.primary,
                        size: 18,
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          context.t(L.savedLocal),
                          style: TextStyle(
                            color: style.quaternary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        color: style.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: style.outline),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: style.tint(style.primary, 0.22),
            ),
            child: Icon(
              Icons.bookmark_border_rounded,
              color: style.text,
              size: 28,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            context.t(L.firstMix),
            style: TextStyle(
              color: style.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            context.t(L.combineSave),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: style.quaternary,
              height: 1.45,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 19),
          FilledButton.tonalIcon(
            onPressed: onBrowse,
            icon: const Icon(Icons.surround_sound_rounded, size: 18),
            label: Text(context.t(L.browseSounds)),
          ),
        ],
      ),
    );
  }
}

class _SavedMixCard extends StatelessWidget {
  const _SavedMixCard({
    required this.mix,
    required this.sounds,
    required this.onPlay,
    required this.onDelete,
  });

  final SoundMix mix;
  final List<Sound> sounds;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    final mixSounds = sounds
        .where((sound) => mix.sounds.contains(sound.file))
        .toList();
    final soundNames = mixSounds.map(context.soundName).join(' · ');
    final firstSound = mixSounds.isEmpty ? null : mixSounds.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: style.outline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: firstSound == null
                ? Icon(Icons.graphic_eq_rounded, color: style.primary, size: 27)
                : SoundIcon(sound: firstSound, size: 56),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mix.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  soundNames.isEmpty
                      ? context.t(L.noAvailableSounds)
                      : soundNames,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: style.quaternary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.t(L.deleteNamed, [mix.name]),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: style.quaternary,
          ),
          IconButton.filledTonal(
            tooltip: context.t(L.playNamed, [mix.name]),
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
          ),
        ],
      ),
    );
  }
}
