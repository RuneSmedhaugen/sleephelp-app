import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../models/rest_style.dart';
import '../models/wake_playback.dart';
import '../services/sleep_audio_handler.dart';
import '../widgets/tonight_panel.dart';
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
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TonightTimerCard(
          initialState: timerState,
          states: timerStates,
          plan: plannedTimer,
          hasPlaybackSession: hasPlaybackSession,
          isPlaying: isPlaying,
          onChange: onTimer,
          embedded: true,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: style.text,
                  fontSize: 23,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasUnsavedChanges
                    ? '$count · ${context.t(L.unsavedChanges)}'
                    : count,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: style.text.withValues(alpha: 0.76),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: context.t(L.bedsideComingSoon),
          child: TonightPanel(
            radius: 22,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bedtime_outlined, color: style.primary, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      context.t(L.bedsideView),
                      style: TextStyle(color: style.text, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      context.t(L.comingSoon),
                      style: TextStyle(
                        color: style.text.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _MasterVolume(value: masterVolume, onChanged: onMasterVolumeChanged),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundControl(
              icon: Icons.timer_outlined,
              label: context.t(L.sleepTimer),
              onPressed: onTimer,
            ),
            const SizedBox(width: 28),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: style.primary.withValues(alpha: 0.08),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: IconButton(
                tooltip: isPlaying ? context.t(L.pause) : context.t(L.play),
                onPressed: selectedSoundCount == 0 ? onOpenMixer : onPlayPause,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 42,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: style
                      .tint(style.primary, 0.14)
                      .withValues(alpha: 0.90),
                  foregroundColor: Color.lerp(style.primary, style.text, 0.40),
                  side: BorderSide(
                    color: style.primary.withValues(alpha: 0.32),
                  ),
                  fixedSize: const Size(80, 80),
                ),
              ),
            ),
            const SizedBox(width: 28),
            _RoundControl(
              icon: Icons.graphic_eq_rounded,
              label: context.t(L.editMix),
              onPressed: onOpenMixer,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: hasPlaybackSession
              ? TextButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded, size: 17),
                  label: Text(context.t(L.stopReset)),
                  style: TextButton.styleFrom(
                    foregroundColor: style.text.withValues(alpha: 0.85),
                  ),
                )
              : Center(
                  child: Text(
                    context.t(L.readyToPlay),
                    style: TextStyle(
                      color: style.text.withValues(alpha: 0.70),
                      fontSize: 12,
                    ),
                  ),
                ),
        ),
      ],
    );
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              constraints.maxWidth > constraints.maxHeight &&
              constraints.maxWidth >= 600;
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: landscape ? 1000 : 540,
                  minHeight: (constraints.maxHeight - 34).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _TopGreeting(),
                    const SizedBox(height: 24),
                    if (landscape)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 36),
                          Expanded(child: controls),
                        ],
                      )
                    else ...[
                      details,
                      const SizedBox(height: 36),
                      controls,
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopGreeting extends StatelessWidget {
  const _TopGreeting();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF4BF1DD), Color(0xFF5E9BFF), Color(0xFFC36AFF)],
            ).createShader(bounds),
            child: const Text(
              'R.E.S.T',
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'REST Ribbon',
                fontSize: 46,
                letterSpacing: 7,
                fontWeight: FontWeight.w400,
                shadows: [
                  Shadow(color: Color(0xCC00E8EF), blurRadius: 16),
                  Shadow(color: Color(0x88705BFF), blurRadius: 30),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.t(L.settleIn),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFD4C3FF),
            fontFamily: 'REST Ribbon',
            fontStyle: FontStyle.italic,
            fontSize: 25,
            shadows: [
              Shadow(color: Color(0xA86645FF), blurRadius: 16),
              Shadow(color: Color(0x5549DCE5), blurRadius: 26),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return TonightPanel(
      radius: 28,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          foregroundColor: style.text,
          fixedSize: const Size(54, 54),
        ),
      ),
    );
  }
}

class _MasterVolume extends StatelessWidget {
  const _MasterVolume({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return TonightPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.volume_down_rounded,
                  color: style.volumeAccent ?? style.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t(L.masterVolume),
                    style: TextStyle(color: style.text, fontSize: 13),
                  ),
                ),
                Text(
                  context.t(L.percent, [(value * 100).round()]),
                  style: TextStyle(color: style.text, fontSize: 12),
                ),
              ],
            ),
            Slider(
              value: value.clamp(0.0, 1.0).toDouble(),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
