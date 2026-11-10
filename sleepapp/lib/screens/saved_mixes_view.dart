import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => SafeArea(
    child: CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
          sliver: SliverList.list(
            children: [
              const Text(
                'Saved for later',
                style: TextStyle(
                  color: Color(0xFFF1F2F7),
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your favorite layers, ready for bedtime.',
                style: TextStyle(color: Color(0xFF929DB2), fontSize: 13),
              ),
              const SizedBox(height: 22),
              if (mixes.isEmpty)
                _EmptySaved(onBrowse: onBrowse)
              else ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  color: const Color(0xFF171D2D),
                  child: ListTile(
                    leading: const Icon(Icons.event_repeat_rounded),
                    title: const Text('Mix rotation'),
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
                  color: const Color(0xFF151C2D),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF9D92D0),
                      size: 18,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Saved on this device. No account needed.',
                        style: TextStyle(
                          color: Color(0xFF9AA4B8),
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

class _EmptySaved extends StatelessWidget {
  const _EmptySaved({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
    decoration: BoxDecoration(
      color: const Color(0xFF171D2D),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF29253F),
          ),
          child: const Icon(
            Icons.bookmark_border_rounded,
            color: Color(0xFFC1B7F0),
            size: 28,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'Your first mix is waiting',
          style: TextStyle(
            color: Color(0xFFF0F2F6),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Combine a few sounds, adjust their levels, then save the mix here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF929DB2),
            height: 1.45,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 19),
        FilledButton.tonalIcon(
          onPressed: onBrowse,
          icon: const Icon(Icons.surround_sound_rounded, size: 18),
          label: const Text('Browse sounds'),
        ),
      ],
    ),
  );
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
    final mixSounds = sounds
        .where((sound) => mix.sounds.contains(sound.file))
        .toList();
    final soundNames = mixSounds.map((sound) => sound.name).join(' · ');
    final firstSound = mixSounds.isEmpty ? null : mixSounds.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171D2D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: firstSound == null
                ? const Icon(
                    Icons.graphic_eq_rounded,
                    color: Color(0xFFB4A8EC),
                    size: 27,
                  )
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
                  style: const TextStyle(
                    color: Color(0xFFF0F2F6),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  soundNames.isEmpty ? 'No sounds available' : soundNames,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF929DB2),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete ${mix.name}',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: const Color(0xFF8792A8),
          ),
          IconButton.filledTonal(
            tooltip: 'Play ${mix.name}',
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
          ),
        ],
      ),
    );
  }
}
