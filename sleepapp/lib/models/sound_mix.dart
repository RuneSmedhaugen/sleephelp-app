class SoundMix {
  const SoundMix({
    required this.id,
    required this.name,
    required this.sounds,
    required this.volumes,
    required this.updatedAt,
    this.timer,
  });

  final String id;
  final String name;
  final List<String> sounds;
  final Map<String, double> volumes;
  final DateTime updatedAt;
  final MixTimerSettings? timer;

  SoundMix copyWith({
    String? id,
    String? name,
    List<String>? sounds,
    Map<String, double>? volumes,
    DateTime? updatedAt,
    MixTimerSettings? timer,
    bool clearTimer = false,
  }) => SoundMix(
    id: id ?? this.id,
    name: name ?? this.name,
    sounds: List.unmodifiable(sounds ?? this.sounds),
    volumes: Map.unmodifiable(volumes ?? this.volumes),
    updatedAt: updatedAt ?? this.updatedAt,
    timer: clearTimer ? null : timer ?? this.timer,
  );

  factory SoundMix.fromJson(Map<String, dynamic> json) => SoundMix(
    id: json['id'] as String,
    name: json['name'] as String,
    sounds: List<String>.from(json['sounds'] as List<dynamic>),
    volumes: (json['volumes'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    ),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    timer: MixTimerSettings.tryParse(json['timer']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sounds': sounds,
    'volumes': volumes,
    'updatedAt': updatedAt.toIso8601String(),
    if (timer != null) 'timer': timer!.toJson(),
  };
}

/// Null on SoundMix means use the regular timer. A settings object with no
/// duration explicitly switches the sleep timer off for that mix.
class MixTimerSettings {
  const MixTimerSettings({this.duration, this.fade = Duration.zero});

  final Duration? duration;
  final Duration fade;

  bool get isValid => duration == null
      ? fade == Duration.zero
      : duration! > Duration.zero && fade >= Duration.zero && fade <= duration!;

  static MixTimerSettings? tryParse(Object? json) {
    if (json is! Map) return null;
    final duration = json['durationMilliseconds'];
    final fade = json['fadeMilliseconds'];
    if (fade is! int || (duration != null && duration is! int)) return null;
    final settings = MixTimerSettings(
      duration: duration == null
          ? null
          : Duration(milliseconds: duration as int),
      fade: Duration(milliseconds: fade),
    );
    return settings.isValid ? settings : null;
  }

  Map<String, Object?> toJson() => {
    'durationMilliseconds': duration?.inMilliseconds,
    'fadeMilliseconds': fade.inMilliseconds,
  };
}
