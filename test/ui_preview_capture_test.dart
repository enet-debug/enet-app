import 'dart:io';
import 'dart:ui' as ui;

import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/domain/auth_repository.dart';
import 'package:enet_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// This is the real Flutter application rendered by the test engine, not a
/// fabricated design image. Only the account/API responses are local fixtures.
/// Captures run only when ENET_CAPTURE_UI=1 is set by the screenshot workflow.
class _PreviewRepository extends DemoAuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(
        id: '00000000-0000-4000-8000-000000000001',
        email: 'preview@example.org',
        name: 'Preview',
      );

  @override
  Future<List<EcosystemService>> listServices() async => const [
        EcosystemService(
          id: 'prodayzer',
          name: 'Продайзер',
          description:
              'Создание и улучшение объявлений. Единый вход пока не подключён.',
          url: 'https://prodayzer.ru',
        ),
      ];
}

const _captureKey = ValueKey<String>('real-app-capture-root');

Future<void> _saveCapture(WidgetTester tester, String filename) async {
  await tester.pump();
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
  // Image encoding and filesystem writes need a real async zone in widget tests.
  final saved = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Flutter renderer did not return screenshot bytes');
      }
      Directory('ui_previews').createSync(recursive: true);
      File('ui_previews/$filename.png')
          .writeAsBytesSync(data.buffer.asUint8List());
      return true;
    } finally {
      image.dispose();
    }
  });
  if (saved != true) {
    throw StateError('Flutter screenshot capture did not complete');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Capture actual desktop login screen', (tester) async {
    if (Platform.environment['ENET_CAPTURE_UI'] != '1') return;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(RepaintBoundary(
      key: _captureKey,
      child: ENetApp(authRepository: DemoAuthRepository()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('С возвращением!'), findsOneWidget);
    await _saveCapture(tester, 'enet-login-desktop');
  });

  for (final size in [const Size(1440, 900), const Size(390, 844)]) {
    testWidgets('Capture actual workspace and profile at $size',
        (tester) async {
      if (Platform.environment['ENET_CAPTURE_UI'] != '1') return;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(RepaintBoundary(
        key: _captureKey,
        child: ENetApp(authRepository: _PreviewRepository()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Приложения eNet'), findsOneWidget);
      final device = size.width < 600 ? 'mobile' : 'desktop';
      await _saveCapture(tester, 'enet-home-$device');

      // On phones the first 'Профиль' is an off-screen quick-action card.
      // The last one is the visible bottom-navigation destination.
      await tester.tap(
        size.width < 600
            ? find.text('Профиль').last
            : find.text('Профиль').first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('00000000-0000-4000-8000-000000000001'),
          findsOneWidget);
      await _saveCapture(tester, 'enet-profile-$device');
    });
  }
}
