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
    duration: const Duration(seconds: 28),
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
                          fontFamily: 'REST Ribbon',
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
                            fontFamily: 'REST Ribbon',
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
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff090c1b), Color(0xff1c1736), Color(0xff10172d)],
        ).createShader(bounds),
    );

    final phase = animation.value * math.pi * 2;
    final scale = size.shortestSide;
    final colors = [
      const Color(0xff9372cb),
      const Color(0xff728ec1),
      const Color(0xffb37eac),
      const Color(0xff7971c0),
      const Color(0xff6b9fab),
    ];
    // Large translucent forms continuously stretch, overlap and travel across
    // the canvas. Integer phase multiples make the loop meet seamlessly.
    for (var i = 0; i < colors.length; i++) {
      final angle = phase + i * math.pi * 2 / colors.length;
      final center = Offset(
        size.width * (.5 + .39 * math.sin(angle)),
        size.height * (.5 + .36 * math.cos(angle + i * .7)),
      );
      final width = scale * (.31 + .08 * math.sin(phase * 2 + i));
      final height = scale * (.47 + .12 * math.cos(phase + i * 1.3));
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(.45 * math.sin(phase + i));
      final glow = Rect.fromCenter(
        center: Offset.zero,
        width: width * 3.7,
        height: height * 3.7,
      );
      canvas.drawOval(
        glow,
        Paint()
          ..shader = RadialGradient(
            colors: [
              colors[i].withValues(alpha: .15),
              colors[i].withValues(alpha: .055),
              Colors.transparent,
            ],
            stops: const [0, .48, 1],
          ).createShader(glow),
      );
      for (var layer = 2; layer >= 0; layer--) {
        final multiplier = 1.0 + layer * .14;
        final path = Path();
        for (var step = 0; step <= 96; step++) {
          final theta = step * math.pi * 2 / 96;
          final ripple =
              1 +
              .14 * math.sin(theta * 3 + phase + i) +
              .08 * math.cos(theta * 2 - phase * 2 + i);
          final x = math.cos(theta) * width * multiplier * ripple;
          final y = math.sin(theta) * height * multiplier * ripple;
          if (step == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        final shapeBounds = Rect.fromCenter(
          center: Offset.zero,
          width: width * multiplier * 2.8,
          height: height * multiplier * 2.8,
        );
        canvas.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-.3, -.4),
              radius: .85,
              colors: [
                colors[i].withValues(alpha: .19 - layer * .035),
                colors[i].withValues(alpha: .025),
                Colors.transparent,
              ],
              stops: const [0, .7, 1],
            ).createShader(shapeBounds),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = colors[i].withValues(alpha: .12 - layer * .025),
        );
      }
      canvas.restore();
    }
    // A soft reading area keeps the clock legible as the forms pass behind it.
    final shade = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * .9,
      height: size.height * .8,
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xff0c0d20).withValues(alpha: .4),
            Colors.transparent,
          ],
        ).createShader(shade),
    );
  }

  @override
  bool shouldRepaint(covariant _NightPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
