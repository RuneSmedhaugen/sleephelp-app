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
  static const _title = 'R.E.S.T';
  static const _subtitle = 'Relaxing Environment, Sounds & Timer';

  final TextPainter _wordmark = TextPainter(
    text: const TextSpan(
      text: _title,
      style: TextStyle(
        color: Colors.white,
        fontFamily: 'Space Grotesk',
        fontVariations: [ui.FontVariation('wght', 640)],
        fontSize: 96,
        letterSpacing: 8,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final TextPainter _fullName = TextPainter(
    text: const TextSpan(
      text: _subtitle,
      style: TextStyle(
        color: Color(0xFFBCC4D6),
        fontFamily: 'Space Grotesk',
        fontVariations: [ui.FontVariation('wght', 500)],
        fontSize: 19,
        letterSpacing: 0.9,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void dispose() {
    _wordmark.dispose();
    _fullName.dispose();
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
        label: '$_subtitle, starting up',
        image: true,
        child: RepaintBoundary(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _RestIntroPainter(
                widget.progress,
                _wordmark,
                _fullName,
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
  _RestIntroPainter(
    this.progress,
    this.wordmark,
    this.fullName,
    this.reduceMotion,
  ) : super(repaint: reduceMotion ? null : progress);

  final Animation<double> progress;
  final TextPainter wordmark;
  final TextPainter fullName;
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
    if (size.isEmpty) return;

    final time = reduceMotion ? 1.0 : progress.value;
    final center = Offset(size.width / 2, size.height * 0.48);
    final field = math.min(size.width, size.height * 1.35);
    final approach = Curves.easeOutQuad.transform(time);
    final light = _reveal(time);
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

    final opacity = _reveal(_phase(time, 0.035, 1));
    if (opacity > 0) {
      final width = math.min(field * 0.80, 440.0) * (0.80 + approach * 0.20);
      final scale = width / math.max(wordmark.width, fullName.width);
      _paintBrand(canvas, center, scale, opacity, time);
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
      final shimmer = 0.93 + 0.07 * math.sin(time * 7 + star.phase);
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

  void _paintBrand(
    Canvas canvas,
    Offset center,
    double scale,
    double opacity,
    double time,
  ) {
    final bounds = Offset.zero & wordmark.size;
    final subtitleOffset = Offset(
      (wordmark.width - fullName.width) / 2,
      wordmark.height + 3,
    );
    final subtitleBounds = subtitleOffset & fullName.size;
    final baseline = wordmark.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    canvas.save();
    canvas.translate(
      center.dx - bounds.width * scale / 2,
      center.dy - subtitleBounds.bottom * scale / 2,
    );
    canvas.scale(scale);
    canvas.saveLayer(
      bounds,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    wordmark.paint(canvas, Offset.zero);
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.srcIn
        ..shader = ui.Gradient.linear(
          Offset(0, baseline - 70),
          Offset(0, baseline),
          const [
            Color(0xFFB1BDCE),
            Color(0xFFF4F8FF),
            Color(0xFF8B9AAF),
            Color(0xFFCDD7E5),
            Color(0xFF9EACC1),
          ],
          const [0, 0.25, 0.52, 0.80, 1],
        ),
    );

    if (time > 0.68 && time < 1) {
      final sweep = Curves.easeInOutSine.transform(_phase(time, 0.68, 1));
      final x = ui.lerpDouble(-62, bounds.width + 62, sweep)!;
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..shader = ui.Gradient.linear(
            Offset(x - 45, baseline - 55),
            Offset(x + 45, baseline - 38),
            const [
              Color(0x00BFCCFF),
              Color(0x66C2D4FF),
              Color(0xA6FFFFFF),
              Color(0x00FFFFFF),
            ],
            const [0, 0.39, 0.57, 1],
          ),
      );
    }

    canvas.restore();

    final subtitleOpacity = _reveal(_phase(time, 0.11, 1));
    canvas.saveLayer(
      subtitleBounds,
      Paint()..color = Colors.white.withValues(alpha: subtitleOpacity),
    );
    fullName.paint(canvas, subtitleOffset);
    canvas.restore();
    canvas.restore();
  }

  // Keep some opacity change in the last frames while making the reveal
  // visible early enough to distinguish it from a blank loading screen.
  static double _reveal(double time) =>
      0.65 * time + 0.35 * Curves.easeInOutSine.transform(time);

  static double _phase(double time, double from, double to) =>
      ((time - from) / (to - from)).clamp(0.0, 1.0).toDouble();

  @override
  bool shouldRepaint(covariant _RestIntroPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.wordmark != wordmark ||
      oldDelegate.fullName != fullName ||
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
