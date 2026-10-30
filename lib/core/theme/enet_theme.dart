import 'package:flutter/material.dart';

abstract final class ENetColors {
  static const background = Color(0xFF050A16);
  static const surface = Color(0xFF0C1928);
  static const surfaceRaised = Color(0xFF112237);
  static const border = Color(0xFF24415A);
  static const cyan = Color(0xFF5CE5FF);
  static const blue = Color(0xFF3C93FF);
  static const text = Color(0xFFF2FAFF);
  static const muted = Color(0xFF91B0C8);
}

abstract final class ENetTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(seedColor: ENetColors.cyan, brightness: Brightness.dark, surface: ENetColors.background);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ENetColors.background,
      colorScheme: scheme,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.7),
        headlineMedium: TextStyle(fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -1),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 14, color: ENetColors.muted, height: 1.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ENetColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        hintStyle: const TextStyle(color: Color(0xFF6C8CA5)),
        prefixIconColor: ENetColors.muted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: ENetColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: ENetColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: ENetColors.cyan, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFFF7F91))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ENetColors.cyan,
          foregroundColor: const Color(0xFF061627),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      iconTheme: const IconThemeData(color: ENetColors.muted),
    );
  }
}
