import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../models/wake_playback.dart';

String formatSleepTime(BuildContext context, DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final clock = TimeOfDay.fromDateTime(local).format(context);
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return clock;
  }
  return '${MaterialLocalizations.of(context).formatShortDate(local)} $clock';
}

String describeSleepPlan(BuildContext context, SleepPlan plan) {
  final alarm = plan.alarmAt;
  final stop = plan.stopAt;
  if (plan.blocked && plan.followsAlarm) {
    return context.t(L.pastStop);
  }
  if (plan.blocked) return context.t(L.stopOrSnooze);
  if (stop == null) return context.t(L.chooseEnd);

  final source = plan.followsAlarm && alarm != null
      ? context.t(L.followingAlarm, [formatSleepTime(context, alarm)])
      : plan.timerShortened
      ? context.t(L.timerShortened)
      : plan.cappedAtAlarm
      ? context.t(L.endsAtAlarm)
      : context.t(L.sleepTimer);
  final fade = plan.fadeShortened
      ? context.t(L.fadeWithPlayback)
      : plan.fade > Duration.zero
      ? context.t(L.fadeAt, [
          formatSleepTime(context, stop.subtract(plan.fade)),
        ])
      : context.t(L.noFade);
  final duration = plan.playFor;
  final playback = duration == null
      ? ''
      : context.t(L.playsFor, [_playTime(context, duration)]);
  return [
    source,
    if (playback.isNotEmpty) playback,
    fade,
    context.t(L.silentBy, [formatSleepTime(context, stop)]),
  ].join(' · ');
}

String _playTime(BuildContext context, Duration duration) {
  final minutes = (duration.inSeconds / 60).ceil();
  if (minutes < 1) return context.t(L.shortDuration);
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return [
    if (hours > 0) context.t(L.hours, [hours]),
    if (remainder > 0 || hours == 0) context.t(L.minutes, [remainder]),
  ].join(' ');
}
