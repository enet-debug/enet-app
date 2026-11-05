import 'package:enet_app/core/theme/enet_theme.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/shell/presentation/device_sessions_panel.dart';
import 'package:enet_app/features/shell/presentation/profile_edit_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Devices panel shows empty session state and refresh', (tester) async {
    final auth = AuthController(DemoAuthRepository());
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: DeviceSessionsPanel(auth: auth)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Активных сеансов не найдено.'), findsOneWidget);
    expect(find.byTooltip('Обновить список устройств'), findsOneWidget);
  });

  testWidgets('Profile name can be changed and is stored by controller', (tester) async {
    final auth = AuthController(DemoAuthRepository());
    addTearDown(auth.dispose);
    await auth.signIn('test@example.org', 'TestOnlyPassword123');
    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: ProfileEditButton(auth: auth)),
    ));
    await tester.tap(find.text('Изменить имя'));
    await tester.pumpAndSettle();
    expect(find.text('Изменить имя профиля'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Новое имя');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(auth.user?.name, 'Новое имя');
  });
}
