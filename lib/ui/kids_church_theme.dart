import 'package:flutter/material.dart';

abstract final class KidsChurchColors {
  static const background = Color(0xFF0B0F14);
  static const surface = Color(0xFF111826);
  static const surfaceAlt = Color(0xFF0F1622);
  static const border = Color(0x14FFFFFF);
  static const text = Color(0xEBFFFFFF);
  static const muted = Color(0x9EFFFFFF);
  static const accent = Color(0xFF2ECC71);
  static const danger = Color(0xFFFF5A5F);
}

ThemeData kidsChurchTheme() {
  const scheme = ColorScheme.dark(
    primary: KidsChurchColors.accent,
    secondary: KidsChurchColors.accent,
    surface: KidsChurchColors.surface,
    error: KidsChurchColors.danger,
    onPrimary: Colors.black,
    onSurface: KidsChurchColors.text,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(999),
    side: const BorderSide(color: KidsChurchColors.border),
  );
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: KidsChurchColors.background,
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: KidsChurchColors.surfaceAlt,
      foregroundColor: KidsChurchColors.text,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: KidsChurchColors.surfaceAlt,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: KidsChurchColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KidsChurchColors.surface,
      hintStyle: const TextStyle(color: KidsChurchColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: KidsChurchColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: KidsChurchColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: KidsChurchColors.accent)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0x2E2ECC71),
        foregroundColor: KidsChurchColors.text,
        shape: rounded,
        side: const BorderSide(color: Color(0x732ECC71)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KidsChurchColors.text,
        backgroundColor: KidsChurchColors.surface,
        shape: rounded,
        side: const BorderSide(color: KidsChurchColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: KidsChurchColors.surfaceAlt,
      indicatorColor: const Color(0x1A2ECC71),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            color: states.contains(WidgetState.selected) ? KidsChurchColors.accent : KidsChurchColors.muted,
            fontSize: 12,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? KidsChurchColors.accent : KidsChurchColors.muted,
          )),
    ),
  );
}
