import 'package:flutter/material.dart';

import '../models/sound.dart';
import '../services/sleep_audio_handler.dart';
import '../widgets/sound_icon.dart';
import '../widgets/sound_layer_card.dart';

class SleepHomeView extends StatelessWidget {
  const SleepHomeView({
    super.key,
    required this.sounds,
    required this.selectedSounds,
    required this.volumes,
    required this.masterVolume,
    required this.isPlaying,
    required this.timerState,
    required this.timerStates,
    required this.onPlayPause,
    required this.onStop,
    required this.onTimer,
    required this.onSaveMix,
    required this.onBrowse,
    required this.onVolumeChanged,
    required this.onMasterVolumeChanged,
    required this.onRemoveSound,
    required this.onAddSound,
  });

  final List<Sound> sounds;
  final Set<String> selectedSounds;
  final Map<String, double> volumes;
  final double masterVolume;
  final bool isPlaying;
  final SleepTimerState timerState;
  final Stream<SleepTimerState> timerStates;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onTimer;
  final VoidCallback onSaveMix;
  final VoidCallback onBrowse;
  final void Function(String file, double volume) onVolumeChanged;
  final ValueChanged<double> onMasterVolumeChanged;
  final ValueChanged<String> onRemoveSound;
  final ValueChanged<Sound> onAddSound;

  @override
  Widget build(BuildContext context) {
    final selected = sounds
        .where((sound) => selectedSounds.contains(sound.file))
        .toList();
    final suggestions = sounds
        .where((sound) => !selectedSounds.contains(sound.file))
        .take(3)
        .toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
          sliver: SliverList.list(
            children: [
              _TopGreeting(onTimer: onTimer),
              const SizedBox(height: 22),
              const _NightHero(),
              const SizedBox(height: 18),
              _TimerCard(
                initialState: timerState,
                states: timerStates,
                onTap: onTimer,
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  const Expanded(child: _SectionTitle('Your soundscape')),
                  TextButton.icon(
                    onPressed: selected.isEmpty ? null : onSaveMix,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (selected.isEmpty)
                _EmptyMixCard(onBrowse: onBrowse)
              else ...[
                _PlaybackCard(
                  isPlaying: isPlaying,
                  count: selected.length,
                  onPlayPause: onPlayPause,
                  onStop: onStop,
                ),
                const SizedBox(height: 12),
                _MasterVolumeCard(
                  value: masterVolume,
                  onChanged: onMasterVolumeChanged,
                ),
                const SizedBox(height: 12),
                for (final sound in selected)
                  SoundLayerCard(
                    sound: sound,
                    volume: volumes[sound.file] ?? 1,
                    onVolumeChanged: (value) =>
                        onVolumeChanged(sound.file, value),
                    onRemove: () => onRemoveSound(sound.file),
                  ),
              ],
              const SizedBox(height: 26),
              Row(
                children: [
                  const Expanded(child: _SectionTitle('Add a layer')),
                  TextButton(onPressed: onBrowse, child: const Text('See all')),
                ],
              ),
              const SizedBox(height: 4),
              if (suggestions.isEmpty)
                const Text(
                  'You have every sound in this collection.',
                  style: TextStyle(color: Color(0xFF929DB2)),
                )
              else
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: suggestions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => _SuggestionCard(
                      sound: suggestions[index],
                      onAdd: () => onAddSound(suggestions[index]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopGreeting extends StatelessWidget {
  const _TopGreeting({required this.onTimer});
  final VoidCallback onTimer;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1C2234),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.nightlight_round,
          color: Color(0xFFB5A8F0),
          size: 21,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NIGHT SOUNDS',
              style: TextStyle(
                color: Color(0xFF8792A8),
                fontSize: 10,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Settle in',
              style: TextStyle(
                color: Color(0xFFF1F2F7),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: onTimer,
        tooltip: 'Sleep timer',
        icon: const Icon(Icons.more_horiz_rounded),
        color: const Color(0xFFAAB3C3),
      ),
    ],
  );
}

class _NightHero extends StatelessWidget {
  const _NightHero();

  @override
  Widget build(BuildContext context) => Container(
    height: 166,
    padding: const EdgeInsets.all(22),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF262B47), Color(0xFF171C30), Color(0xFF151A2B)],
      ),
      border: Border.all(
        color: const Color(0xFF454762).withValues(alpha: 0.38),
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -4,
          top: -24,
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFAFA5E5).withValues(alpha: 0.08),
            ),
          ),
        ),
        Positioned(
          right: 22,
          top: 21,
          child: Icon(
            Icons.nightlight_round,
            color: const Color(0xFFD9D2FF).withValues(alpha: 0.85),
            size: 56,
          ),
        ),
        const Positioned(
          right: 93,
          top: 35,
          child: Icon(Icons.circle, color: Color(0xFF9BA9D4), size: 5),
        ),
        const Positioned(
          right: 42,
          bottom: 24,
          child: Icon(Icons.circle, color: Color(0xFF8EA0C7), size: 4),
        ),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'YOUR QUIETER SPACE',
              style: TextStyle(
                color: Color(0xFFC1B8F3),
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'A little less noise\nfrom the day.',
              style: TextStyle(
                color: Color(0xFFF2F1FA),
                height: 1.12,
                fontSize: 23,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.initialState,
    required this.states,
    required this.onTap,
  });

  final SleepTimerState initialState;
  final Stream<SleepTimerState> states;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => StreamBuilder<SleepTimerState>(
    stream: states,
    initialData: initialState,
    builder: (context, snapshot) {
      final state = snapshot.data ?? initialState;
      final active = state.isActive && !state.isCompleted;
      final title = active ? _formatRemaining(state.remaining) : 'Set a timer';
      final subtitle = active
          ? 'Sound fades gently, then stops'
          : 'Choose when your soundscape ends';

      return Material(
        color: const Color(0xFF151C2D),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9ED9CC).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.hourglass_bottom_rounded,
                    color: Color(0xFF9ED9CC),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFFF0F2F6),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF8D98AC),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF77839A),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: Color(0xFFF0F2F6),
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
  );
}

class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({
    required this.isPlaying,
    required this.count,
    required this.onPlayPause,
    required this.onStop,
  });

  final bool isPlaying;
  final int count;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(17, 12, 10, 12),
    decoration: BoxDecoration(
      color: const Color(0xFF20263A),
      borderRadius: BorderRadius.circular(21),
      border: Border.all(
        color: const Color(0xFFACA2E1).withValues(alpha: 0.11),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFB4A9EE).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
            color: const Color(0xFFC3B9F6),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPlaying ? 'Playing softly' : 'Ready when you are',
                style: const TextStyle(
                  color: Color(0xFFF0F2F6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$count ${count == 1 ? 'layer' : 'layers'} in your mix',
                style: const TextStyle(color: Color(0xFF929DB2), fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: isPlaying ? 'Pause' : 'Play',
          onPressed: onPlayPause,
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 25,
          ),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFB3A8EC),
            foregroundColor: const Color(0xFF17182A),
            fixedSize: const Size(48, 48),
          ),
        ),
        IconButton(
          tooltip: 'Stop and reset',
          onPressed: isPlaying ? onStop : null,
          icon: const Icon(Icons.stop_rounded, size: 22),
          color: const Color(0xFF9BA5B7),
        ),
      ],
    ),
  );
}

class _MasterVolumeCard extends StatelessWidget {
  const _MasterVolumeCard({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(15, 11, 15, 9),
    decoration: BoxDecoration(
      color: const Color(0xFF151C2D),
      borderRadius: BorderRadius.circular(19),
    ),
    child: Row(
      children: [
        const Icon(Icons.tune_rounded, size: 18, color: Color(0xFFAA9EE2)),
        const SizedBox(width: 10),
        const Text(
          'Master',
          style: TextStyle(color: Color(0xFFD9DDE7), fontSize: 13),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, 1.0).toDouble(),
            onChanged: onChanged,
          ),
        ),
        Text(
          '${(value * 100).round()}%',
          style: const TextStyle(color: Color(0xFF929DB2), fontSize: 11),
        ),
      ],
    ),
  );
}

class _EmptyMixCard extends StatelessWidget {
  const _EmptyMixCard({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF171D2D),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
    ),
    child: Row(
      children: [
        const SoundIcon(
          sound: Sound(
            file: '',
            name: 'Quiet',
            category: 'Ambient',
            icon: Icons.spa_rounded,
          ),
          size: 48,
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start with one sound',
                style: TextStyle(
                  color: Color(0xFFF0F2F6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Layer a few favorites into your own mix.',
                style: TextStyle(color: Color(0xFF929DB2), fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onBrowse,
          tooltip: 'Browse sounds',
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    ),
  );
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.sound, required this.onAdd});
  final Sound sound;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    width: 148,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF171D2D),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    ),
    child: Row(
      children: [
        SoundIcon(sound: sound, size: 42),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sound.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE8EAF1),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: Color(0xFFB7ACEF),
                      ),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: Color(0xFFB7ACEF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _formatRemaining(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '$hours hr ${minutes.toString().padLeft(2, '0')} min left';
  }
  return '${duration.inMinutes} min left';
}
