import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';
import '../models/wake_playback.dart';
import '../services/sleep_audio_handler.dart';
import 'rest_artwork.dart';
import 'sleep_plan_text.dart';

class TonightTimerCard extends StatelessWidget {
  const TonightTimerCard({
    super.key,
    required this.initialState,
    required this.states,
    required this.plan,
    required this.hasPlaybackSession,
    required this.isPlaying,
    required this.onChange,
  });

  final SleepTimerState initialState;
  final Stream<SleepTimerState> states;
  final SleepPlan plan;
  final bool hasPlaybackSession;
  final bool isPlaying;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: RestArtworkPanel(
        style: style,
        child: Container(
          constraints: const BoxConstraints(minHeight: 170),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: style.outline),
            gradient: LinearGradient(
              colors: [
                style.background.withValues(alpha: 0.82),
                style.background.withValues(alpha: 0.40),
              ],
            ),
          ),
          child: StreamBuilder<SleepTimerState>(
            stream: states,
            initialData: initialState,
            builder: (context, snapshot) {
              final state = snapshot.data ?? initialState;
              final active =
                  hasPlaybackSession && state.isActive && !state.isCompleted;
              final alarm = active ? state.alarmAt : null;
              final fade = active ? state.untilFade : null;
              final fading = fade == Duration.zero;
              final title = active
                  ? alarm == null
                        ? 'Sleep timer'
                        : state.followsAlarm
                        ? 'Following your ${formatSleepTime(context, alarm)} alarm'
                        : 'Stops at your ${formatSleepTime(context, alarm)} alarm'
                  : 'Playback plan';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: style.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onChange,
                        child: Text(
                          !active && plan.stopAt == null && !plan.blocked
                              ? 'Set timer'
                              : 'Change',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (active) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fade != null) ...[
                          Expanded(
                            child: _CountdownReading(
                              title: fading ? 'Fading now' : 'Fade starts in',
                              value: fading
                                  ? _fadeProgress(state)
                                  : _countdown(fade),
                              accent: style.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: _CountdownReading(
                            title: 'Silent in',
                            value: _countdown(state.remaining),
                            accent: style.primary,
                          ),
                        ),
                      ],
                    ),
                    if (!isPlaying) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.isRunning
                            ? 'Playback paused · alarm deadline still counting'
                            : 'Timer paused',
                        style: TextStyle(color: style.text, fontSize: 12),
                      ),
                    ],
                  ] else
                    Text(
                      hasPlaybackSession && !plan.blocked
                          ? 'No timer running'
                          : describeSleepPlan(context, plan),
                      style: TextStyle(
                        color: style.text,
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _countdown(Duration duration) {
    // Round up so 00:00:00 only appears once the deadline is reached.
    final seconds = (duration.inMicroseconds / Duration.microsecondsPerSecond)
        .ceil();
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$remainder';
  }

  static String _fadeProgress(SleepTimerState state) {
    final remainingPortion =
        state.remaining.inMicroseconds / state.fadeOut.inMicroseconds;
    return '${((1 - remainingPortion).clamp(0.0, 1.0) * 100).floor()}%';
  }
}

class _CountdownReading extends StatelessWidget {
  const _CountdownReading({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fit both readings in the same width even on smaller displays.
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: style.text,
                fontSize: 31,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(title, style: TextStyle(color: accent, fontSize: 13)),
      ],
    );
  }
}
