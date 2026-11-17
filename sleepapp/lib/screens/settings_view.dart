import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';
import '../services/theme_storage.dart';
import '../widgets/rest_artwork.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  Future<void> _selectTheme(BuildContext context, RestStyle style) async {
    RestStyle.selected.value = style;
    try {
      await ThemeStorage.save(style);
    } catch (error) {
      debugPrint('Could not save theme: $error');
      if (!context.mounted || RestStyle.selected.value != style) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Theme applied. REST couldn’t save it for next time.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = RestStyle.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
        children: [
          Text(
            'Settings',
            style: TextStyle(
              color: current.text,
              fontSize: 27,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Appearance',
            style: TextStyle(
              color: current.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a style to apply it.',
            style: TextStyle(color: current.quaternary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<RestStyle>(
            valueListenable: RestStyle.selected,
            builder: (context, selected, _) => Column(
              children: [
                for (final style in RestStyle.all)
                  _StyleCard(
                    style: style,
                    selected: identical(style, selected),
                    onTap: () => _selectTheme(context, style),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final RestStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: style.background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? style.primary : style.outline),
        ),
        child: InkWell(
          onTap: onTap,
          child: Ink(
            color: style.background,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: RestArtworkPanel(style: style),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              style.name,
                              style: TextStyle(
                                color: style.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    color: style.background,
                                    blurRadius: 9,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 11),
                            ExcludeSemantics(
                              child: Row(
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: style.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: style.onAccent,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Icon(
                                    Icons.timer_outlined,
                                    color: style.secondary,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 7),
                                  Icon(
                                    Icons.graphic_eq_rounded,
                                    color: style.tertiary,
                                    size: 19,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: style.background,
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: style.primary,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
