import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RestIntro extends StatefulWidget {
  const RestIntro({super.key, required this.progress});

  final Animation<double> progress;

  @override
  State<RestIntro> createState() => _RestIntroState();
}

class _RestIntroState extends State<RestIntro> {
  final TextPainter _wordmark = TextPainter(
    text: const TextSpan(
      text: 'REST',
      style: TextStyle(
        color: Color(0xFFDDE3F1),
        fontSize: 96,
        fontWeight: FontWeight.w600,
        letterSpacing: 14,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void dispose() {
    _wordmark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarDividerColor: Colors.black,
      ),
      child: Semantics(
        label: 'REST, starting up',
        image: true,
        child: RepaintBoundary(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _RestIntroPainter(
                widget.progress,
                _wordmark,
                reduceMotion,
              ),
              willChange: !reduceMotion,
            ),
          ),
        ),
      ),
    );
  }
}

class _RestIntroPainter extends CustomPainter {
  _RestIntroPainter(this.progress, this.wordmark, this.reduceMotion)
    : super(repaint: reduceMotion ? null : progress);

  final Animation<double> progress;
  final TextPainter wordmark;
  final bool reduceMotion;

  static final List<_Star> _stars = _makeStars();

  static List<_Star> _makeStars() {
    final random = math.Random(1807);
    return List.generate(
      210,
      (_) => _Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: 0.34 + math.pow(random.nextDouble(), 4) * 1.02,
        brightness: 0.21 + random.nextDouble() * 0.79,
        phase: random.nextDouble() * 2 * math.pi,
      ),
      growable: false,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    final time = reduceMotion ? 1.0 : progress.value;
    final center = Offset(size.width / 2, size.height * 0.48);
    final field = math.min(size.width, size.height * 1.35);
    final approach = Curves.easeOutCubic.transform(_phase(time, 0.07, 0.59));
    final lightIn = Curves.easeInOutCubic.transform(_phase(time, 0.09, 0.59));
    final settle = Curves.easeInOut.transform(_phase(time, 0.89, 1));
    final light = lightIn * (1 - 0.23 * settle);
    final spread = field * (0.83 + approach * 0.17);

    if (light > 0) {
      _glow(
        canvas,
        center + Offset(-spread * 0.21, -spread * 0.06),
        spread * 0.50,
        spread * 0.40,
        const Color(0xFFCE426E),
        light * 0.36,
      );
      _glow(
        canvas,
        center + Offset(-spread * 0.02, spread * 0.07),
        spread * 0.41,
        spread * 0.31,
        const Color(0xFF42B28E),
        light * 0.23,
      );
      _glow(
        canvas,
        center + Offset(spread * 0.22, -spread * 0.025),
        spread * 0.54,
        spread * 0.42,
        const Color(0xFF5D69EA),
        light * 0.43,
      );
      _paintStars(canvas, size, center, field, time, light);
    }

    final opacity = Curves.easeInOut.transform(_phase(time, 0.12, 0.55));
    if (opacity > 0) {
      final width = math.min(field * 0.74, 404.0) * (0.66 + approach * 0.34);
      _paintWordmark(canvas, center, width / wordmark.width, opacity, time);
    }
  }

  void _glow(
    Canvas canvas,
    Offset center,
    double radiusX,
    double radiusY,
    Color color,
    double intensity,
  ) {
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [
          color.withValues(alpha: intensity),
          color.withValues(alpha: intensity * 0.38),
          color.withValues(alpha: intensity * 0.07),
          color.withValues(alpha: 0),
        ],
        [0, 0.37, 0.71, 1],
      );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radiusX, radiusY);
    canvas.drawCircle(Offset.zero, 1, paint);
    canvas.restore();
  }

  void _paintStars(
    Canvas canvas,
    Size size,
    Offset center,
    double field,
    double time,
    double light,
  ) {
    final paint = Paint();
    for (final star in _stars) {
      final position = Offset(star.x * size.width, star.y * size.height);
      final delta = position - center;
      final distance = Offset(delta.dx / field, delta.dy / (field * 0.72));
      final exposure = math.exp(-5 * distance.distanceSquared);
      final shimmer = 0.86 + 0.14 * math.sin(time * 7 + star.phase);
      final alpha =
          light * (0.09 + 0.91 * exposure) * star.brightness * shimmer;
      final color = Color.lerp(
        const Color(0xFFF9AFC6),
        const Color(0xFFACC6FF),
        star.x,
      )!;
      if (star.size > 0.95) {
        paint.color = color.withValues(alpha: alpha * 0.18);
        canvas.drawCircle(position, star.size * 2.3, paint);
      }
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(position, star.size, paint);
    }
  }

  void _paintWordmark(
    Canvas canvas,
    Offset center,
    double scale,
    double opacity,
    double time,
  ) {
    final bounds = Offset.zero & wordmark.size;
    canvas.save();
    canvas.translate(
      center.dx - bounds.width * scale / 2,
      center.dy - bounds.height * scale / 2,
    );
    canvas.scale(scale);
    canvas.saveLayer(
      bounds,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    wordmark.paint(canvas, Offset.zero);

    if (time > 0.68 && time < 0.92) {
      final sweep = Curves.easeInOutSine.transform(_phase(time, 0.68, 0.92));
      final x = ui.lerpDouble(-62, bounds.width + 62, sweep)!;
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..shader = ui.Gradient.linear(
            Offset(x - 45, 31),
            Offset(x + 45, 48),
            const [
              Color(0x00BFCCFF),
              Color(0xFFC2D4FF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            const [0, 0.39, 0.57, 1],
          ),
      );
    }

    canvas.restore();
    canvas.restore();
  }

  static double _phase(double time, double from, double to) =>
      ((time - from) / (to - from)).clamp(0.0, 1.0).toDouble();

  @override
  bool shouldRepaint(covariant _RestIntroPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.wordmark != wordmark ||
      oldDelegate.reduceMotion != reduceMotion;
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.brightness,
    required this.phase,
  });

  final double x;
  final double y;
  final double size;
  final double brightness;
  final double phase;
}
