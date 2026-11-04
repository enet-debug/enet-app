import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';

/// Палитра eNet. Глубокий «чернильный» фон, стекло и холодный неоновый акцент.
abstract final class ENetColors {
  static const background = Color(0xFF04070F);
  static const surface = Color(0xFF0B1220);
  static const surfaceRaised = Color(0xFF121B2E);
  static const border = Color(0x1AFFFFFF);
  static const cyan = Color(0xFF5CE5FF);
  static const blue = Color(0xFF3C93FF);
  static const violet = Color(0xFF8B7CFF);
  static const mint = Color(0xFF4EE3B0);
  static const danger = Color(0xFFFF6B81);
  static const text = Color(0xFFF5F8FF);
  static const muted = Color(0xFF9BA9C1);
  static const faint = Color(0xFF6E7C95);
  static const onAccent = Color(0xFF031425);

  static const accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7DF0FF), Color(0xFF3C93FF)],
  );
  static const violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB4A8FF), Color(0xFF6C5CFF)],
  );
  static const mintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7BF3CF), Color(0xFF1FB58A)],
  );
  static const amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC46B), Color(0xFFFF8A4C)],
  );
}

/// Единые параметры движения, чтобы все анимации «дышали» в одном ритме.
abstract final class ENetMotion {
  static const quick = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 380);
  static const slow = Duration(milliseconds: 700);
  static const curve = Curves.easeOutQuart;
}

/// Плавная «пружинная» прокрутка на всех платформах, drag мышью на ПК.
class ENetScrollBehavior extends MaterialScrollBehavior {
  const ENetScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

abstract final class ENetTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: ENetColors.cyan,
      onPrimary: ENetColors.onAccent,
      secondary: ENetColors.blue,
      surface: ENetColors.background,
      onSurface: ENetColors.text,
      error: ENetColors.danger,
    );

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ENetColors.background,
      colorScheme: scheme,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerTheme: const DividerThemeData(color: ENetColors.border, thickness: 1, space: 1),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16, color: ENetColors.text),
        bodyMedium: TextStyle(fontSize: 14, color: ENetColors.muted, height: 1.5),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ENetColors.cyan,
        selectionColor: Color(0x553C93FF),
        selectionHandleColor: ENetColors.cyan,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x0FFFFFFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: const TextStyle(color: ENetColors.faint),
        floatingLabelStyle: const TextStyle(color: ENetColors.cyan, fontWeight: FontWeight.w600),
        errorStyle: const TextStyle(color: ENetColors.danger, fontSize: 12),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused) ? ENetColors.cyan : ENetColors.faint,
        ),
        suffixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused) ? ENetColors.cyan : ENetColors.faint,
        ),
        border: border(ENetColors.border),
        enabledBorder: border(ENetColors.border),
        focusedBorder: border(ENetColors.cyan, 1.5),
        errorBorder: border(ENetColors.danger.withValues(alpha: .7)),
        focusedErrorBorder: border(ENetColors.danger, 1.5),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ENetColors.cyan,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      iconTheme: const IconThemeData(color: ENetColors.muted),
    );
  }
}
