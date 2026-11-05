import 'package:enet_app/core/theme/enet_theme.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/domain/auth_repository.dart';
import 'package:enet_app/features/shell/presentation/enet_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InboxRepository extends DemoAuthRepository {
  @override
  Future<bool> checkServer() async => true;

  @override
  Future<NotificationFeed> listNotifications() async {
    return NotificationFeed(notifications: [
      AccountNotification(
        id: 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
        type: 'security',
        title: 'Новый вход в eNet ID',
        body: 'Проверка приложения',
        createdAt: DateTime.utc(2026, 11, 5),
        readAt: null,
      ),
    ], unreadCount: 1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    testWidgets('Unread badge and navigation work at $size', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthController(_InboxRepository());
      addTearDown(auth.dispose);
      await auth.signIn('test@example.org', 'Example-Password-123');

      await tester.pumpWidget(MaterialApp(
        theme: ENetTheme.dark,
        home: ENetShell(auth: auth),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byTooltip('Уведомления: 1 непрочитанных'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Уведомления: 1 непрочитанных'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Новый вход в eNet ID'), findsOneWidget);
      expect(find.text('Непрочитанных: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
