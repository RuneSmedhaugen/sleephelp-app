import 'package:material_ui/material_ui.dart';

enum RestArtwork {
  moon,
  leaves,
  petals,
  waves,
  aurora,
  orbit,
  embers,
  spores,
  eclipse,
}

class RestStyle extends ThemeExtension<RestStyle> {
  const RestStyle({
    required this.id,
    required this.name,
    required this.artwork,
    required this.background,
    required this.surface,
    required this.text,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.quaternary,
    this.soundAccent,
    this.volumeAccent,
    this.stopAccent,
  });

  final String id;
  final String name;
  final RestArtwork artwork;
  final Color background;
  final Color surface;
  final Color text;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color quaternary;
  final Color? soundAccent;
  final Color? volumeAccent;
  final Color? stopAccent;

  static RestStyle of(BuildContext context) =>
      Theme.of(context).extension<RestStyle>() ?? all.first;

  Color get panel => tint(primary, 0.06);
  Color get raised => tint(primary, 0.13);
  Color get outline => primary.withValues(alpha: 0.18);
  Color get onAccent => const Color(0xFF0C1017);
  Color get backgroundHighlight => Color.lerp(
    background,
    artwork == RestArtwork.eclipse ? surface : primary,
    artwork == RestArtwork.eclipse ? 0.65 : 0.095,
  )!;

  Color layerAccent(String category) =>
      soundAccent ??
      switch (category) {
        'Nature' => secondary,
        'Water' => tertiary,
        'Warmth' => Color.lerp(primary, secondary, 0.40)!,
        _ => primary,
      };

  Color tint(Color accent, double amount) =>
      Color.lerp(surface, accent, amount)!;

  LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      background,
      surface,
      tint(secondary, artwork == RestArtwork.eclipse ? 0.03 : 0.16),
    ],
    stops: const [0, 0.55, 1],
  );

  @override
  RestStyle copyWith({
    String? name,
    RestArtwork? artwork,
    Color? background,
    Color? surface,
    Color? text,
    Color? primary,
    Color? secondary,
    Color? tertiary,
    Color? quaternary,
    Color? soundAccent,
    Color? volumeAccent,
    Color? stopAccent,
  }) => RestStyle(
    id: id,
    name: name ?? this.name,
    artwork: artwork ?? this.artwork,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    text: text ?? this.text,
    primary: primary ?? this.primary,
    secondary: secondary ?? this.secondary,
    tertiary: tertiary ?? this.tertiary,
    quaternary: quaternary ?? this.quaternary,
    soundAccent: soundAccent ?? this.soundAccent,
    volumeAccent: volumeAccent ?? this.volumeAccent,
    stopAccent: stopAccent ?? this.stopAccent,
  );

  @override
  RestStyle lerp(RestStyle? other, double t) {
    if (other == null || identical(other, this)) return this;
    if (t <= 0) return this;
    if (t >= 1) return other;
    final target = t < 0.5 ? this : other;
    return target.copyWith(
      background: Color.lerp(background, other.background, t),
      surface: Color.lerp(surface, other.surface, t),
      text: Color.lerp(text, other.text, t),
      primary: Color.lerp(primary, other.primary, t),
      secondary: Color.lerp(secondary, other.secondary, t),
      tertiary: Color.lerp(tertiary, other.tertiary, t),
      quaternary: Color.lerp(quaternary, other.quaternary, t),
    );
  }

  static const all = [
    RestStyle(
      id: 'midnight_lavender',
      name: 'Midnight Lavender',
      artwork: RestArtwork.moon,
      background: Color(0xFF0D1220),
      surface: Color(0xFF111726),
      text: Color(0xFFB6B7CA),
      primary: Color(0xFFB4A8EC),
      secondary: Color(0xFF9ED9CC),
      tertiary: Color(0xFFDDE3F1),
      quaternary: Color(0xFF8994AA),
    ),
    RestStyle(
      id: 'sage',
      name: 'Sage',
      artwork: RestArtwork.leaves,
      background: Color(0xFF101C1C),
      surface: Color(0xFF172523),
      text: Color(0xFFB6BFB1),
      primary: Color(0xFFA8C9B5),
      secondary: Color(0xFFB6BFB1),
      tertiary: Color(0xFF82B9A0),
      quaternary: Color(0xFF9BAFA6),
    ),
    RestStyle(
      id: 'rose',
      name: 'Rose',
      artwork: RestArtwork.petals,
      background: Color(0xFF1C1720),
      surface: Color(0xFF261E29),
      text: Color(0xFFC3ADB4),
      primary: Color(0xFFD6A0A7),
      secondary: Color(0xFFD9C6A2),
      tertiary: Color(0xFFE8B8BB),
      quaternary: Color(0xFFAB929F),
    ),
    RestStyle(
      id: 'tidal',
      name: 'Tidal',
      artwork: RestArtwork.waves,
      background: Color(0xFF0D1722),
      surface: Color(0xFF14212D),
      text: Color(0xFFABBDC9),
      primary: Color(0xFF8FB7CE),
      secondary: Color(0xFFC99B78),
      tertiary: Color(0xFF86C7D6),
      quaternary: Color(0xFF8D9FAC),
    ),
    RestStyle(
      id: 'aurora',
      name: 'Aurora',
      artwork: RestArtwork.aurora,
      background: Color(0xFF081719),
      surface: Color(0xFF102326),
      text: Color(0xFFA6C3BE),
      primary: Color(0xFF48E5D2),
      secondary: Color(0xFF91F7D3),
      tertiary: Color(0xFF71CFF0),
      quaternary: Color(0xFF8AAEAD),
    ),
    RestStyle(
      id: 'violet_orbit',
      name: 'Violet Orbit',
      artwork: RestArtwork.orbit,
      background: Color(0xFF100B1D),
      surface: Color(0xFF1A1230),
      text: Color(0xFFB8ABD0),
      primary: Color(0xFFAA72FF),
      secondary: Color(0xFF78D9FF),
      tertiary: Color(0xFFC39BFF),
      quaternary: Color(0xFFA298B8),
    ),
    RestStyle(
      id: 'ember_glow',
      name: 'Ember Glow',
      artwork: RestArtwork.embers,
      background: Color(0xFF19100F),
      surface: Color(0xFF261917),
      text: Color(0xFFC6AFA2),
      primary: Color(0xFFFF6B71),
      secondary: Color(0xFFFFB85C),
      tertiary: Color(0xFFFF8C70),
      quaternary: Color(0xFFB49B8D),
    ),
    RestStyle(
      id: 'bioluminescent',
      name: 'Bioluminescent',
      artwork: RestArtwork.spores,
      background: Color(0xFF0A150E),
      surface: Color(0xFF122219),
      text: Color(0xFFB2C2A6),
      primary: Color(0xFFB7F34B),
      secondary: Color(0xFF4FE5C1),
      tertiary: Color(0xFF83E477),
      quaternary: Color(0xFF9AAE91),
    ),
    RestStyle(
      id: 'blacklight',
      name: 'Blacklight',
      artwork: RestArtwork.eclipse,
      background: Color(0xFF030406),
      surface: Color(0xFF0B0D12),
      text: Color(0xFFAFB8C9),
      primary: Color(0xFF38F5FF),
      secondary: Color(0xFFC399FF),
      tertiary: Color(0xFFC8FA59),
      quaternary: Color(0xFF9EA8BD),
      soundAccent: Color(0xFFC8FA59),
      volumeAccent: Color(0xFF639DFF),
      stopAccent: Color(0xFFFF7887),
    ),
  ];

  static final selected = ValueNotifier<RestStyle>(all.first);
}
