import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../models/rest_style.dart';
import '../services/wake_alarms.dart';

const _weekdays = [L.mon, L.tue, L.wed, L.thu, L.fri, L.sat, L.sun];
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
        title: Text(context.t(L.deleteAlarm)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t(L.keepAlarm)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t(L.delete)),
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
                    context.t(L.alarms),
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
                    label: Text(context.t(L.addAlarm)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (alarms.error case final error?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  context.t(error),
                  style: TextStyle(color: style.text),
                ),
              ),
            if (unsupported)
              Text(context.t(L.alarmUnavailable))
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
                  context.t(L.noAlarms),
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
                    subtitle: Text(_alarmSubtitle(context, alarm)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.t(L.deleteAlarmAt, [
                            alarm.time.format(context),
                          ]),
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

  String _alarmSubtitle(BuildContext context, WakeAlarm alarm) {
    if (alarm.snoozed) return context.t(L.snoozed);
    if (alarm.days.isEmpty) return context.t(L.once);
    if (alarm.days.length == 7) return context.t(L.everyDay);
    if (alarm.days.length == 5 && _workdays.every(alarm.days.contains)) {
      return context.t(L.weekdays);
    }
    return alarm.days.map((day) => context.t(_weekdays[day - 1])).join(' · ');
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.permission, this.onTap});

  final String permission;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (permission) {
      'exact' => (context.t(L.allowExact), context.t(L.allowExactDetails)),
      'notifications' => (
        context.t(L.allowNotifications),
        context.t(L.allowNotificationsDetails),
      ),
      'fullScreen' => (
        context.t(L.allowFullScreen),
        context.t(L.allowFullScreenDetails),
      ),
      'iosSettings' => (
        context.t(L.allowIosSettings),
        context.t(L.allowIosSettingsDetails),
      ),
      _ => (context.t(L.allowIos), context.t(L.allowIosDetails)),
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
  bool _saving = false;
  L? _error;

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
      ),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = widget.alarms.error ?? L.alarmSaveError;
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
      title: Text(
        widget.alarm == null ? context.t(L.addAlarm) : context.t(L.editAlarm),
      ),
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
            Text(_days.isEmpty ? context.t(L.repeatOnce) : context.t(L.repeat)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: Text(context.t(L.weekdays)),
                  selected: weekdaysSelected,
                  onSelected: _saving
                      ? null
                      : (selected) => setState(() {
                          _days = selected ? _workdays.toSet() : {};
                        }),
                ),
                FilterChip(
                  label: Text(context.t(L.everyDay)),
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
                    label: Text(context.t(_weekdays[day - 1])),
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
            if (_error case final error?) ...[
              const SizedBox(height: 10),
              Text(
                context.t(error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(context.t(L.cancel)),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? context.t(L.saving) : context.t(L.saveAlarm)),
        ),
      ],
    );
  }

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
                    Expanded(child: Text(context.t(L.alarmRinging))),
                    TextButton(
                      onPressed: alarms.busy
                          ? null
                          : () => alarms.action('snooze', id),
                      child: Text(context.t(L.snooze)),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: style.onAccent,
                      ),
                      onPressed: alarms.busy
                          ? null
                          : () => alarms.action('stop', id),
                      child: Text(context.t(L.stop)),
                    ),
                  ],
                ),
                if (alarms.error case final error?) Text(context.t(error)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
