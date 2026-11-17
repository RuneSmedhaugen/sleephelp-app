import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';

/// The same scene is drawn on Tonight and in the appearance preview.
class RestArtworkPanel extends StatelessWidget {
  const RestArtworkPanel({super.key, required this.style, this.child});

  final RestStyle style;
  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: style.heroGradient),
    child: CustomPaint(painter: _ArtworkPainter(style), child: child),
  );
}

class _ArtworkPainter extends CustomPainter {
  const _ArtworkPainter(this.style);

  final RestStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = math.min(size.width / 236, size.height / 160);
    final center = Offset(size.width - 86 * scale, size.height * 0.47);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    if (style.artwork != RestArtwork.eclipse) {
      _halo(canvas, Offset.zero, 102, style.primary, 0.27);
    }

    switch (style.artwork) {
      case RestArtwork.moon:
        _particles(canvas, seed: 6, count: 45, color: style.tertiary);
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 38)),
          Path()..addOval(
            Rect.fromCircle(center: const Offset(16, -14), radius: 35),
          ),
        );
        canvas.drawPath(moon, _gradient(style.text, style.primary, 46));
      case RestArtwork.leaves:
        _branch(canvas, -0.42, style.primary);
        _branch(canvas, 0.37, style.tertiary);
      case RestArtwork.petals:
        for (var index = 0; index < 7; index++) {
          canvas.save();
          canvas.rotate(index * math.pi * 2 / 7);
          final petal = Path()
            ..moveTo(0, 3)
            ..cubicTo(-30, -14, -18, -56, 4, -56)
            ..cubicTo(24, -55, 33, -21, 0, 3);
          canvas.drawPath(
            petal,
            _gradient(style.primary, style.secondary, 55, opacity: 0.45),
          );
          canvas.drawPath(petal, _line(style.tertiary, 0.48));
          canvas.restore();
        }
        _halo(canvas, Offset.zero, 20, style.secondary, 0.67);
      case RestArtwork.waves:
        _halo(canvas, const Offset(19, -23), 37, style.secondary, 0.53);
        canvas.drawCircle(
          const Offset(19, -23),
          14,
          _gradient(style.secondary, style.primary, 45),
        );
        for (var index = 0; index < 11; index++) {
          final y = -4 + index * 6.5;
          final wave = Path()
            ..moveTo(-105, y + 21)
            ..cubicTo(-69, y - 25, -14, y + 34, 29, y + 5)
            ..quadraticBezierTo(66, y - 22, 104, y - 8);
          canvas.drawPath(
            wave,
            _line(
              index.isEven ? style.primary : style.tertiary,
              0.54 - index * 0.031,
            ),
          );
        }
      case RestArtwork.aurora:
        _particles(canvas, seed: 22, count: 27, color: style.tertiary);
        for (var index = 0; index < 16; index++) {
          final bend = index * 3.5;
          final ribbon = Path()
            ..moveTo(-107, 49 - bend)
            ..cubicTo(-50, 51 - bend, -32, -82 + bend, 15, -40 + bend)
            ..quadraticBezierTo(53, 4 + bend, 102, -52 + bend);
          final paint = _line(style.primary, 0.4, width: 1.5)
            ..shader = LinearGradient(
              colors: [
                style.tertiary.withValues(alpha: 0),
                style.primary.withValues(alpha: 0.43),
                style.secondary.withValues(alpha: 0.52 - index * 0.025),
              ],
            ).createShader(const Rect.fromLTRB(-108, -70, 92, 65));
          canvas.drawPath(ribbon, paint);
        }
      case RestArtwork.orbit:
        _particles(canvas, seed: 12, count: 45, color: style.secondary);
        canvas.drawCircle(
          Offset.zero,
          36,
          _gradient(style.tertiary, style.background, 38),
        );
        canvas.save();
        canvas.rotate(-0.43);
        for (var index = 0; index < 4; index++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: 116 + index * 8,
              height: 27 + index * 6,
            ),
            _line(
              index.isEven ? style.secondary : style.primary,
              0.48,
              width: 1.2,
            ),
          );
        }
        canvas.restore();
      case RestArtwork.embers:
        _halo(canvas, const Offset(3, 23), 70, style.secondary, 0.40);
        _particles(
          canvas,
          seed: 32,
          count: 65,
          color: style.secondary,
          luminous: true,
        );
        for (var index = 0; index < 5; index++) {
          final x = index * 14.0 - 28;
          final current = Path()
            ..moveTo(x + 19, 57)
            ..cubicTo(x - 24, 21, x + 37, 15, x - 10, -40 - index * 3);
          canvas.drawPath(current, _line(style.primary, 0.34, width: 1.6));
        }
      case RestArtwork.spores:
        _particles(
          canvas,
          seed: 71,
          count: 36,
          color: style.secondary,
          luminous: true,
        );
        for (var index = 0; index < 6; index++) {
          final x = index * 19.0 - 49;
          final tip = Offset(
            x + 8 * math.sin(index),
            -18 - 28 * math.sin(index * 1.6),
          );
          final stem = Path()
            ..moveTo(x * 0.45, 73)
            ..quadraticBezierTo(x + 9, 28, tip.dx, tip.dy);
          final color = index.isEven ? style.primary : style.secondary;
          canvas.drawPath(stem, _line(color, 0.47));
          _halo(canvas, tip, 22, color, 0.44);
          canvas.drawCircle(tip, 2.6, Paint()..color = color);
        }
      case RestArtwork.eclipse:
        _paintEclipse(canvas);
    }
    canvas.restore();
  }

  void _paintEclipse(Canvas canvas) {
    const rim = Rect.fromLTWH(-41, -41, 82, 82);
    const start = -math.pi / 2;
    const sweep = 2 * math.pi;
    _halo(canvas, const Offset(-18, 12), 75, style.primary, 0.23);
    _halo(canvas, const Offset(24, -14), 67, style.secondary, 0.28);
    _particles(canvas, seed: 84, count: 27, color: style.tertiary);

    canvas.drawCircle(Offset.zero, 40, Paint()..color = style.background);
    final rimShader = SweepGradient(
      transform: const GradientRotation(start),
      colors: [style.secondary, style.primary, style.secondary],
    ).createShader(rim);
    canvas.drawArc(
      rim,
      start,
      sweep,
      false,
      _line(style.primary, 1, width: 5)
        ..shader = rimShader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawArc(
      rim,
      start,
      sweep,
      false,
      _line(style.primary, 1, width: 1.6)..shader = rimShader,
    );
    canvas.drawArc(
      rim.inflate(10),
      -0.45,
      1.65,
      false,
      _line(style.volumeAccent ?? style.primary, 0.58),
    );
    canvas.drawArc(
      rim.inflate(16),
      2.9,
      0.72,
      false,
      _line(style.tertiary, 0.73),
    );
  }

  void _branch(Canvas canvas, double angle, Color color) {
    canvas.save();
    canvas.rotate(angle);
    final stem = Path()
      ..moveTo(0, 65)
      ..quadraticBezierTo(6, 4, -2, -56);
    canvas.drawPath(stem, _line(color, 0.66));
    for (var index = 0; index < 8; index++) {
      final y = 50.0 - index * 13;
      final side = index.isEven ? 1 : -1;
      final reach = (43 - 2.8 * index) * side;
      final leaf = Path()
        ..moveTo(1, y)
        ..quadraticBezierTo(reach * 0.18, y - 24, reach, y - 27)
        ..quadraticBezierTo(reach * 0.74, y - 5, 1, y);
      canvas.drawPath(
        leaf,
        _gradient(color, style.background, 55, opacity: 0.77),
      );
      canvas.drawPath(leaf, _line(color, 0.45));
    }
    canvas.restore();
  }

  void _particles(
    Canvas canvas, {
    required int seed,
    required int count,
    required Color color,
    bool luminous = false,
  }) {
    final random = math.Random(seed);
    final paint = Paint();
    for (var index = 0; index < count; index++) {
      final point = Offset(
        random.nextDouble() * 171 - 84,
        random.nextDouble() * 144 - 73,
      );
      final radius = 0.45 + random.nextDouble() * (luminous ? 1.75 : 1);
      final alpha = 0.16 + random.nextDouble() * 0.65;
      if (luminous && radius > 1.5) {
        _halo(canvas, point, 9, color, alpha * 0.53);
      }
      canvas.drawCircle(
        point,
        radius,
        paint..color = color.withValues(alpha: alpha),
      );
    }
  }

  void _halo(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
      ).createShader(bounds);
    canvas.drawCircle(center, radius, paint);
  }

  Paint _gradient(
    Color light,
    Color dark,
    double radius, {
    double opacity = 1,
  }) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        light.withValues(alpha: opacity),
        dark.withValues(alpha: opacity),
      ],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));

  Paint _line(Color color, double opacity, {double width = 1}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = color.withValues(alpha: opacity);

  @override
  bool shouldRepaint(covariant _ArtworkPainter oldDelegate) =>
      oldDelegate.style != style;
}
