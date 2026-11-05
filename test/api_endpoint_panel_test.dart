import 'package:enet_app/core/theme/enet_theme.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/presentation/api_endpoint_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('API endpoint can be changed from the unauthenticated screen', (tester) async {
    final auth = AuthController(DemoAuthRepository());
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: Center(child: ApiEndpointPanel(auth: auth))),
    ));

    expect(find.text('http://127.0.0.1:8787'), findsOneWidget);
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'https://api.example.com');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(auth.apiBaseUrl, 'https://api.example.com');
    expect(find.text('https://api.example.com'), findsOneWidget);
  });

  testWidgets('API endpoint form refuses non-HTTPS remote servers', (tester) async {
    final auth = AuthController(DemoAuthRepository());
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: Center(child: ApiEndpointPanel(auth: auth))),
    ));

    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'http://api.example.com');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Для удалённого API требуется HTTPS'), findsOneWidget);
    expect(auth.apiBaseUrl, 'http://127.0.0.1:8787');
  });
}
