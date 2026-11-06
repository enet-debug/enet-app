import 'package:enet_app/core/widgets/brand_logo.dart';
import 'package:enet_app/features/shell/presentation/workspace_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Reference mobile welcome and ID geometry stay consistent', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            MobileWelcomeScene(name: 'Виталий', onOpenProfile: () {}),
            V07HeroIdCard(compact: true, onTap: () {}),
          ]),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(MobileWelcomeScene)).height, 285);
    expect(tester.getSize(find.byKey(const ValueKey('workspace-hero'))).height, 116);
    expect(find.text('Единый аккаунт\\neNet'), findsOneWidget);
    // The supplied scenery already includes the logo. A second vector mark
    // would create a doubled symbol, which was caught in a previous capture.
    expect(find.byType(BrandLogo), findsNothing);
  });

  testWidgets('Reference desktop ID card retains its prominent 3D mark', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 810,
            child: V07HeroIdCard(onTap: _noop),
          ),
        ),
      ),
    ));

    expect(tester.getSize(find.byKey(const ValueKey('workspace-hero'))).height, 166);
    expect(find.byKey(const ValueKey('desktop-enet-id-plate')), findsOneWidget);
    expect(find.text('eNet ID'), findsOneWidget);
  });
}

void _noop() {}
