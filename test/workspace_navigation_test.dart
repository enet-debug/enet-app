import 'package:enet_app/core/theme/enet_theme.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/shell/presentation/enet_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    testWidgets('Workspace navigation opens real feature pages at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthController(DemoAuthRepository());
      addTearDown(auth.dispose);
      await auth.signIn('workspace@example.org', 'Local-Test-Password-123');

      await tester.pumpWidget(MaterialApp(
        theme: ENetTheme.dark,
        home: ENetShell(auth: auth),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Один аккаунт.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (size.width < 600) {
        await tester.tap(find.byKey(const ValueKey('mobile-nav-1')));
      } else {
        await tester.tap(find.byKey(const ValueKey('desktop-nav-1')));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Сервисы'), findsOneWidget);
      expect(find.text('Сервисы пока не добавлены.'), findsOneWidget);

      if (size.width < 600) {
        await tester.tap(find.byKey(const ValueKey('mobile-nav-more')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.byKey(const ValueKey('more-nav-4')));
      } else {
        await tester.tap(find.byKey(const ValueKey('desktop-nav-4')));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Защита аккаунта и управление доступом.'), findsOneWidget);
      expect(find.text('Изменить пароль'), findsOneWidget);

      if (size.width < 600) {
        await tester.tap(find.byKey(const ValueKey('mobile-nav-more')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.byKey(const ValueKey('more-nav-5')));
      } else {
        await tester.tap(find.byKey(const ValueKey('desktop-nav-5')));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Активные сеансы твоего eNet ID.'), findsOneWidget);
      expect(find.text('Активных сеансов не найдено.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
