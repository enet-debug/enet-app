import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/domain/auth_repository.dart';
import 'package:enet_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _RecoveryRepository extends DemoAuthRepository {
  bool offline = false;
  bool expired = false;

  @override
  Future<AuthUser?> restoreSession() async {
    if (offline) throw Exception('offline');
    return const AuthUser(id: 'saved-account-id', email: 'saved@example.org', name: 'Saved User');
  }

  @override
  Future<NotificationFeed> listNotifications() async {
    if (expired) throw const SessionExpiredException();
    return const NotificationFeed(notifications: [], unreadCount: 0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    testWidgets('saved session recovery works without re-entering credentials at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _RecoveryRepository()..offline = true;
      await tester.pumpWidget(ENetApp(authRepository: repository));
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 650));
      final retry = find.text('Повторить проверку сеанса');
      expect(retry, findsOneWidget);
      expect(find.textContaining('Не удалось проверить сохранённый сеанс.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      repository.offline = false;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(retry, findsNothing);
      expect(find.byTooltip('Открыть уведомления'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final profileTab = find.byKey(ValueKey(
        size.width < 600 ? 'mobile-nav-3' : 'desktop-nav-3',
      ));
      await tester.ensureVisible(profileTab);
      await tester.tap(profileTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('saved-account-id'), findsOneWidget);
      repository.expired = true;
      await tester.tap(find.byTooltip('Открыть уведомления'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text(SessionExpiredException.message), findsOneWidget);
      expect(find.text('С возвращением!'), findsOneWidget);
      expect(find.byTooltip('Открыть уведомления'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
