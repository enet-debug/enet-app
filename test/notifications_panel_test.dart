import 'package:enet_app/core/theme/enet_theme.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/domain/auth_repository.dart';
import 'package:enet_app/features/shell/presentation/notifications_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NotificationsRepository extends DemoAuthRepository {
  final Set<String> readIds = {};
  int readAllCalls = 0;

  List<AccountNotification> get entries => [
    AccountNotification(
      id: 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
      type: 'security',
      title: 'Новый вход в eNet ID',
      body: 'Выполнен вход с устройства: eNet APP Linux',
      createdAt: DateTime.utc(2026, 11, 5, 9, 0),
      readAt: readIds.contains('a') ? DateTime.utc(2026, 11, 5, 9, 1) : null,
    ),
    AccountNotification(
      id: 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb',
      type: 'welcome',
      title: 'Добро пожаловать в eNet',
      body: 'Аккаунт создан',
      createdAt: DateTime.utc(2026, 11, 4, 9, 0),
      readAt: readIds.contains('b') ? DateTime.utc(2026, 11, 4, 9, 1) : null,
    ),
  ];

  @override
  Future<NotificationFeed> listNotifications() async {
    final list = entries;
    return NotificationFeed(
      notifications: list,
      unreadCount: list.where((item) => item.unread).length,
    );
  }

  @override
  Future<void> readNotification(String id) async {
    if (id.startsWith('a')) readIds.add('a');
    if (id.startsWith('b')) readIds.add('b');
  }

  @override
  Future<int> readAllNotifications() async {
    readAllCalls++;
    final count = entries.where((item) => item.unread).length;
    readIds.addAll(['a', 'b']);
    return count;
  }
}

void main() {
  testWidgets('Notification center uses server feed and marks messages read', (tester) async {
    tester.view.physicalSize = const Size(1100, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _NotificationsRepository();
    final auth = AuthController(repo);
    addTearDown(auth.dispose);
    final unreadUpdates = <int>[];

    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: SingleChildScrollView(
        child: NotificationsPanel(
          auth: auth,
          onUnreadCountChanged: unreadUpdates.add,
        ),
      )),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(unreadUpdates.last, 2);
    expect(find.text('Непрочитанных: 2'), findsOneWidget);
    expect(find.text('Новый вход в eNet ID'), findsOneWidget);
    expect(find.text('Добро пожаловать в eNet'), findsOneWidget);
    await tester.tap(find.text('Отметить прочитанным').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.readIds.contains('a'), true);
    expect(unreadUpdates.last, 1);
    expect(find.text('Непрочитанных: 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Прочитать все уведомления'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.readAllCalls, 1);
    expect(unreadUpdates.last, 0);
    expect(find.text('Всё прочитано'), findsOneWidget);
  });
}
