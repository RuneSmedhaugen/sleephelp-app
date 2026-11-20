/// The next occurrence of a REST alarm, with optional sleep playback settings.
class WakePlayback {
  const WakePlayback(this.ringsAt);

  final DateTime ringsAt;
}

class SleepPlan {
  const SleepPlan({
    this.stopAt,
    this.alarmAt,
    this.playFor,
    this.fade = Duration.zero,
    this.cappedAtAlarm = false,
    this.timerShortened = false,
    this.blocked = false,
    this.fadeShortened = false,
  });

  final DateTime? stopAt;
  final DateTime? alarmAt;
  final Duration? playFor;
  final Duration fade;
  final bool cappedAtAlarm;
  final bool timerShortened;
  final bool blocked;
  final bool fadeShortened;
}
