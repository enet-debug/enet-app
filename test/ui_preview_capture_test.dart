import 'dart:io';
import 'dart:ui' as ui;

import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/domain/auth_repository.dart';
import 'package:enet_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
        email: 'user@enet-dev.ru',
        name: 'Виталий',
      );

  @override
  Future<bool> checkServer() async => true;

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

  @override
  Future<List<AccountSession>> listSessions() async => [
        AccountSession(
          id: 'preview-session',
          device: 'Linux (текущее)',
          createdAt: DateTime.utc(2026, 11, 5, 8),
          lastSeenAt: DateTime.utc(2026, 11, 5, 12, 30),
          expiresAt: DateTime.utc(2026, 11, 6, 8),
          current: true,
        ),
      ];
}

const _captureKey = ValueKey<String>('real-app-capture-root');

Future<void> _loadReadableFont() async {
  // The flutter_test engine normally substitutes the Ahem font, which paints
  // text as blocks. Load a local system font into the app's Roboto family so
  // real UI screenshots include readable Russian text.
  final source = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
  if (!source.existsSync()) {
    throw StateError('Readable screenshot font was not installed');
  }
  final bytes = await source.readAsBytes();
  final boldSource = File('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf');
  if (!boldSource.existsSync()) {
    throw StateError('Bold Cyrillic screenshot font was not installed');
  }
  final boldBytes = await boldSource.readAsBytes();
  final loader = FontLoader('Roboto');
  loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  loader.addFont(Future<ByteData>.value(ByteData.sublistView(boldBytes)));
  await loader.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    throw StateError('Flutter root is required for real icon previews');
  }
  final iconFile = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!iconFile.existsSync()) {
    throw StateError('Material Icons font was not found in the Flutter SDK');
  }
  final iconBytes = await iconFile.readAsBytes();
  final icons = FontLoader('MaterialIcons');
  icons.addFont(Future<ByteData>.value(ByteData.sublistView(iconBytes)));
  await icons.load();

  // The profile intentionally uses a monospaced face for the account UUID.
  final monoSource = File('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf');
  if (!monoSource.existsSync()) {
    throw StateError('Monospaced screenshot font was not installed');
  }
  final monoBytes = await monoSource.readAsBytes();
  final mono = FontLoader('monospace');
  mono.addFont(Future<ByteData>.value(ByteData.sublistView(monoBytes)));
  await mono.load();
}

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

  setUpAll(() async {
    if (Platform.environment['ENET_CAPTURE_UI'] == '1') {
      await _loadReadableFont();
    }
  });

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

      // Raster decorations are bundled offline and remain separate from
      // interactive Flutter widgets. Ensure both screenshot viewports render
      // loaded assets rather than a transient image-decoding frame.
      final artwork = size.width < 600
          ? const AssetImage('assets/brand/approved_mobile_mountains.jpg')
          : const AssetImage('assets/brand/approved_hero_graphic.jpg');
      final loaded = await tester.runAsync(() async {
        await precacheImage(
          artwork,
          tester.element(find.byKey(const ValueKey('workspace-hero'))),
        );
        return true;
      });
      expect(loaded, isTrue);
      await tester.pump(const Duration(milliseconds: 150));

      if (size.width < 600) {
        expect(find.text('Быстрый доступ'), findsOneWidget);
        expect(find.text('Мои сервисы'), findsNothing);
      } else {
        expect(find.text('Мои сервисы'), findsOneWidget);
      }
      expect(find.text('Продайзер'), findsWidgets);
      final heroSize = tester.getSize(find.byKey(const ValueKey('workspace-hero')));
      if (size.width > 600) {
        expect(heroSize.width, greaterThan(680));
      } else {
        expect(heroSize.width, greaterThan(300));
      }
      final device = size.width < 600 ? 'mobile' : 'desktop';
      await _saveCapture(tester, 'enet-home-$device');

      // On phones the first 'Профиль' is an off-screen quick-action card.
      // The last one is the visible bottom-navigation destination.
      await tester.tap(
        size.width < 600
            ? find.byKey(const ValueKey('mobile-nav-3'))
            : find.byKey(const ValueKey('desktop-nav-3')),
      );
      // Reveal widgets are staggered. Drive multiple frames so both the page
      // transition and delayed cards reach their final visible state.
      await tester.pump();
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('00000000-0000-4000-8000-000000000001'),
          findsOneWidget);
      await _saveCapture(tester, 'enet-profile-$device');

      // Capture the actual API-backed feature pages, not invented mock screens.
      if (size.width < 600) {
        // The phone dock now opens the real 0.7 command palette.
        await tester.tap(find.byKey(const ValueKey('mobile-nav-1')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.enterText(
          find.byKey(const ValueKey('enet-search-input')), 'Сервисы');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(find.text('Сервисы').last);
      } else {
        await tester.tap(find.byKey(const ValueKey('desktop-nav-1')));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Сервисы'), findsWidgets);
      await _saveCapture(tester, 'enet-services-$device');

      if (size.width < 600) {
        await tester.tap(find.byKey(const ValueKey('mobile-nav-more')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.byKey(const ValueKey('more-nav-7')));
      } else {
        await tester.tap(find.byKey(const ValueKey('desktop-nav-more')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.byKey(const ValueKey('more-nav-7')));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Список пока пуст'), findsOneWidget);
      await _saveCapture(tester, 'enet-tasks-$device');

      if (size.width < 600) {
        await tester.tap(find.byKey(const ValueKey('mobile-nav-more')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.byKey(const ValueKey('more-nav-4')));
      } else {
        await tester.tap(find.byKey(const ValueKey('desktop-nav-4')));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Защита аккаунта и управление доступом.'), findsOneWidget);
      await _saveCapture(tester, 'enet-security-$device');

      if (size.width < 600) {
        await tester.tap(find.byKey(const ValueKey('mobile-nav-more')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.byKey(const ValueKey('more-nav-5')));
      } else {
        await tester.tap(find.byKey(const ValueKey('desktop-nav-0')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        await tester.tap(find.text('Управление сеансами'));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Активные сеансы твоего eNet ID.'), findsOneWidget);
      await _saveCapture(tester, 'enet-devices-$device');
    });
  }
}
