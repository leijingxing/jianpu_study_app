import 'package:flutter/material.dart';

const brandColor = Color(0xFF4F9F98);
const inkColor = Color(0xFF17212B);
const paperColor = Color(0xFFF5F7F2);
const accentColor = Color(0xFFE87558);
const mutedTextColor = Color(0xFF68747C);
const lineColor = Color(0xFFE3E8E2);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandColor,
      primary: brandColor,
      secondary: accentColor,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: paperColor,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: paperColor,
      foregroundColor: inkColor,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: brandColor, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
