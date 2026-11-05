import 'package:enet_app/core/theme/enet_theme.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/domain/auth_repository.dart';
import 'package:enet_app/features/shell/presentation/dashboard_status.dart';
import 'package:enet_app/features/shell/presentation/service_catalog_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CatalogRepository extends DemoAuthRepository {
  @override
  Future<bool> checkServer() async => true;

  @override
  Future<List<EcosystemService>> listServices() async => const [
    EcosystemService(id: 'prodayzer', name: 'Продайзер',
      description: 'Генерация объявлений', url: 'https://prodayzer.ru'),
    EcosystemService(id: 'studio', name: 'eNet Studio',
      description: 'Инструменты разработки', url: 'https://enet-dev.ru'),
  ];
}

void main() {
  test('eNet 0.5 uses a dark emerald and mint theme', () {
    expect(ENetTheme.dark.brightness, Brightness.dark);
    expect(ENetTheme.dark.colorScheme.primary, ENetColors.cyan);
    expect(ENetColors.background.g, greaterThan(ENetColors.background.b));
  });

  testWidgets('The dashboard shows confirmed API status and quick actions', (tester) async {
    final auth = AuthController(_CatalogRepository());
    addTearDown(auth.dispose);
    var openedProfile = false;
    var openedSettings = false;
    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: DashboardStatus(
        auth: auth,
        openAccount: () => openedProfile = true,
        openSettings: () => openedSettings = true,
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Сервер отвечает'), findsOneWidget);
    await tester.tap(find.text('eNet ID'));
    expect(openedProfile, true);
    await tester.tap(find.text('Безопасность'));
    expect(openedSettings, true);
  });

  testWidgets('Favorites can be saved and filtered across service cards', (tester) async {
    final auth = AuthController(_CatalogRepository());
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: SingleChildScrollView(
        child: ServiceCatalogPanel(auth: auth))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-prodayzer')));
    await tester.pumpAndSettle();
    expect(find.text('Избранное (1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('favorites-only')));
    await tester.pumpAndSettle();
    expect(find.text('Продайзер'), findsOneWidget);
    expect(find.text('eNet Studio'), findsNothing);
  });

  testWidgets('Search filters services and clear restores the full catalog', (tester) async {
    final auth = AuthController(_CatalogRepository());
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: SingleChildScrollView(
        child: ServiceCatalogPanel(auth: auth))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Продайзер'), findsOneWidget);
    expect(find.text('eNet Studio'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.byIcon(Icons.code_rounded), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('service-search')), 'Студи');
    await tester.pumpAndSettle();
    expect(find.text('Продайзер'), findsNothing);
    expect(find.text('По запросу «Студи» сервисы не найдены.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('service-search')), 'studio');
    await tester.pumpAndSettle();
    expect(find.text('eNet Studio'), findsOneWidget);
    expect(find.text('Продайзер'), findsNothing);
    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pumpAndSettle();
    expect(find.text('Продайзер'), findsOneWidget);
    expect(find.text('eNet Studio'), findsOneWidget);
  });
}
