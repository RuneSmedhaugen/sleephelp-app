import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/wake_playback.dart';

class WakeAlarm {
  const WakeAlarm({
    this.id,
    required this.time,
    this.days = const [],
    this.enabled = true,
    this.snoozed = false,
    this.nextAt,
    this.snoozedUntil,
    this.finishBeforeMinutes,
    this.fadeMinutes,
  });

  final String? id;
  final TimeOfDay time;
  final List<int> days;
  final bool enabled;
  final bool snoozed;
  final DateTime? nextAt;
  final DateTime? snoozedUntil;
  final int? finishBeforeMinutes;
  final int? fadeMinutes;

  factory WakeAlarm.fromMap(Map<Object?, Object?> map) => WakeAlarm(
    id: map['id'] as String,
    time: TimeOfDay(hour: map['hour'] as int, minute: map['minute'] as int),
    days: (map['days'] as List).cast<int>(),
    enabled: map['enabled'] as bool,
    snoozed: map['snoozed'] as bool,
    nextAt: _date(map['nextAt']),
    snoozedUntil: _date(map['snoozedUntil']),
    finishBeforeMinutes: map['finishBeforeMinutes'] as int?,
    fadeMinutes: map['fadeMinutes'] as int?,
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
    'finishBeforeMinutes': finishBeforeMinutes,
    'fadeMinutes': fadeMinutes,
  };
}

class WakeAlarms extends ChangeNotifier {
  static const _channel = MethodChannel('rest/alarms');

  List<WakeAlarm> alarms = const [];
  List<String> permissions = const [];
  String? ringingId;
  int lastRing = 0;
  String? error;
  bool ready = false;
  bool busy = false;
  bool _disposed = false;
  Future<void>? _refreshing;
  Timer? _poll;
  bool _visible = false;
  bool _playbackSession = false;
  int? _previewMinute;

  WakePlayback? get nextWake {
    WakePlayback? earliest;
    for (final alarm in alarms) {
      final next = alarm.nextAt;
      if (next != null &&
          (earliest == null || next.isBefore(earliest.ringsAt))) {
        earliest = WakePlayback(
          next,
          finishBefore: alarm.finishBeforeMinutes == null
              ? null
              : Duration(minutes: alarm.finishBeforeMinutes!),
          fade: Duration(minutes: alarm.fadeMinutes ?? 0),
        );
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
    } on PlatformException catch (exception) {
      error = exception.message ?? 'Could not read alarms.';
      _notify();
    }
  }

  Future<bool> _readStatus() async {
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
                a.finishBeforeMinutes != b.finishBeforeMinutes ||
                a.fadeMinutes != b.fadeMinutes ||
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
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (exception) {
      error = exception.message ?? 'Could not update the alarm.';
      busy = false;
      _notify();
      return false;
    }
    try {
      await _readStatus();
    } on PlatformException catch (exception) {
      error = exception.message ?? 'Could not refresh the alarm list.';
    } finally {
      busy = false;
      _notify();
    }
    return true;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
