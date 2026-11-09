class SoundMix {
  const SoundMix({
    required this.id,
    required this.name,
    required this.sounds,
    required this.volumes,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> sounds;
  final Map<String, double> volumes;
  final DateTime updatedAt;

  factory SoundMix.fromJson(Map<String, dynamic> json) => SoundMix(
    id: json['id'] as String,
    name: json['name'] as String,
    sounds: List<String>.from(json['sounds'] as List<dynamic>),
    volumes: (json['volumes'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    ),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sounds': sounds,
    'volumes': volumes,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
