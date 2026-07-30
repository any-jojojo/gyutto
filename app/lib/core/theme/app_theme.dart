import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return _buildTheme(Brightness.light);
  }

  static ThemeData dark() {
    return _buildTheme(Brightness.dark);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppConstants.seedColor,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? AppConstants.hopeColor
          : colorScheme.surface,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: brightness == Brightness.light
            ? AppConstants.inkColor
            : null,
        titleTextStyle: TextStyle(
          color: brightness == Brightness.light
              ? AppConstants.inkColor
              : colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: AppConstants.inkColor,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: AppConstants.inkColor,
          side: BorderSide(
            color: AppConstants.inkColor.withValues(alpha: 0.48),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        floatingLabelStyle: const TextStyle(
          color: AppConstants.inkColor,
          fontWeight: FontWeight.w700,
        ),
        labelStyle: TextStyle(
          color: AppConstants.inkColor.withValues(alpha: 0.78),
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: AppConstants.inkColor.withValues(alpha: 0.72),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppConstants.inkColor.withValues(alpha: 0.38),
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppConstants.inkColor, width: 1.4),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppConstants.inkColor,
        selectionColor: AppConstants.connectionColor.withValues(alpha: 0.48),
        selectionHandleColor: AppConstants.inkColor,
      ),
    );
  }
}
