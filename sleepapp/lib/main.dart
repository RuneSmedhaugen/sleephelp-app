import 'package:flutter/material.dart';

import 'screens/startup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SleepApp());
}

class SleepApp extends StatelessWidget {
  const SleepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REST',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFFB4A8EC),
              brightness: Brightness.dark,
            ).copyWith(
              surface: const Color(0xFF111726),
              primary: const Color(0xFFB4A8EC),
              secondary: const Color(0xFF9ED9CC),
            ),
        scaffoldBackgroundColor: const Color(0xFF0D1220),
        useMaterial3: true,
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF111726),
          indicatorColor: const Color(0xFF393452),
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? const Color(0xFFE5E0FF)
                  : const Color(0xFF8994AA),
            );
          }),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFFB4A8EC),
          inactiveTrackColor: Color(0xFF353D51),
          thumbColor: Color(0xFFD2C9FF),
          overlayColor: Color(0x33B4A8EC),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF171D2D),
          hintStyle: const TextStyle(color: Color(0xFF7F8BA1)),
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
            borderSide: const BorderSide(color: Color(0xFF8E82C5)),
          ),
        ),
      ),
      home: const StartupScreen(),
    );
  }
}
