import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';

/// Each theme is a complete composition; previews use the same scene renderer.
class RestArtworkPanel extends StatelessWidget {
  const RestArtworkPanel({
    super.key,
    required this.style,
    this.child,
    this.fullScene = false,
  });

  final RestStyle style;
  final Widget? child;
  final bool fullScene;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ArtworkPainter(style, fullScene: fullScene),
              isComplex: true,
            ),
          ),
        ),
      ),
      ?child,
    ],
  );
}

class _ArtworkPainter extends CustomPainter {
  const _ArtworkPainter(this.style, {required this.fullScene});
  final RestStyle style;
  final bool fullScene;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scene = _ThemeScene(canvas, size, style);
    scene.paint();
    // Quiet the central reading area while retaining detail around the edges.
    if (fullScene) scene.readingShade();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArtworkPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.fullScene != fullScene;
}

class _ThemeScene {
  _ThemeScene(this.canvas, this.size, this.style);

  final Canvas canvas;
  final Size size;
  final RestStyle style;
  Rect get bounds => Offset.zero & size;
  double get unit => math.min(size.width, size.height);
  Offset p(double x, double y) => Offset(x * size.width, y * size.height);

  void paint() {
    canvas.drawRect(bounds, Paint()..color = style.background);
    switch (style.artwork) {
      case RestArtwork.moon:
        _moonlight();
      case RestArtwork.leaves:
        _sage();
      case RestArtwork.petals:
        _rose();
      case RestArtwork.waves:
        _tidal();
      case RestArtwork.aurora:
        _aurora();
      case RestArtwork.orbit:
        _orbit();
      case RestArtwork.embers:
        _embers();
      case RestArtwork.spores:
        _bioluminescent();
      case RestArtwork.eclipse:
        _blacklight();
    }
  }

  void readingShade() {
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 0.85,
          colors: [
            style.background.withValues(alpha: 0.26),
            style.background.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
  }

  void _moonlight() {
    _wash(0.77, 0.20, 0.70, style.primary, 0.21);
    _wash(0.10, 0.62, 0.65, style.secondary, 0.065);
    _points(seed: 6, count: 90, color: style.tertiary, bottom: 0.68);
    final center = p(0.76, 0.22);
    final radius = unit * 0.105;
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Path()..addOval(
        Rect.fromCircle(
          center: center + Offset(radius * 0.44, -radius * 0.34),
          radius: radius * 0.94,
        ),
      ),
    );
    canvas.drawPath(
      moon,
      Paint()..color = style.primary.withValues(alpha: 0.46),
    );
    // Unequal distant ridges and mist form a landscape, rather than a wave motif.
    final ridges = [
      [
        0.0,
        0.65,
        0.12,
        0.55,
        0.27,
        0.69,
        0.44,
        0.61,
        0.70,
        0.46,
        0.81,
        0.64,
        1.0,
        0.55,
      ],
      [
        0.0,
        0.79,
        0.23,
        0.63,
        0.27,
        0.72,
        0.51,
        0.75,
        0.72,
        0.79,
        0.80,
        0.65,
        1.0,
        0.72,
      ],
      [
        0.0,
        0.91,
        0.17,
        0.82,
        0.36,
        0.92,
        0.57,
        0.86,
        0.76,
        0.77,
        0.90,
        0.89,
        1.0,
        0.83,
      ],
    ];
    for (var i = 0; i < ridges.length; i++) {
      final ridge = _curve(ridges[i])
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      _fill(ridge, style.primary, style.background, opacity: 0.16 - i * 0.025);
    }
    _wash(0.36, 0.72, 0.33, style.primary, 0.07);
    for (final (x, y, h) in [
      (0.03, 0.85, 0.14),
      (0.95, 0.92, 0.19),
      (0.89, 0.94, 0.11),
    ]) {
      final top = p(x, y - h);
      final tree = Path()..moveTo(top.dx, top.dy);
      for (final side in [-1, 1]) {
        if (side == 1) {
          final base = p(x + 0.038, y);
          tree.lineTo(base.dx, base.dy);
        }
        for (var tier = 0; tier < 5; tier++) {
          final level = side == -1 ? tier : 4 - tier;
          final tip = p(
            x + side * (0.014 + level * 0.006),
            y - h + h * (level + 1) / 5,
          );
          final notch = p(
            x + side * (0.006 + level * 0.003),
            y - h + h * (level + 0.8) / 5,
          );
          if (side == -1) {
            tree.lineTo(tip.dx, tip.dy);
            tree.lineTo(notch.dx, notch.dy);
          } else {
            tree.lineTo(notch.dx, notch.dy);
            tree.lineTo(tip.dx, tip.dy);
          }
        }
      }
      tree.close();
      canvas.drawPath(
        tree,
        Paint()..color = style.background.withValues(alpha: 0.65),
      );
    }
  }

  void _sage() {
    _wash(0.18, 0.20, 0.60, style.tertiary, 0.16);
    _wash(0.85, 0.88, 0.65, style.primary, 0.11);
    // Botanical silhouettes grow in from the perimeter, leaving a quiet clearing.
    for (final (x, y, angle, length, opacity) in [
      (-0.03, 1.07, 0.30, 1.50, 0.22),
      (1.04, 1.07, -0.35, 1.65, 0.26),
      (0.04, -0.10, 2.55, 1.12, 0.18),
      (0.96, -0.08, -2.55, 1.13, 0.20),
      (-0.12, 0.67, 0.83, 0.80, 0.13),
      (1.10, 0.56, -0.85, 0.76, 0.16),
    ]) {
      _fern(p(x, y), angle, unit * length, opacity);
    }
    _points(
      seed: 31,
      count: 20,
      color: style.secondary,
      luminous: true,
      strength: 0.16,
    );
  }

  void _fern(Offset origin, double angle, double length, double opacity) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    final stem = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * 0.06, -length * 0.5, 0, -length);
    _stroke(stem, style.primary, opacity, 1);
    for (var i = 1; i <= 10; i++) {
      final y = -length * i / 11;
      final reach = length * (0.13 - i * 0.006);
      for (final side in [-1, 1]) {
        final leaf = Path()
          ..moveTo(0, y)
          ..cubicTo(
            side * reach * 0.2,
            y - reach * 0.95,
            side * reach * 0.8,
            y - reach * 1.05,
            side * reach,
            y - reach * 0.66,
          )
          ..quadraticBezierTo(side * reach * 0.8, y + reach * 0.08, 0, y)
          ..close();
        canvas.drawPath(
          leaf,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                style.surface.withValues(alpha: opacity),
                style.primary.withValues(alpha: opacity),
              ],
            ).createShader(leaf.getBounds()),
        );
        _stroke(leaf, style.secondary, opacity * 0.25, 0.6);
      }
    }
    canvas.restore();
  }

  void _rose() {
    _wash(0.0, 0.05, 0.70, style.primary, 0.15);
    _wash(1.0, 0.96, 0.70, style.secondary, 0.10);
    // Oversized translucent blooms overlap the canvas edges like a silk canopy.
    _bloom(p(-0.08, 0.04), unit * 0.68, -0.3, 0.20);
    _bloom(p(1.08, 0.92), unit * 0.83, 0.5, 0.23);
    _bloom(p(-0.13, 0.69), unit * 0.48, 0.9, 0.11);
    for (var i = 0; i < 7; i++) {
      final x = 0.14 + (i * 0.17) % 0.8;
      final y = 0.14 + i * 0.11;
      canvas.save();
      canvas.translate(p(x, y).dx, p(x, y).dy);
      canvas.rotate(i * 0.83);
      final r = unit * 0.025;
      final petal = Path()
        ..moveTo(-r, 0)
        ..cubicTo(-r, -r, r, -r * 1.6, r * 1.3, 0)
        ..quadraticBezierTo(0, r, -r, 0)
        ..close();
      canvas.drawPath(
        petal,
        Paint()..color = style.primary.withValues(alpha: 0.11),
      );
      canvas.restore();
    }
    _points(seed: 61, count: 26, color: style.secondary, strength: 0.22);
  }

  void _bloom(Offset origin, double radius, double rotation, double opacity) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(rotation);
    for (var layer = 0; layer < 3; layer++) {
      final r = radius * (1 - layer * 0.24);
      for (var i = 0; i < 7; i++) {
        canvas.save();
        canvas.rotate(i * math.pi * 2 / 7 + layer * 0.42);
        final petal = Path()
          ..moveTo(0, r * 0.06)
          ..cubicTo(-r * 0.72, -r * 0.30, -r * 0.52, -r, 0, -r)
          ..cubicTo(r * 0.64, -r * 0.96, r * 0.60, -r * 0.22, 0, r * 0.06)
          ..close();
        canvas.drawPath(
          petal,
          Paint()
            ..shader = RadialGradient(
              center: Alignment.topCenter,
              radius: 1.1,
              colors: [
                style.primary.withValues(alpha: opacity),
                style.secondary.withValues(alpha: opacity * 0.20),
                style.background.withValues(alpha: 0),
              ],
            ).createShader(petal.getBounds()),
        );
        _stroke(petal, style.primary, opacity * 0.42, 0.7);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  void _tidal() {
    _wash(0.66, 0.34, 0.65, style.tertiary, 0.12);
    _wash(0.65, 0.45, 0.28, style.secondary, 0.13);
    // A distant horizon dissolves into a deep, rippled ocean.
    final sea = Rect.fromLTWH(
      0,
      size.height * 0.45,
      size.width,
      size.height * 0.55,
    );
    canvas.drawRect(
      sea,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            style.tertiary.withValues(alpha: 0),
            style.tertiary.withValues(alpha: 0.09),
            style.background,
          ],
          stops: const [0, 0.24, 1],
        ).createShader(sea),
    );
    final random = math.Random(42);
    for (var i = 0; i < 38; i++) {
      final y = 0.46 + i * 0.015;
      final spread = (i / 38) * 0.35;
      final start = 0.65 - spread - random.nextDouble() * 0.16;
      final end = 0.65 + spread + random.nextDouble() * 0.16;
      final reflection = _curve([
        start,
        y,
        start + 0.12,
        y - 0.004,
        end - 0.10,
        y + 0.006,
        end,
        y,
      ]);
      _stroke(
        reflection,
        i.isEven ? style.secondary : style.tertiary,
        0.09 + (1 - i / 38) * 0.10,
        0.6 + i * 0.045,
      );
    }
    for (var i = 0; i < 6; i++) {
      final y = 0.64 + i * 0.071;
      final swell = _curve([
        -0.1,
        y,
        0.22,
        y - 0.10,
        0.66,
        y + 0.12,
        1.1,
        y - 0.04,
      ]);
      _stroke(swell, style.tertiary, 0.13 - i * 0.01, 1 + i * 0.5, blur: 1);
      _stroke(swell, style.primary, 0.11, 0.7);
    }
    _points(
      seed: 11,
      count: 25,
      color: style.primary,
      bottom: 0.40,
      strength: 0.22,
    );
  }

  void _aurora() {
    _wash(0.07, 0.25, 0.80, style.secondary, 0.10);
    _points(seed: 22, count: 80, color: style.tertiary, strength: 0.55);
    // Curtains stretch from sky to sky, with feathered translucent folds.
    for (var band = 0; band < 3; band++) {
      for (var i = 0; i < 24; i++) {
        final d = i * 0.005;
        final shift = band * 0.23;
        final curtain = _curve([
          -0.16,
          0.14 + shift + d,
          0.24,
          -0.10 + shift + d,
          0.31,
          0.68 - shift + d,
          0.68,
          0.40 + shift + d,
          0.89,
          0.29 + shift + d,
          0.90,
          0.26 + shift + d,
          1.15,
          0.01 + shift + d,
        ]);
        final color = band == 1 ? style.tertiary : style.primary;
        final alpha = math.sin(i / 24 * math.pi) * 0.07;
        _stroke(curtain, color, alpha, unit * 0.013, blur: unit * 0.012);
        if (i % 6 == 0) _stroke(curtain, style.secondary, 0.04, 0.7);
      }
    }
    _wash(0.79, 0.79, 0.43, style.primary, 0.08);
  }

  void _orbit() {
    _wash(0.84, 0.22, 0.72, style.primary, 0.19);
    _wash(0.08, 0.91, 0.52, style.secondary, 0.08);
    _points(seed: 12, count: 115, color: style.secondary, strength: 0.60);
    final center = p(0.59, 0.53);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.65);
    // Nested orbits run off the edges; the scene has no rectangular boundary.
    for (var i = 0; i < 6; i++) {
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: unit * (1.1 + i * 0.27),
        height: unit * (0.44 + i * 0.19),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..shader = SweepGradient(
            colors: [
              style.primary.withValues(alpha: 0),
              style.primary.withValues(alpha: 0.22),
              style.secondary.withValues(alpha: 0.12),
              style.primary.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
    canvas.restore();
    final planet = p(0.82, 0.31);
    final radius = unit * 0.22;
    canvas.drawCircle(
      planet,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.7, -0.6),
          radius: 1.3,
          colors: [
            style.primary.withValues(alpha: 0.35),
            style.surface,
            style.background,
          ],
        ).createShader(Rect.fromCircle(center: planet, radius: radius)),
    );
    _glow(p(0.12, 0.75), unit * 0.065, style.secondary, 0.18);
    canvas.drawCircle(
      p(0.12, 0.75),
      unit * 0.015,
      Paint()..color = style.secondary.withValues(alpha: 0.45),
    );
  }

  void _embers() {
    _wash(0.48, 1.12, 0.80, style.secondary, 0.27);
    _wash(0.05, 0.66, 0.64, style.primary, 0.09);
    // Long smoke trails dissolve upwards above a low bank of embers.
    for (var i = 0; i < 7; i++) {
      final x = i * 0.19;
      final smoke = _curve([
        x,
        1.12,
        x - 0.25,
        0.70,
        x + 0.36,
        0.65,
        x + 0.08,
        0.32,
        x - 0.04,
        0.16,
        x + 0.17,
        0.06,
        x + 0.02,
        -0.12,
      ]);
      _stroke(smoke, style.primary, 0.055, unit * 0.045, blur: unit * 0.04);
    }
    final random = math.Random(32);
    for (var i = 0; i < 105; i++) {
      final y = math.pow(random.nextDouble(), 0.42).toDouble();
      final center = p(random.nextDouble(), y);
      final r = (0.4 + random.nextDouble() * 1.4) * (0.4 + y);
      final color = i.isEven ? style.secondary : style.primary;
      if (i % 4 == 0) _glow(center, r * 6, color, 0.13 * y);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: r, height: r * 2.4),
        Paint()..color = color.withValues(alpha: 0.10 + y * 0.27),
      );
    }
  }

  void _bioluminescent() {
    _wash(0.03, 0.93, 0.65, style.primary, 0.13);
    _wash(0.98, 0.29, 0.62, style.secondary, 0.10);
    final random = math.Random(71);
    // Fine living filaments grow along both margins, each ending in a soft spore.
    for (var side = 0; side < 2; side++) {
      for (var i = 0; i < 12; i++) {
        final edge = side == 0 ? -0.06 : 1.06;
        final reach = 0.03 + random.nextDouble() * 0.22;
        final tipX = side == 0 ? reach : 1 - reach;
        final tipY = 0.08 + random.nextDouble() * 0.84;
        final rootY = (tipY + 0.28 + random.nextDouble() * 0.3).clamp(0.0, 1.2);
        final stem = _curve([
          edge,
          rootY,
          edge,
          tipY + 0.08,
          tipX,
          tipY + 0.19,
          tipX,
          tipY,
        ]);
        final color = i.isEven ? style.primary : style.secondary;
        _stroke(stem, color, 0.18, 0.75);
        final tip = p(tipX, tipY);
        _glow(tip, unit * 0.044, color, 0.17);
        canvas.drawCircle(
          tip,
          1.2 + random.nextDouble() * 1.2,
          Paint()..color = color.withValues(alpha: 0.47),
        );
        for (var j = 0; j < 3; j++) {
          final branch = _curve([
            tipX,
            tipY + 0.08,
            tipX,
            tipY + 0.02,
            tipX + (j - 1) * 0.025,
            tipY + 0.05,
            tipX + (j - 1) * 0.04,
            tipY - 0.025,
          ]);
          _stroke(branch, color, 0.10, 0.55);
        }
      }
    }
    _points(
      seed: 72,
      count: 58,
      color: style.secondary,
      luminous: true,
      strength: 0.38,
    );
  }

  void _blacklight() {
    final center = p(0.5, 0.49);
    final radius = unit * 0.65;
    _wash(0.0, 0.23, 0.67, style.primary, 0.075);
    _wash(1.0, 0.82, 0.60, style.secondary, 0.08);
    // A room-sized eclipse and sparse chromatic arcs frame the whole interface.
    for (var i = 0; i < 4; i++) {
      final rim = Rect.fromCircle(
        center: center,
        radius: radius + unit * i * 0.12,
      );
      final shader = SweepGradient(
        transform: const GradientRotation(-1.7),
        colors: [
          style.primary.withValues(alpha: 0),
          style.primary.withValues(alpha: 0.35),
          style.secondary.withValues(alpha: 0.03),
          style.secondary.withValues(alpha: 0.30),
          style.primary.withValues(alpha: 0),
        ],
      ).createShader(rim);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 0 ? 1.2 : 0.65
        ..shader = shader;
      if (i == 0) {
        canvas.drawOval(
          rim,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = unit * 0.02
            ..shader = shader
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.025),
        );
      }
      canvas.drawOval(rim, paint);
    }
    final arc = Rect.fromCenter(
      center: p(0.5, 0.52),
      width: unit * 1.85,
      height: size.height * 0.90,
    );
    canvas.drawArc(
      arc,
      0.5,
      0.37,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = style.tertiary.withValues(alpha: 0.25),
    );
    canvas.drawArc(
      arc,
      3.6,
      0.43,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = (style.volumeAccent ?? style.primary).withValues(alpha: 0.22),
    );
    _points(seed: 84, count: 22, color: style.secondary, strength: 0.32);
  }

  /// Cubic control points in viewport fractions keep both orientations composed.
  Path _curve(List<double> values) {
    final start = p(values[0], values[1]);
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 2; i + 5 < values.length; i += 6) {
      final a = p(values[i], values[i + 1]);
      final b = p(values[i + 2], values[i + 3]);
      final c = p(values[i + 4], values[i + 5]);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }
    return path;
  }

  void _wash(double x, double y, double radius, Color color, double opacity) =>
      _glow(
        p(x, y),
        math.max(size.width, size.height) * radius,
        color,
        opacity,
      );

  void _glow(Offset center, double radius, Color color, double opacity) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.32),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _fill(Path path, Color light, Color dark, {double opacity = 1}) {
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            light.withValues(alpha: opacity),
            dark.withValues(alpha: 0.85),
          ],
        ).createShader(path.getBounds()),
    );
  }

  void _stroke(
    Path path,
    Color color,
    double opacity,
    double width, {
    double blur = 0,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: opacity);
    if (blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawPath(path, paint);
  }

  void _points({
    required int seed,
    required int count,
    required Color color,
    double bottom = 1,
    double strength = 0.65,
    bool luminous = false,
  }) {
    final random = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final point = p(random.nextDouble(), random.nextDouble() * bottom);
      final radius = 0.4 + random.nextDouble() * 0.95;
      final alpha = (0.12 + random.nextDouble() * 0.42) * strength;
      if (luminous && i % 4 == 0) _glow(point, radius * 7, color, alpha * 0.65);
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }
}
