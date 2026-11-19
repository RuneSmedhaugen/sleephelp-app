import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../models/rest_style.dart';
import '../models/wake_playback.dart';
import '../services/sleep_audio_handler.dart';
import '../widgets/tonight_timer_card.dart';

class SleepHomeView extends StatelessWidget {
  const SleepHomeView({
    super.key,
    required this.selectedSoundCount,
    required this.masterVolume,
    required this.isPlaying,
    required this.hasPlaybackSession,
    required this.mixName,
    required this.hasUnsavedChanges,
    required this.timerState,
    required this.timerStates,
    required this.plannedTimer,
    required this.onPlayPause,
    required this.onStop,
    required this.onTimer,
    required this.onOpenMixer,
    required this.onMasterVolumeChanged,
  });

  final int selectedSoundCount;
  final double masterVolume;
  final bool isPlaying;
  final bool hasPlaybackSession;
  final String? mixName;
  final bool hasUnsavedChanges;
  final SleepTimerState timerState;
  final Stream<SleepTimerState> timerStates;
  final SleepPlan plannedTimer;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onTimer;
  final VoidCallback onOpenMixer;
  final ValueChanged<double> onMasterVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    final title = selectedSoundCount == 0
        ? context.t(L.chooseSounds)
        : mixName ?? context.t(L.yourSoundMix);
    final count = RestStrings.of(context)
        .count(selectedSoundCount, L.layerCountOne, L.layerCountOther);
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
              const SizedBox(height: 24),
              Material(
                color: style.panel,
                borderRadius: BorderRadius.circular(21),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(21),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 8,
                  ),
                  leading: Icon(Icons.graphic_eq_rounded, color: style.primary),
                  title: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    hasUnsavedChanges
                        ? '$count · ${context.t(L.unsavedChanges)}'
                        : count,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: onOpenMixer,
                ),
              ),
              if (selectedSoundCount > 0) ...[
                const SizedBox(height: 12),
                _PlaybackCard(
                  isPlaying: isPlaying,
                  canStop: hasPlaybackSession,
                  mixName: null,
                  count: selectedSoundCount,
                  onPlayPause: onPlayPause,
                  onStop: onStop,
                ),
              ],
              const SizedBox(height: 12),
              _MasterVolumeCard(
                value: masterVolume,
                onChanged: onMasterVolumeChanged,
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
                context.t(L.nightSounds),
                style: TextStyle(
                  color: style.quaternary,
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                context.t(L.settleIn),
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
                  isPlaying
                      ? context.t(L.playingSoftly)
                      : context.t(L.readyToPlay),
                  style: TextStyle(
                    color: style.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mixName ??
                      RestStrings.of(context)
                          .count(count, L.layerCountOne, L.layerCountOther),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: style.quaternary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isPlaying ? context.t(L.pause) : context.t(L.play),
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
            tooltip: context.t(L.stopReset),
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
          Text(
            context.t(L.masterVolume),
            style: TextStyle(color: style.text, fontSize: 13),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(0.0, 1.0).toDouble(),
              onChanged: onChanged,
            ),
          ),
          Text(
            context.t(L.percent, [(value * 100).round()]),
            style: TextStyle(color: style.quaternary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
