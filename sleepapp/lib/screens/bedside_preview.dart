import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';

/// A visual concept for the browser showcase, independent of the active theme.
class BedsidePreview extends StatefulWidget {
  const BedsidePreview({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onStop,
    required this.mixName,
    required this.alarmAt,
    required this.visible,
  });
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final String? mixName;
  final DateTime? alarmAt;
  final bool visible;

  @override
  State<BedsidePreview> createState() => _BedsidePreviewState();
}

class _BedsidePreviewState extends State<BedsidePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 32),
  )..repeat();
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && widget.visible) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(_now).format(context);
    final alarm = widget.alarmAt;
    return TickerMode(
      enabled: widget.visible && !MediaQuery.disableAnimationsOf(context),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(painter: _NightPainter(_animation)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape =
                      constraints.maxWidth > constraints.maxHeight * 1.25;
                  final clockSize = math
                      .min(
                        landscape
                            ? constraints.maxHeight * .24
                            : constraints.maxWidth * .21,
                        100.0,
                      )
                      .clamp(38.0, 100.0);
                  final content = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'R.E.S.T.',
                        style: TextStyle(
                          color: const Color(0xffb8aadf).withValues(alpha: .7),
                          fontFamily: 'Space Grotesk',
                          fontSize: 12,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          time,
                          maxLines: 1,
                          style: TextStyle(
                            color: const Color(0xffd5cbe9)
                                .withValues(alpha: .88),
                            fontFamily: 'Nunito',
                            fontSize: clockSize,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                      Text(
                        MaterialLocalizations.of(context).formatFullDate(_now),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xff8d87a8),
                          fontSize: 13,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.mixName ?? context.t(L.soundscape),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xffb2aaca),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alarm == null
                            ? context.t(L.noAlarms)
                            : '${context.t(L.alarms)} · ${TimeOfDay.fromDateTime(alarm).format(context)}',
                        style: const TextStyle(
                          color: Color(0xff827c9c),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _control(
                            Icons.stop_rounded,
                            context.t(L.stop),
                            widget.onStop,
                            false,
                          ),
                          const SizedBox(width: 16),
                          _control(
                            widget.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            context.t(widget.isPlaying ? L.pause : L.play),
                            widget.onPlayPause,
                            true,
                          ),
                        ],
                      ),
                    ],
                  );
                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: landscape ? 12 : 24,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: content,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _control(
    IconData icon,
    String tooltip,
    VoidCallback action,
    bool primary,
  ) => Tooltip(
    message: tooltip,
    child: Material(
      color: primary
          ? const Color(0xffaaa0d4).withValues(alpha: .23)
          : const Color(0xffaaa0d4).withValues(alpha: .08),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: action,
        icon: Icon(icon),
        color: const Color(0xffc6bde0),
        iconSize: primary ? 30 : 23,
        padding: EdgeInsets.all(primary ? 14 : 11),
      ),
    ),
  );
}

class _NightPainter extends CustomPainter {
  _NightPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff0a0d1e), Color(0xff17142d), Color(0xff101722)],
        ).createShader(rect),
    );
    final phase = animation.value * math.pi * 2;
    final moon = Offset(
      size.width * (.75 + .018 * math.sin(phase)),
      size.height * (.25 + .015 * math.cos(phase)),
    );
    final radius = math.min(size.width, size.height) * .085;
    for (var layer = 0; layer < 3; layer++) {
      final drift = math.sin(phase + layer * 1.5);
      final center = Offset(
        size.width * (.2 + layer * .31 + drift * .055),
        size.height * (.36 + layer * .09 + math.cos(phase + layer) * .04),
      );
      final glowRadius = size.longestSide * (.35 + layer * .06);
      canvas.drawCircle(
        center,
        glowRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              [
                const Color(0xff735caa),
                const Color(0xff4f729a),
                const Color(0xff9972a5),
              ][layer].withValues(alpha: .045 + .014 * (1 + drift)),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
      );
    }
    final glowRadius = radius * (3.1 + .3 * math.sin(phase));
    canvas.drawCircle(
      moon,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xff9f8dca)
                .withValues(alpha: .16 + .035 * (1 + math.sin(phase))),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: moon, radius: glowRadius)),
    );
    final moonShape = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moon, radius: radius)),
      Path()..addOval(
        Rect.fromCircle(
          center: moon.translate(radius * .42, -radius * .24),
          radius: radius * .9,
        ),
      ),
    );
    canvas.drawPath(
      moonShape,
      Paint()..color = const Color(0xffb3a6d5).withValues(alpha: .42),
    );
    for (var i = 0; i < 35; i++) {
      final x =
          (((i * 73 + 17) % 997) / 997 + .012 * math.sin(phase + i * .8)) *
          size.width;
      final y =
          (((i * 137 + 83) % 787) / 787 * .75 +
              .012 * math.cos(phase + i * 1.3)) *
          size.height;
      final opacity = .12 + .15 * (1 + math.sin(phase + i * 2.1)) / 2;
      canvas.drawCircle(
        Offset(x, y),
        i % 8 == 0 ? 1.3 : .7,
        Paint()..color = const Color(0xffc6b9ed).withValues(alpha: opacity),
      );
    }
    for (var layer = 0; layer < 3; layer++) {
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width + 4; x += 4) {
        final y =
            size.height * (.73 + layer * .075) +
            math.sin(x / size.width * 4.2 + phase + layer * 1.2) *
                size.height *
                .025 +
            math.sin(x / size.width * 8 - phase) * size.height * .012;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = [
            const Color(0xff6d5b98),
            const Color(0xff5b6e91),
            const Color(0xff4c587d),
          ][layer].withValues(alpha: .10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NightPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
