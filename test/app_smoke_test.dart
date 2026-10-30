import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enet_app/main.dart';

void main() {
  testWidgets('Authentication screen is available', (tester) async {
    await tester.view.setPhysicalSize(const Size(1280, 900));
    await tester.view.setDevicePixelRatio(1);
    await tester.pumpWidget(const ENetApp());
    expect(find.text('С возвращением!'), findsOneWidget);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.view.resetPhysicalSize();
  });
}
