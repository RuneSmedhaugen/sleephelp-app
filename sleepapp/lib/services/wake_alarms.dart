import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals, kIsWeb;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../models/wake_playback.dart';
import 'browser_store.dart';

class WakeAlarm {
  const WakeAlarm({
    this.id,
    required this.time,
    this.days = const [],
    this.enabled = true,
    this.snoozed = false,
    this.nextAt,
    this.snoozedUntil,
  });

  final String? id;
  final TimeOfDay time;
  final List<int> days;
  final bool enabled;
  final bool snoozed;
  final DateTime? nextAt;
  final DateTime? snoozedUntil;

  factory WakeAlarm.fromMap(Map<Object?, Object?> map) => WakeAlarm(
    id: map['id'] as String,
    time: TimeOfDay(hour: map['hour'] as int, minute: map['minute'] as int),
    days: (map['days'] as List).cast<int>(),
    enabled: map['enabled'] as bool,
    snoozed: map['snoozed'] as bool,
    nextAt: _date(map['nextAt']),
    snoozedUntil: _date(map['snoozedUntil']),
  );

  static DateTime? _date(Object? millis) => millis is int && millis > 0
      ? DateTime.fromMillisecondsSinceEpoch(millis)
      : null;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'hour': time.hour,
    'minute': time.minute,
    'days': days,
    'enabled': enabled,
  };
}

class WakeAlarms extends ChangeNotifier {
  static const _channel = MethodChannel('rest/alarms');

  List<WakeAlarm> alarms = const [];
  List<String> permissions = const [];
  String? ringingId;
  int lastRing = 0;
  L? error;
  bool ready = false;
  bool busy = false;
  bool _disposed = false;
  Future<void>? _refreshing;
  Timer? _poll;
  bool _visible = false;
  bool _playbackSession = false;
  int? _previewMinute;
  Locale? _language;

  Future<void> syncLanguage(RestStrings strings) async {
    if (_language == strings.locale) return;
    _language = strings.locale;
    const labels = [
      L.alarmTitle,
      L.alarmAlertDetail,
      L.alarmChannel,
      L.snooze,
      L.stop,
      L.snoozeMinutes,
      L.snoozeError,
      L.alarmUpdateError,
    ];
    try {
      await _channel.invokeMethod<void>('setLanguage', {
        'locale': strings.locale.toLanguageTag(),
        'labels': {for (final label in labels) label.name: strings.text(label)},
      });
    } on MissingPluginException {
      // Alarms are unavailable on this platform.
    } on PlatformException {
      _language = null;
    }
  }

  WakePlayback? get nextWake {
    WakePlayback? earliest;
    for (final alarm in alarms) {
      final next = alarm.nextAt;
      if (next != null &&
          (earliest == null || next.isBefore(earliest.ringsAt))) {
        earliest = WakePlayback(next);
      }
      final snooze = alarm.snoozedUntil;
      if (snooze != null &&
          (earliest == null || snooze.isBefore(earliest.ringsAt))) {
        earliest = WakePlayback(snooze);
      }
    }
    return earliest;
  }

  // Also watch native changes while playback is active or paused in the background.
  void resume() {
    _visible = true;
    unawaited(refresh());
    _updatePolling();
  }

  void pause() {
    _visible = false;
    _updatePolling();
  }

  void setPlaybackSession(bool active) {
    _playbackSession = active;
    _updatePolling();
  }

  void _updatePolling() {
    if ((_visible || _playbackSession || ringingId != null) &&
        !permissions.contains('unsupported')) {
      _poll ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(refresh()),
      );
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> refresh() {
    if (busy || _disposed || permissions.contains('unsupported')) {
      return Future<void>.value();
    }
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    try {
      if (await _readStatus()) _notify();
    } on PlatformException {
      error = L.alarmReadError;
      _notify();
    }
  }

  Future<bool> _readStatus() async {
    if (kIsWeb) return _demoStatus();
    var changed = !ready;
    try {
      final data = await _channel.invokeMapMethod<Object?, Object?>('status');
      if (data == null || _disposed) return false;
      final nextAlarms =
          (data['alarms'] as List)
              .map(
                (item) =>
                    WakeAlarm.fromMap((item as Map).cast<Object?, Object?>()),
              )
              .toList()
            ..sort(
              (a, b) => (a.time.hour * 60 + a.time.minute).compareTo(
                b.time.hour * 60 + b.time.minute,
              ),
            );
      final nextPermissions = (data['permissions'] as List).cast<String>();
      final nextRingingId = data['ringing'] as String?;
      final nextRing = data['lastRing'] as int? ?? 0;
      final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      changed =
          changed ||
          !listEquals(permissions, nextPermissions) ||
          ringingId != nextRingingId ||
          lastRing != nextRing ||
          (_visible && minute != _previewMinute) ||
          alarms.length != nextAlarms.length ||
          Iterable<int>.generate(alarms.length).any((index) {
            final a = alarms[index];
            final b = nextAlarms[index];
            return a.id != b.id ||
                a.time != b.time ||
                a.enabled != b.enabled ||
                a.snoozed != b.snoozed ||
                a.nextAt != b.nextAt ||
                a.snoozedUntil != b.snoozedUntil ||
                !listEquals(a.days, b.days);
          });
      alarms = nextAlarms;
      permissions = nextPermissions;
      ringingId = nextRingingId;
      lastRing = nextRing;
      _previewMinute = minute;
      _updatePolling();
    } on MissingPluginException {
      permissions = const ['unsupported'];
      _updatePolling();
    }
    ready = true;
    return changed;
  }

  Future<bool> save(WakeAlarm alarm) => _perform('save', alarm.toMap());
  Future<bool> action(String method, String id) => _perform(method, {'id': id});
  Future<bool> allow(String permission) =>
      _perform('allow', {'permission': permission});

  Future<bool> _perform(String method, Map<String, Object?> arguments) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    _notify();
    try {
      if (kIsWeb) {
        _demoAction(method, arguments);
      } else {
        await _channel.invokeMethod<void>(method, arguments);
      }
    } on PlatformException catch (exception) {
      error = switch (exception.code) {
        'exactRequired' => L.exactRequired,
        'notificationsRequired' => L.notificationsRequired,
        'iosRequired' => L.allowIosSettingsDetails,
        'alarmInvalid' => L.alarmInvalid,
        'alarmBusy' => L.alarmBusy,
        _ => switch (method) {
          'save' => L.alarmSaveError,
          'delete' => L.alarmDeleteError,
          'snooze' => L.snoozeError,
          _ => L.alarmUpdateError,
        },
      };
      busy = false;
      _notify();
      return false;
    }
    try {
      await _readStatus();
    } on PlatformException {
      error = L.alarmRefreshError;
    } finally {
      busy = false;
      _notify();
    }
    return true;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  DateTime _demoNext(WakeAlarm alarm, DateTime now) {
    for (var offset = 0; offset <= 7; offset++) {
      final candidate = DateTime(
        now.year,
        now.month,
        now.day + offset,
        alarm.time.hour,
        alarm.time.minute,
      );
      if (candidate.isAfter(now) &&
          (alarm.days.isEmpty || alarm.days.contains(candidate.weekday))) {
        return candidate;
      }
    }
    return now.add(const Duration(days: 7));
  }

  List<dynamic> _demoRecords() {
    final raw = browserRead('rest_alarms');
    return raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
  }

  Future<bool> _demoStatus() async {
    final records = _demoRecords();
    final now = DateTime.now();
    var changed = !ready;
    for (final dynamic row in records) {
      final due = row['snoozedUntil'] ?? row['nextAt'];
      if (due is int &&
          due <= now.millisecondsSinceEpoch &&
          ringingId == null) {
        ringingId = row['id'] as String;
        lastRing = now.millisecondsSinceEpoch;
        row['snoozedUntil'] = null;
        if ((row['days'] as List).isEmpty) {
          row['enabled'] = false;
          row['nextAt'] = null;
        } else {
          row['nextAt'] = _demoNext(
            WakeAlarm.fromMap((row as Map).cast<Object?, Object?>()),
            now,
          ).millisecondsSinceEpoch;
        }
        changed = true;
      }
      row['snoozed'] = row['snoozedUntil'] != null;
    }
    browserWrite('rest_alarms', jsonEncode(records));
    alarms = records
        .map((row) => WakeAlarm.fromMap((row as Map).cast<Object?, Object?>()))
        .toList();
    permissions = const [];
    ready = true;
    _updatePolling();
    return changed;
  }

  void _demoAction(String method, Map<String, Object?> arguments) {
    final records = _demoRecords();
    final id = arguments['id'] as String?;
    if (method == 'save') {
      final alarm = WakeAlarm(
        time: TimeOfDay(
          hour: arguments['hour'] as int,
          minute: arguments['minute'] as int,
        ),
        days: (arguments['days'] as List).cast<int>(),
        enabled: arguments['enabled'] as bool,
      );
      records.removeWhere((row) => id != null && row['id'] == id);
      records.add({
        ...arguments,
        'id': id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        'snoozed': false,
        'snoozedUntil': null,
        'nextAt': alarm.enabled
            ? _demoNext(alarm, DateTime.now()).millisecondsSinceEpoch
            : null,
      });
    } else if (method == 'delete') {
      records.removeWhere((row) => row['id'] == id);
      if (ringingId == id) ringingId = null;
    } else if (method == 'stop') {
      ringingId = null;
    } else if (method == 'snooze') {
      for (final dynamic row in records) {
        if (row['id'] == id) {
          row['snoozedUntil'] = DateTime.now()
              .add(const Duration(minutes: 10))
              .millisecondsSinceEpoch;
        }
      }
      ringingId = null;
    }
    browserWrite('rest_alarms', jsonEncode(records));
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
