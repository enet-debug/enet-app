import 'package:enet_app/core/theme/enet_theme.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/presentation/api_connection_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Connection panel shows endpoint, checks API, and opens editor', (tester) async {
    final auth = AuthController(DemoAuthRepository());
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: ApiConnectionPanel(auth: auth))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('http://127.0.0.1:8787'), findsOneWidget);
    await tester.tap(find.text('Проверить'));
    await tester.pumpAndSettle();
    expect(find.text('Нет ответа от сервера'), findsOneWidget);
    await tester.tap(find.text('Изменить адрес'));
    await tester.pumpAndSettle();
    expect(find.text('Адрес eNet API'), findsOneWidget);
    expect(find.byKey(const ValueKey('api-endpoint-field')), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
  });
}
