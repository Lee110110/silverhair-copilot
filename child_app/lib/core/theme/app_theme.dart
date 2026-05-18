import 'package:flutter/material.dart';

class AppTheme {
  // Color palette - blue/teal for child app (vs red for elderly)
  static const Color primary = Color(0xFF1565C0); // Blue
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color secondary = Color(0xFF00897B); // Teal
  static const Color background = Color(0xFFF5F7FA); // Light cool gray
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color danger = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF57C00);
  static const Color sosRed = Color(0xFFE53935);

  // Typography - slightly smaller than elderly app
  static const double fontSizeTitle = 24.0;
  static const double fontSizeBody = 18.0;
  static const double fontSizeButton = 16.0;
  static const double fontSizeCaption = 14.0;
  static const double fontSizeHint = 14.0;

  // Spacing
  static const double buttonHeight = 48.0;
  static const double buttonMinWidth = 160.0;
  static const double iconSize = 24.0;
  static const double paddingLarge = 24.0;
  static const double paddingMedium = 16.0;
  static const double paddingSmall = 8.0;

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      error: danger,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(fontSize: fontSizeTitle, fontWeight: FontWeight.bold),
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: fontSizeTitle, fontWeight: FontWeight.bold, color: textPrimary),
      headlineMedium: TextStyle(fontSize: fontSizeTitle, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: TextStyle(fontSize: fontSizeBody, color: textPrimary),
      bodyMedium: TextStyle(fontSize: fontSizeBody, color: textSecondary),
      labelLarge: TextStyle(fontSize: fontSizeButton, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: fontSizeHint),
      labelSmall: TextStyle(fontSize: fontSizeCaption, color: textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(buttonMinWidth, buttonHeight),
        textStyle: const TextStyle(fontSize: fontSizeButton, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: paddingLarge, vertical: paddingMedium),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(width: 1),
      ),
      labelStyle: const TextStyle(fontSize: fontSizeHint),
      hintStyle: const TextStyle(fontSize: fontSizeHint, color: textSecondary),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(paddingMedium),
    ),
    iconTheme: const IconThemeData(size: iconSize),
  );
}
