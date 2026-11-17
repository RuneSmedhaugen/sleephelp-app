import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';
import '../services/wake_alarms.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _workdays = [1, 2, 3, 4, 5];

class AlarmsView extends StatelessWidget {
  const AlarmsView({super.key, required this.alarms});

  final WakeAlarms alarms;

  Future<void> _edit(BuildContext context, [WakeAlarm? alarm]) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AlarmEditor(alarm: alarm, alarms: alarms),
      );

  Future<void> _delete(BuildContext context, WakeAlarm alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete alarm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep alarm'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await alarms.action('delete', alarm.id!);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: alarms,
    builder: (context, _) {
      final style = RestStyle.of(context);
      final unsupported = alarms.permissions.contains('unsupported');
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Alarms',
                    style: TextStyle(
                      color: style.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (alarms.ready && !unsupported)
                  FilledButton.tonalIcon(
                    onPressed: alarms.busy ? null : () => _edit(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add alarm'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (alarms.error case final error?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(error, style: TextStyle(color: style.text)),
              ),
            if (unsupported)
              const Text(
                'Wake-up alarms are available on Android and iOS 26 or later.',
              )
            else if (!alarms.ready && alarms.error == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              for (final permission in alarms.permissions)
                _PermissionCard(
                  permission: permission,
                  onTap: alarms.busy ? null : () => alarms.allow(permission),
                ),
              if (alarms.alarms.isEmpty && alarms.ready)
                Text(
                  'No alarms set.',
                  style: TextStyle(color: style.quaternary),
                ),
              for (final alarm in alarms.alarms)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: alarms.busy || alarm.id == alarms.ringingId
                        ? null
                        : () => _edit(context, alarm),
                    title: Text(
                      alarm.time.format(context),
                      style: TextStyle(
                        color: style.text,
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(_alarmSubtitle(alarm)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip:
                              'Delete alarm at ${alarm.time.format(context)}',
                          onPressed: alarms.busy
                              ? null
                              : () => _delete(context, alarm),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                        Switch(
                          value: alarm.enabled || alarm.snoozed,
                          onChanged: alarms.busy || alarm.id == alarms.ringingId
                              ? null
                              : (value) => alarms.save(
                                  WakeAlarm(
                                    id: alarm.id,
                                    time: alarm.time,
                                    days: alarm.days,
                                    enabled: value,
                                    finishBeforeMinutes:
                                        alarm.finishBeforeMinutes,
                                    fadeMinutes: alarm.fadeMinutes,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );

  String _alarmSubtitle(WakeAlarm alarm) {
    if (alarm.snoozed) return 'Snoozed';
    if (alarm.days.isEmpty) return 'Once';
    if (alarm.days.length == 7) return 'Every day';
    if (alarm.days.length == 5 && _workdays.every(alarm.days.contains)) {
      return 'Mon–Fri';
    }
    return alarm.days.map((day) => _weekdays[day - 1]).join(' · ');
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.permission, this.onTap});

  final String permission;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (permission) {
      'exact' => (
        'Allow Alarms & reminders',
        'Lets REST ring at the time you set.',
      ),
      'notifications' => (
        'Allow alarm notifications',
        'Shows Snooze and Stop outside REST.',
      ),
      'fullScreen' => (
        'Allow full-screen alarms',
        'Optional. Show alarm controls over the lock screen.',
      ),
      'iosSettings' => (
        'Allow alarms in Settings',
        'Turn on Alarms for REST in iOS Settings.',
      ),
      _ => ('Allow alarms', 'Lets iOS present REST alarms on the lock screen.'),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.alarm_outlined),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _AlarmEditor extends StatefulWidget {
  const _AlarmEditor({this.alarm, required this.alarms});

  final WakeAlarm? alarm;
  final WakeAlarms alarms;

  @override
  State<_AlarmEditor> createState() => _AlarmEditorState();
}

class _AlarmEditorState extends State<_AlarmEditor> {
  late TimeOfDay _time =
      widget.alarm?.time ?? const TimeOfDay(hour: 7, minute: 0);
  late Set<int> _days = {...?widget.alarm?.days};
  late bool _customPlayback = widget.alarm?.finishBeforeMinutes != null;
  late int _finishBefore = widget.alarm?.finishBeforeMinutes ?? 60;
  late int _fade = widget.alarm?.fadeMinutes ?? 10;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.alarms.save(
      WakeAlarm(
        id: widget.alarm?.id,
        time: _time,
        days: _days.toList()..sort(),
        enabled: widget.alarm?.enabled ?? true,
        finishBeforeMinutes: _customPlayback ? _finishBefore : null,
        fadeMinutes: _customPlayback ? _fade : null,
      ),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = widget.alarms.error ?? 'Could not save the alarm. Try again.';
      });
    }
  }

  Future<void> _chooseTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null && mounted) setState(() => _time = value);
  }

  @override
  Widget build(BuildContext context) {
    final weekdaysSelected =
        _days.length == 5 && _workdays.every(_days.contains);
    return AlertDialog(
      title: Text(widget.alarm == null ? 'Add alarm' : 'Edit alarm'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: _saving ? null : _chooseTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text(
                _time.format(context),
                style: const TextStyle(fontSize: 23),
              ),
            ),
            const SizedBox(height: 16),
            Text(_days.isEmpty ? 'Repeat · Once' : 'Repeat'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Mon–Fri'),
                  selected: weekdaysSelected,
                  onSelected: _saving
                      ? null
                      : (selected) => setState(() {
                          _days = selected ? _workdays.toSet() : {};
                        }),
                ),
                FilterChip(
                  label: const Text('Every day'),
                  selected: _days.length == 7,
                  onSelected: _saving
                      ? null
                      : (selected) => setState(() {
                          _days = selected ? {1, 2, 3, 4, 5, 6, 7} : {};
                        }),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(_weekdays[day - 1]),
                    selected: _days.contains(day),
                    onSelected: _saving
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              _days.add(day);
                            } else {
                              _days.remove(day);
                            }
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Custom sleep fade'),
              subtitle: const Text(
                'Used when this is your next alarm and it’s within 12 hours of Play.',
              ),
              value: _customPlayback,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _customPlayback = value),
            ),
            if (_customPlayback) ...[
              const SizedBox(height: 10),
              _minutesField(
                title: 'Finish sounds',
                selected: _finishBefore,
                choices: const [
                  0,
                  15,
                  30,
                  45,
                  60,
                  90,
                  120,
                  180,
                  240,
                  360,
                  480,
                  720,
                ],
                label: (minutes) => minutes == 0
                    ? 'At the alarm'
                    : '${_durationLabel(minutes)} before the alarm',
                onChanged: (value) => setState(() => _finishBefore = value),
              ),
              const SizedBox(height: 10),
              _minutesField(
                title: 'Fade over',
                selected: _fade,
                choices: const [0, 2, 5, 10, 15, 20, 30, 45, 60, 90, 120],
                label: (minutes) =>
                    minutes == 0 ? 'No fade' : _durationLabel(minutes),
                onChanged: (value) => setState(() => _fade = value),
              ),
            ],
            if (_error case final error?) ...[
              const SizedBox(height: 10),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save alarm'),
        ),
      ],
    );
  }

  Widget _minutesField({
    required String title,
    required int selected,
    required List<int> choices,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
  }) => DropdownButtonFormField<int>(
    decoration: InputDecoration(labelText: title),
    initialValue: selected,
    isExpanded: true,
    items: [
      for (final minutes in ({...choices, selected}.toList()..sort()))
        DropdownMenuItem(value: minutes, child: Text(label(minutes))),
    ],
    onChanged: _saving
        ? null
        : (value) {
            if (value != null) onChanged(value);
          },
  );

  String _durationLabel(int minutes) =>
      minutes % 60 == 0 ? '${minutes ~/ 60} hr' : '$minutes min';
}

class RingingAlarmBanner extends StatelessWidget {
  const RingingAlarmBanner({super.key, required this.alarms});

  final WakeAlarms alarms;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: alarms,
    builder: (context, _) {
      final id = alarms.ringingId;
      if (id == null) return const SizedBox.shrink();
      final style = RestStyle.of(context);
      final accent = style.stopAccent ?? style.secondary;
      return Material(
        color: style.tint(accent, 0.13),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.alarm_on_rounded, color: accent),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Alarm ringing')),
                    TextButton(
                      onPressed: alarms.busy
                          ? null
                          : () => alarms.action('snooze', id),
                      child: const Text('Snooze'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: style.onAccent,
                      ),
                      onPressed: alarms.busy
                          ? null
                          : () => alarms.action('stop', id),
                      child: const Text('Stop'),
                    ),
                  ],
                ),
                if (alarms.error case final error?) Text(error),
              ],
            ),
          ),
        ),
      );
    },
  );
}
