import 'package:material_ui/material_ui.dart';

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
    return 'The planned stop time has passed. Choose Sleep timer tonight to play.';
  }
  if (plan.blocked) return 'Stop or snooze the alarm before pressing Play.';
  if (stop == null) return 'Choose when your soundscape ends.';

  final source = plan.followsAlarm && alarm != null
      ? 'Following your ${formatSleepTime(context, alarm)} alarm'
      : plan.timerShortened
      ? 'Sleep timer shortened to your alarm'
      : plan.cappedAtAlarm
      ? 'Playback ends at your alarm'
      : 'Sleep timer';
  final fade = plan.fadeShortened
      ? 'Fade starts with playback'
      : plan.fade > Duration.zero
      ? 'Fade at ${formatSleepTime(context, stop.subtract(plan.fade))}'
      : 'No fade';
  final duration = plan.playFor;
  final playback = duration == null
      ? ''
      : ' · Plays for ${_playTime(duration)}';
  return '$source$playback · $fade · Silent by ${formatSleepTime(context, stop)}';
}

String _playTime(Duration duration) {
  final minutes = (duration.inSeconds / 60).ceil();
  if (minutes < 1) return 'less than 1 min';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return [
    if (hours > 0) '$hours hr',
    if (remainder > 0 || hours == 0) '$remainder min',
  ].join(' ');
}
