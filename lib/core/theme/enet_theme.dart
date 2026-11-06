import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';

/// Палитра eNet 0.7: глубокий изумрудный фон и мятные акценты.
abstract final class ENetColors {
  static const background = Color(0xFF031A1C);
  static const surface = Color(0xFF07282A);
  static const surfaceRaised = Color(0xFF124039);
  static const border = Color(0x5540EAC2);
  static const cyan = Color(0xFF38F9D0);
  static const blue = Color(0xFF11BEAD);
  static const violet = Color(0xFF77CFC0);
  static const mint = Color(0xFF25F5B5);
  static const danger = Color(0xFFFF8892);
  static const text = Color(0xFFF4FFF9);
  static const muted = Color(0xFFB1CAC6);
  static const faint = Color(0xFF719F98);
  static const onAccent = Color(0xFF042522);

  static const accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5AFFF0), Color(0xFF13DEA3)],
  );
  static const violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF77D8C5), Color(0xFF277C70)],
  );
  static const mintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF69FFE2), Color(0xFF11C990)],
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
      fontFamily: 'Roboto',
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
        selectionColor: Color(0x5543C99C),
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
