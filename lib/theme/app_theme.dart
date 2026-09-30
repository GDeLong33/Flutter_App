import 'package:flutter/material.dart';

import '../models/game.dart';

/// "Game night" palette: deep navy field, bright scoreboard accents.
class AppColors {
  static const background = Color(0xFF0A0E16);
  static const surface = Color(0xFF131A26);
  static const surfaceHigh = Color(0xFF1B2433);
  static const outline = Color(0xFF263041);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textMuted = Color(0xFF8A97AB);
  static const live = Color(0xFF22C55E);
  static const accent = Color(0xFFFACC15); // scoreboard yellow
  static const finalGame = Color(0xFF94A3B8);
  static const upcoming = Color(0xFF475569);
  static const danger = Color(0xFFF87171);
  static const positive = Color(0xFF4ADE80);
  static const negative = Color(0xFFF87171);

  static Color forState(GameState? state) => switch (state) {
        GameState.live => live,
        GameState.finished => finalGame,
        _ => upcoming,
      };
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.live,
    brightness: Brightness.dark,
  ).copyWith(
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    primary: AppColors.live,
    secondary: AppColors.accent,
    error: AppColors.danger,
    outline: AppColors.outline,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: AppColors.textPrimary,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outline, thickness: 1),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      isDense: true,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
