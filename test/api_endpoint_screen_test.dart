import 'package:enet_app/core/theme/enet_theme.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/presentation/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _EndpointRepository extends DemoAuthRepository {
  String endpoint = 'http://127.0.0.1:8787';

  @override
  String get apiEndpoint => endpoint;

  @override
  Future<void> configureApiEndpoint(String value) async {
    endpoint = value;
  }
}

void main() {
  testWidgets('Sign-in screen allows a user to configure the API URL', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _EndpointRepository();
    final auth = AuthController(repository);
    addTearDown(auth.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: AuthScreen(auth: auth),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Настроить адрес API'), findsOneWidget);
    await tester.tap(find.text('Настроить адрес API'));
    await tester.pumpAndSettle();

    expect(find.text('Подключение к eNet API'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.last, 'https://api.example.org/');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(repository.endpoint, 'https://api.example.org');
    expect(find.text('Адрес API сохранён. Теперь можно войти в eNet ID.'), findsOneWidget);
  });
}
