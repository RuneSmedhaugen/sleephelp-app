import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../models/rest_style.dart';
import '../models/wake_playback.dart';
import 'sleep_plan_text.dart';

const sleepTimerMinutes = [
  15,
  30,
  60,
  120,
  360,
  480,
];
const sleepFadeMinutes = [0, 5, 10, 15, 30, 60, 120];

class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({
    super.key,
    required this.regularDuration,
    required this.regularFade,
    required this.preview,
    required this.onStart,
    required this.onCancel,
  });

  final Duration? regularDuration;
  final Duration regularFade;
  final SleepPlan Function(Duration duration, Duration fade) preview;
  final Future<void> Function(Duration duration, Duration fadeOut) onStart;
  final Future<void> Function() onCancel;

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  late int _durationMinutes;
  late int _fadeMinutes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _durationMinutes = widget.regularDuration?.inMinutes ?? 45;
    _fadeMinutes = widget.regularDuration == null
        ? 5
        : widget.regularFade.inMinutes;
    _clampFade();
  }

  void _clampFade() {
    _fadeMinutes = _fadeMinutes.clamp(0, _durationMinutes).toInt();
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    try {
      await widget.onStart(
        Duration(minutes: _durationMinutes),
        Duration(minutes: _fadeMinutes),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _saving = true);
    try {
      await widget.onCancel();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final plan = widget.preview(
      Duration(minutes: _durationMinutes),
      Duration(minutes: _fadeMinutes),
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22, 10, 22, 22 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: style.quaternary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Text(
            context.t(L.sleepTimer),
            style: TextStyle(
              color: style.text,
              fontSize: 23,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 24),
          _TimerLabel(context.t(L.playFor)),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in ({
                ...sleepTimerMinutes,
                _durationMinutes,
              }.toList()..sort()))
                _TimerChoice(
                  label: formatSleepDuration(
                    context,
                    Duration(minutes: minutes),
                  ),
                  selected: _durationMinutes == minutes,
                  onTap: () => setState(() {
                    _durationMinutes = minutes;
                    _clampFade();
                  }),
                ),
            ],
          ),
          Slider(
            value: _durationMinutes.toDouble(),
            min: 1,
            max: 720,
            divisions: 719,
            label: formatSleepDuration(
              context,
              Duration(minutes: _durationMinutes),
            ),
            onChanged: (value) => setState(() {
              _durationMinutes = value.round();
              _clampFade();
            }),
          ),
          Center(
            child: Text(
              formatSleepDuration(context, Duration(minutes: _durationMinutes)),
              style: TextStyle(color: style.text, fontSize: 16),
            ),
          ),
          const SizedBox(height: 23),
          _TimerLabel(context.t(L.fadeOver)),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes
                  in ({
                      ...sleepFadeMinutes,
                      _fadeMinutes,
                    }.where((minutes) => minutes <= _durationMinutes).toList()
                    ..sort()))
                _TimerChoice(
                  label: minutes == 0
                      ? context.t(L.noFade)
                      : context.t(L.minutes, [minutes]),
                  selected: _fadeMinutes == minutes,
                  onTap: () => setState(() => _fadeMinutes = minutes),
                ),
            ],
          ),
          Slider(
            value: _fadeMinutes.toDouble(),
            min: 0,
            max: _durationMinutes.toDouble(),
            divisions: _durationMinutes,
            label: _fadeMinutes == 0
                ? context.t(L.noFade)
                : formatSleepDuration(context, Duration(minutes: _fadeMinutes)),
            onChanged: (value) => setState(() => _fadeMinutes = value.round()),
          ),
          Center(
            child: Text(
              _fadeMinutes == 0
                  ? context.t(L.noFade)
                  : formatSleepDuration(context, Duration(minutes: _fadeMinutes)),
              style: TextStyle(color: style.text, fontSize: 16),
            ),
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: style.raised,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              describeSleepPlan(context, plan),
              style: TextStyle(color: style.text, fontSize: 12, height: 1.35),
            ),
          ),
          const SizedBox(height: 19),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving || plan.blocked ? null : _start,
              style: FilledButton.styleFrom(
                backgroundColor: style.secondary,
                foregroundColor: style.onAccent,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.t(L.setSleepTimer)),
              ),
            ),
          ),
          if (widget.regularDuration != null) ...[
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _saving ? null : _cancel,
                child: Text(context.t(L.disableTimer)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimerLabel extends StatelessWidget {
  const _TimerLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return Text(
      label,
      style: TextStyle(
        color: style.quaternary,
        fontSize: 10,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TimerChoice extends StatelessWidget {
  const _TimerChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? style.text : style.quaternary,
        fontSize: 12,
      ),
      backgroundColor: style.panel,
      selectedColor: style.tint(style.secondary, 0.22),
      side: BorderSide(
        color: selected
            ? style.secondary.withValues(alpha: 0.58)
            : style.outline,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    );
  }
}
