import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enet_app/core/theme/enet_theme.dart';

void main() {
  test('eNet design system uses a dark theme', () {
    expect(ENetTheme.dark.brightness, Brightness.dark);
    expect(ENetColors.mint, isA<Color>());
  });
}
