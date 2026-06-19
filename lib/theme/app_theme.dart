import 'package:flutter/material.dart';

// LexNLand Customer — deep purple brand
class C {
  // LexNLand brand — raspberry/maroon (from reference design)
  static const primary = Color(0xFFAA3D67); // primary500
  static const primaryLight = Color(0xFFF6E8EE); // primary100
  static const primaryMid = Color(0xFFC1577F); // primary400
  static const primaryDark = Color(0xFF722545); // primary700
  static const accent = Color(0xFFD4A853); // gold (kept)
  static const success = Color(0xFF2E7D32);
  static const successBg = Color(0xFFE8F5E9);
  static const error = Color(0xFFC62828);
  static const errorBg = Color(0xFFFFEBEE);
  static const warning = Color(0xFFE65100);
  static const bg = Color(0xFFFAF6F8); // light maroon tint
  static const card = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF6B6B6B);
  static const textLight = Color(0xFFB0B0B0);
  static const border = Color(0xFFEAD9E1); // light maroon tint
}

ThemeData customerTheme() => ThemeData(
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: C.bg,
      primaryColor: C.primary,
      colorScheme:
          ColorScheme.fromSeed(seedColor: C.primary, primary: C.primary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: C.textDark,
        elevation: 0,
        titleTextStyle: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: C.textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: C.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C.primary, width: 1.8)),
        labelStyle: const TextStyle(color: C.textMuted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
