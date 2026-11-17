import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';
import '../models/sound.dart';
import '../models/wake_playback.dart';
import '../services/sleep_audio_handler.dart';
import '../widgets/sound_icon.dart';
import '../widgets/sound_layer_card.dart';
import '../widgets/tonight_timer_card.dart';

class SleepHomeView extends StatelessWidget {
  const SleepHomeView({
    super.key,
    required this.sounds,
    required this.selectedSounds,
    required this.volumes,
    required this.masterVolume,
    required this.isPlaying,
    required this.hasPlaybackSession,
    required this.mixName,
    required this.timerState,
    required this.timerStates,
    required this.plannedTimer,
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
  final bool hasPlaybackSession;
  final String? mixName;
  final SleepTimerState timerState;
  final Stream<SleepTimerState> timerStates;
  final SleepPlan plannedTimer;
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
    final style = RestStyle.of(context);
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
              const _TopGreeting(),
              const SizedBox(height: 22),
              TonightTimerCard(
                initialState: timerState,
                states: timerStates,
                plan: plannedTimer,
                hasPlaybackSession: hasPlaybackSession,
                isPlaying: isPlaying,
                onChange: onTimer,
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
                  canStop: hasPlaybackSession,
                  mixName: mixName,
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
                Text(
                  'You have every sound in this collection.',
                  style: TextStyle(color: style.quaternary),
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
  const _TopGreeting();

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: style.raised,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.nightlight_round, color: style.primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NIGHT SOUNDS',
                style: TextStyle(
                  color: style.quaternary,
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Settle in',
                style: TextStyle(
                  color: style.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return Text(
      title,
      style: TextStyle(
        color: style.text,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({
    required this.isPlaying,
    required this.canStop,
    required this.mixName,
    required this.count,
    required this.onPlayPause,
    required this.onStop,
  });

  final bool isPlaying;
  final bool canStop;
  final String? mixName;
  final int count;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [style.tint(style.primary, 0.17), style.panel],
        ),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: style.primary.withValues(alpha: 0.11)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: style.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
              color: style.primary,
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
                  style: TextStyle(
                    color: style.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mixName ??
                      '$count ${count == 1 ? 'layer' : 'layers'} in your mix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: style.quaternary, fontSize: 12),
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
              backgroundColor: style.primary,
              foregroundColor: style.onAccent,
              fixedSize: const Size(48, 48),
            ),
          ),
          IconButton(
            tooltip: 'Stop and reset',
            onPressed: canStop ? onStop : null,
            icon: const Icon(Icons.stop_rounded, size: 22),
            color: style.stopAccent ?? style.quaternary,
          ),
        ],
      ),
    );
  }
}

class _MasterVolumeCard extends StatelessWidget {
  const _MasterVolumeCard({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 11, 15, 9),
      decoration: BoxDecoration(
        color: style.panel,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          Icon(
            Icons.tune_rounded,
            size: 18,
            color: style.volumeAccent ?? style.primary,
          ),
          const SizedBox(width: 10),
          Text('Master', style: TextStyle(color: style.text, fontSize: 13)),
          Expanded(
            child: Slider(
              value: value.clamp(0.0, 1.0).toDouble(),
              onChanged: onChanged,
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(color: style.quaternary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmptyMixCard extends StatelessWidget {
  const _EmptyMixCard({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: style.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: style.outline),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start with one sound',
                  style: TextStyle(
                    color: style.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Layer a few favorites into your own mix.',
                  style: TextStyle(color: style.quaternary, fontSize: 12),
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
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.sound, required this.onAdd});
  final Sound sound;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return Container(
      width: 148,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: style.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.outline),
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
                  style: TextStyle(
                    color: style.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: style.primary),
                        Text(
                          'Add',
                          style: TextStyle(color: style.primary, fontSize: 11),
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
}
