import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';

/// Translucent surfaces keep the scene visible without fading the controls.
class TonightPanel extends StatelessWidget {
  const TonightPanel({super.key, required this.child, this.radius = 21});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: style.primary.withValues(alpha: 0.20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            style.panel.withValues(alpha: 0.72),
            style.background.withValues(alpha: 0.56),
          ],
        ),
      ),
      child: child,
    );
  }
}
