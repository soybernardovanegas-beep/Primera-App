import 'package:flutter/material.dart';

/// Paleta y tipografía del diario: papel crema, tinta negra y rojo ladrillo.
class AppColors {
  static const paper = Color(0xFFF6F4EF);
  static const ink = Color(0xFF1C1B19);
  static const muted = Color(0xFF6F6B66);
  static const faint = Color(0xFFB5B0A8);
  static const line = Color(0xFFDEDAD3);
  static const accent = Color(0xFF8B2C1C);
}

/// Títulos con serifa (Cinzel: las minúsculas salen como versalitas).
const serif = 'Cinzel';

/// Texto general.
const sans = 'PlusJakartaSans';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    surface: AppColors.paper,
    onSurface: AppColors.ink,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: sans,
    scaffoldBackgroundColor: AppColors.paper,
    dividerColor: AppColors.line,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: serif,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Etiqueta en mayúsculas espaciadas ("PERSONAS A MOVER HOY").
TextStyle labelStyle({Color color = AppColors.muted, double size = 13}) =>
    TextStyle(
      fontFamily: sans,
      fontSize: size,
      letterSpacing: 3,
      fontWeight: FontWeight.w500,
      color: color,
    );
