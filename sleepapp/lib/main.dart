import 'package:material_ui/material_ui.dart';

import 'l10n/rest_strings.dart';
import 'models/rest_style.dart';
import 'screens/startup_screen.dart';
import 'services/language_preference.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SleepApp());
}

class SleepApp extends StatelessWidget {
  const SleepApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      RestStyle.selected,
      LanguagePreference.selected,
    ]),
    builder: (context, _) {
      final style = RestStyle.selected.value;
      return MaterialApp(
        title: 'REST',
        locale: LanguagePreference.selected.value,
        supportedLocales: RestStrings.supportedLocales,
        localeListResolutionCallback: RestStrings.resolve,
        localizationsDelegates: [
          RestStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(
                seedColor: style.primary,
                brightness: Brightness.dark,
              ).copyWith(
                surface: style.surface,
                onSurface: style.text,
                onSurfaceVariant: style.quaternary,
                surfaceContainer: style.panel,
                surfaceContainerHigh: style.raised,
                primary: style.primary,
                onPrimary: style.onAccent,
                secondaryContainer: style.tint(style.secondary, 0.19),
                onSecondaryContainer: style.text,
                secondary: style.secondary,
                tertiary: style.tertiary,
              ),
          scaffoldBackgroundColor: style.background,
          extensions: [style],
          cardTheme: CardThemeData(
            color: style.panel,
            surfaceTintColor: Colors.transparent,
          ),
          dialogTheme: DialogThemeData(backgroundColor: style.raised),
          bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: style.surface,
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: style.raised,
            contentTextStyle: TextStyle(color: style.text),
          ),
          useMaterial3: true,
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: style.surface,
            indicatorColor: style.primary.withValues(alpha: 0.24),
            elevation: 0,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              return IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? style.primary
                    : style.quaternary,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? style.text : style.quaternary,
              );
            }),
          ),
          sliderTheme: SliderThemeData(
            activeTrackColor: style.volumeAccent ?? style.primary,
            inactiveTrackColor: style.quaternary.withValues(alpha: 0.35),
            thumbColor: style.volumeAccent ?? style.secondary,
            overlayColor: (style.volumeAccent ?? style.primary).withValues(
              alpha: 0.2,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: style.surface,
            hintStyle: TextStyle(color: style.quaternary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: style.primary),
            ),
          ),
        ),
        home: const StartupScreen(),
      );
    },
  );
}
