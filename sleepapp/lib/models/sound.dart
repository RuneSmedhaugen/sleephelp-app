class Sound {
  final String id;
  final String name;
  final String assetPath;
  double volume;
  bool isMuted;

  Sound({
    required this.id,
    required this.name,
    required this.assetPath,
    this.volume = 1.0,
    this.isMuted = false,
  });
}