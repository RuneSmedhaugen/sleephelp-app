/// The next occurrence of a REST alarm, with optional sleep playback settings.
class WakePlayback {
  const WakePlayback(this.ringsAt, {this.finishBefore, this.fade});

  final DateTime ringsAt;
  final Duration? finishBefore;
  final Duration? fade;

  DateTime get customStop => ringsAt.subtract(finishBefore ?? Duration.zero);

  bool offersCustomPlan(DateTime now) =>
      finishBefore != null &&
      ringsAt.isAfter(now) &&
      ringsAt.difference(now) <= const Duration(hours: 12);
}

class SleepPlan {
  const SleepPlan({
    this.stopAt,
    this.alarmAt,
    this.playFor,
    this.fade = Duration.zero,
    this.followsAlarm = false,
    this.cappedAtAlarm = false,
    this.timerShortened = false,
    this.blocked = false,
    this.fadeShortened = false,
  });

  final DateTime? stopAt;
  final DateTime? alarmAt;
  final Duration? playFor;
  final Duration fade;
  final bool followsAlarm;
  final bool cappedAtAlarm;
  final bool timerShortened;
  final bool blocked;
  final bool fadeShortened;
}
