import 'package:flutter/material.dart';

import '../services/sleep_audio_handler.dart';

class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({
    super.key,
    required this.initialState,
    required this.onStart,
    required this.onCancel,
  });

  final SleepTimerState initialState;
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

  @override
  void initState() {
    super.initState();
    final current = widget.initialState;
    _durationMinutes = current.isActive && current.duration != null
        ? current.duration!.inMinutes
        : 45;
    _fadeMinutes = current.isActive ? current.fadeOut.inMinutes : 5;
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
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
                color: const Color(0xFF5D667A),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Sleep timer',
            style: TextStyle(
              color: Color(0xFFF1F2F7),
              fontSize: 23,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your mix fades out before it stops.',
            style: TextStyle(color: Color(0xFF929DB2), fontSize: 13),
          ),
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
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2132),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              _fadeMinutes == 0
                  ? 'Sound stops after $_durationMinutes minutes.'
                  : 'Sound fades over the last $_fadeMinutes minutes, then stops.',
              style: const TextStyle(
                color: Color(0xFFB8C1D1),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 19),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _start,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start timer'),
              ),
            ),
          ),
          if (widget.initialState.isActive &&
              !widget.initialState.isCompleted) ...[
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _saving ? null : _cancel,
                child: const Text('Cancel timer'),
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
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF8792A8),
      fontSize: 10,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w700,
    ),
  );
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
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    onSelected: (_) => onTap(),
    labelStyle: TextStyle(
      color: selected ? const Color(0xFFEAE7FF) : const Color(0xFF9BA5B8),
      fontSize: 12,
    ),
    backgroundColor: const Color(0xFF171D2D),
    selectedColor: const Color(0xFF34304E),
    side: BorderSide(
      color: selected
          ? const Color(0xFF8274B8).withValues(alpha: 0.58)
          : Colors.white.withValues(alpha: 0.05),
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  );
}
