import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../services/language_preference.dart';

// Display names are in their own language so users can find them in any locale.
const _languages = [
  (
    Locale('de'),
    'Deutsch',
    'German Germany Deutschland allemand alemán tysk Tyskland Allemagne Alemania Austria Österreich Schweiz',
  ),
  (
    Locale('en'),
    'English',
    'Engelsk anglais inglés Englisch United Kingdom UK United States USA England Australia Canada',
  ),
  (
    Locale('es'),
    'Español',
    'Spanish Spansk Spanisch espagnol Spain España Spania Espagne Spanien México Mexico Latin America',
  ),
  (
    Locale('fr'),
    'Français',
    'French Fransk Französisch francés France Frankrike Frankreich Francia Canada Belgique',
  ),
  (
    Locale('nb'),
    'Norsk bokmål',
    'Norwegian Norway Norge Norwegian Bokmal Norvégien Noruego norwegisch Norvège Noruega Norwegen Noreg',
  ),
];

String languageName(Locale locale) =>
    _languages.firstWhere((item) => item.$1 == locale).$2;

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final _search = TextEditingController();
  String _query = '';

  String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp('[àáâäå]'), 'a')
      .replaceAll(RegExp('[èéêë]'), 'e')
      .replaceAll(RegExp('[ìíîï]'), 'i')
      .replaceAll(RegExp('[òóôöø]'), 'o')
      .replaceAll(RegExp('[ùúûü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('ç', 'c');

  bool _matches(String text) {
    final normalized = _normalize(text);
    return _query.split(RegExp(r'\s+')).every(normalized.contains);
  }

  Future<void> _select(Locale? locale) async {
    try {
      await LanguagePreference.save(locale);
    } catch (error) {
      debugPrint('Could not save language: $error');
      if (!mounted || LanguagePreference.selected.value != locale) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(L.languageSaveError))));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final system = context.t(L.system);
    final visible = _languages.where(
      (item) => _matches('${item.$2} ${item.$3}'),
    );
    final showSystem = _matches('$system System');
    return Scaffold(
      appBar: AppBar(title: Text(context.t(L.language))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
              child: TextField(
                controller: _search,
                onChanged: (value) =>
                    setState(() => _query = _normalize(value.trim())),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.t(L.searchLanguages),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.t(L.clearSearch),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<Locale?>(
                valueListenable: LanguagePreference.selected,
                builder: (context, selected, _) => ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  children: [
                    if (showSystem) _option(null, system, selected),
                    for (final (locale, name, _) in visible)
                      _option(locale, name, selected),
                    if (!showSystem && visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(context.t(L.noLanguages)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(Locale? locale, String name, Locale? selected) => Card(
    child: ListTile(
      title: Text(name),
      selected: locale == selected,
      trailing: locale == selected ? const Icon(Icons.check_rounded) : null,
      onTap: () {
        FocusScope.of(context).unfocus();
        _select(locale);
      },
    ),
  );
}
