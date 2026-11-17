import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';
import '../models/wake_playback.dart';
import 'sleep_plan_text.dart';

class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({
    super.key,
    required this.regularDuration,
    required this.regularFade,
    required this.offersAlarmPlan,
    required this.usesRegularTimerTonight,
    required this.preview,
    required this.onFollowAlarm,
    required this.onStart,
    required this.onCancel,
  });

  final Duration? regularDuration;
  final Duration regularFade;
  final bool offersAlarmPlan;
  final bool usesRegularTimerTonight;
  final SleepPlan Function(Duration duration, Duration fade, bool follow)
  preview;
  final Future<void> Function() onFollowAlarm;
  final Future<void> Function(Duration duration, Duration fadeOut) onStart;
  final Future<void> Function() onCancel;

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  static const _durations = [15, 30, 45, 60, 90];
  static const _fades = [0, 2, 5, 10, 15];

  late int _durationMinutes;
  late int _fadeMinutes;
  bool _saving = false;
  late bool _followAlarm;

  @override
  void initState() {
    super.initState();
    _durationMinutes = widget.regularDuration?.inMinutes ?? 45;
    _fadeMinutes = widget.regularDuration == null
        ? 5
        : widget.regularFade.inMinutes;
    _followAlarm = widget.offersAlarmPlan && !widget.usesRegularTimerTonight;
    if (!_durations.contains(_durationMinutes)) _durationMinutes = 45;
    _clampFade();
  }

  void _clampFade() {
    final allowed = _fades.where((minutes) => minutes <= _durationMinutes);
    if (!allowed.contains(_fadeMinutes)) {
      _fadeMinutes = allowed.isEmpty ? 0 : allowed.last;
    }
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    try {
      if (_followAlarm) {
        await widget.onFollowAlarm();
      } else {
        await widget.onStart(
          Duration(minutes: _durationMinutes),
          Duration(minutes: _fadeMinutes),
        );
      }
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
      _followAlarm,
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
            'Sleep timer',
            style: TextStyle(
              color: style.text,
              fontSize: 23,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.offersAlarmPlan) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _TimerChoice(
                  label: 'Follow alarm',
                  selected: _followAlarm,
                  onTap: () => setState(() => _followAlarm = true),
                ),
                _TimerChoice(
                  label: 'Sleep timer tonight',
                  selected: !_followAlarm,
                  onTap: () => setState(() => _followAlarm = false),
                ),
              ],
            ),
          ],
          if (!_followAlarm) ...[
            const SizedBox(height: 24),
            const _TimerLabel('PLAY FOR'),
            const SizedBox(height: 11),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in _durations)
                  _TimerChoice(
                    label: '$minutes min',
                    selected: _durationMinutes == minutes,
                    onTap: () => setState(() {
                      _durationMinutes = minutes;
                      _clampFade();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 23),
            const _TimerLabel('FADE OVER'),
            const SizedBox(height: 11),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in _fades.where(
                  (minutes) => minutes <= _durationMinutes,
                ))
                  _TimerChoice(
                    label: minutes == 0 ? 'No fade' : '$minutes min',
                    selected: _fadeMinutes == minutes,
                    onTap: () => setState(() => _fadeMinutes = minutes),
                  ),
              ],
            ),
          ],
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
                    : Text(_followAlarm ? 'Follow alarm' : 'Set sleep timer'),
              ),
            ),
          ),
          if (!_followAlarm && widget.regularDuration != null) ...[
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _saving ? null : _cancel,
                child: const Text('Turn off sleep timer'),
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
