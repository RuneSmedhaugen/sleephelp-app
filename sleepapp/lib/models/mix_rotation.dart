enum MixRotationMode {
  off('Off'),
  daily('Daily'),
  weekly('Weekly');

  const MixRotationMode(this.label);
  final String label;
}

class MixRotation {
  const MixRotation({
    this.mode = MixRotationMode.off,
    this.days = const [null, null, null, null, null, null, null],
    this.weeks = const [null],
    this.firstMonday,
  });

  final MixRotationMode mode;
  final List<String?> days;
  final List<String?> weeks;
  final DateTime? firstMonday;

  MixRotation copyWith({
    MixRotationMode? mode,
    List<String?>? days,
    List<String?>? weeks,
    DateTime? firstMonday,
  }) => MixRotation(
    mode: mode ?? this.mode,
    days: days ?? this.days,
    weeks: weeks ?? this.weeks,
    firstMonday: firstMonday ?? this.firstMonday,
  );

  String? assignedMixId(DateTime now) => switch (mode) {
    MixRotationMode.off => null,
    MixRotationMode.daily => days[now.weekday - 1],
    MixRotationMode.weekly => weeks[weekIndex(now)],
  };

  int weekIndex(DateTime now) {
    final monday = mondayOf(now);
    final elapsed = monday.difference(firstMonday ?? monday).inDays;
    return elapsed < 0 ? 0 : (elapsed ~/ 7) % weeks.length;
  }

  // Use UTC dates as calendar labels so DST can't make a week 6 days long.
  static DateTime mondayOf(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day - date.weekday + 1);

  factory MixRotation.fromJson(Map<String, dynamic> json) {
    final days = List<String?>.from(json['days'] as List);
    final weeks = List<String?>.from(json['weeks'] as List);
    if (days.length != 7 || weeks.isEmpty) {
      throw const FormatException('Invalid rotation slots.');
    }
    final firstMonday = json['firstMonday'] as String?;
    return MixRotation(
      mode: MixRotationMode.values.byName(json['mode'] as String),
      days: days,
      weeks: weeks,
      firstMonday: firstMonday == null ? null : DateTime.parse(firstMonday),
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'days': days,
    'weeks': weeks,
    'firstMonday': firstMonday?.toIso8601String(),
  };
}
