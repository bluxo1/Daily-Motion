import 'package:flutter/material.dart';

ThemeData motionTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final accent = Color(dark ? 0xFF9BD8BE : 0xFF245C48);
  final background = Color(dark ? 0xFF0B0D10 : 0xFFF5F7F9);
  final surface = Color(dark ? 0xFF151A20 : 0xFFFFFFFF);
  final text = Color(dark ? 0xFFF4F6F8 : 0xFF101820);
  final secondary = Color(dark ? 0xFFAAB4C0 : 0xFF4B5967);
  final theme = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
        .copyWith(
          primary: accent,
          onPrimary: Color(dark ? 0xFF102019 : 0xFFFFFFFF),
          surface: surface,
          onSurface: text,
          onSurfaceVariant: secondary,
          error: Color(dark ? 0xFFFF8F91 : 0xFFA82332),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.all(16),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  return theme.copyWith(
    textTheme: theme.textTheme
        .apply(bodyColor: text, displayColor: text)
        .copyWith(
          bodyLarge: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 17,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
  );
}
