import 'package:enet_app/core/theme/enet_theme.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/domain/auth_repository.dart';
import 'package:enet_app/features/shell/presentation/service_catalog_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FavoriteRepository extends DemoAuthRepository {
  final Map<String, bool> favorites = {};

  @override
  Future<List<EcosystemService>> listServices() async => [
    EcosystemService(id: 'prodayzer', name: 'Продайзер',
      description: 'Карточки объявлений', url: 'https://prodayzer.ru',
      favorite: favorites['prodayzer'] ?? false),
    EcosystemService(id: 'docs', name: 'eNet Docs',
      description: 'Документация', url: 'https://enet-dev.ru',
      favorite: favorites['docs'] ?? false),
  ];

  @override
  Future<void> setServiceFavorite(String serviceId, bool favorite) async {
    favorites[serviceId] = favorite;
  }
}

void main() {
  testWidgets('Favorite and filter controls keep the catalog in sync', (tester) async {
    final repository = _FavoriteRepository();
    final auth = AuthController(repository);
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(body: SingleChildScrollView(
        child: ServiceCatalogPanel(auth: auth))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Продайзер'), findsOneWidget);
    expect(find.text('eNet Docs'), findsOneWidget);

    await tester.tap(find.byTooltip('Добавить Продайзер в избранное'));
    await tester.pumpAndSettle();
    expect(repository.favorites['prodayzer'], true);
    expect(find.byTooltip('Убрать Продайзер из избранного'), findsOneWidget);

    await tester.tap(find.text('Избранное'));
    await tester.pumpAndSettle();
    expect(find.text('Продайзер'), findsOneWidget);
    expect(find.text('eNet Docs'), findsNothing);

    await tester.tap(find.byTooltip('Убрать Продайзер из избранного'));
    await tester.pumpAndSettle();
    expect(repository.favorites['prodayzer'], false);
    expect(find.text('Пока нет избранных сервисов.'), findsOneWidget);
  });
}
