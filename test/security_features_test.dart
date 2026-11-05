import 'package:enet_app/core/theme/enet_theme.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/shell/presentation/account_security_panel.dart';
import 'package:enet_app/features/shell/presentation/service_catalog_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Settings show API status and password controls', (tester) async {
    final auth = AuthController(DemoAuthRepository());
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: AccountSecurityPanel(auth: auth))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Изменить пароль'), findsOneWidget);
    expect(find.text('Завершить сеансы на других устройствах'), findsOneWidget);
    expect(find.text('Нет подключения к eNet API'), findsOneWidget);
    await tester.tap(find.text('Изменить пароль'));
    await tester.pumpAndSettle();
    expect(find.text('Текущий пароль'), findsOneWidget);
    expect(find.text('Новый пароль'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
  });

  testWidgets('Service catalog gracefully handles an empty API response', (tester) async {
    final auth = AuthController(DemoAuthRepository());
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: ServiceCatalogPanel(auth: auth))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Сервисы пока не добавлены.'), findsOneWidget);
    expect(find.byTooltip('Обновить сервисы'), findsOneWidget);
  });
}
