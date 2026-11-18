import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../models/rest_style.dart';
import '../services/language_preference.dart';
import '../services/theme_storage.dart';
import '../widgets/rest_artwork.dart';
import 'language_settings_screen.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
        children: [
          Text(
            context.t(L.settings),
            style: TextStyle(
              color: style.text,
              fontSize: 27,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 22),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(context.t(L.theme)),
              subtitle: Text(RestStyle.selected.value.name),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _ThemeSettingsScreen(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(context.t(L.language)),
              subtitle: ValueListenableBuilder(
                valueListenable: LanguagePreference.selected,
                builder: (context, locale, _) => Text(
                  locale == null ? context.t(L.system) : languageName(locale),
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LanguageSettingsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSettingsScreen extends StatelessWidget {
  const _ThemeSettingsScreen();

  Future<void> _selectTheme(BuildContext context, RestStyle style) async {
    RestStyle.selected.value = style;
    try {
      await ThemeStorage.save(style);
    } catch (error) {
      debugPrint('Could not save theme: $error');
      if (!context.mounted || RestStyle.selected.value != style) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t(L.themeSaveError))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t(L.theme))),
    body: SafeArea(
      child: ValueListenableBuilder<RestStyle>(
        valueListenable: RestStyle.selected,
        builder: (context, selected, _) => ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(context.t(L.chooseTheme)),
            ),
            for (final style in RestStyle.all)
              _StyleCard(
                style: style,
                selected: identical(style, selected),
                onTap: () => _selectTheme(context, style),
              ),
          ],
        ),
      ),
    ),
  );
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
