import 'package:enet_app/core/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reference e brand mark renders without a bitmap asset', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: BrandLogo(size: 96))),
    ));

    expect(find.byType(ENetMark), findsOneWidget);
    expect(find.text('eNet'), findsOneWidget);
    expect(find.descendant(
      of: find.byType(ENetMark),
      matching: find.byType(CustomPaint),
    ), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon-only brand mark fits small and large placements', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Row(children: [
          BrandLogo(size: 22, showName: false),
          BrandLogo(size: 58, showName: false),
          BrandLogo(size: 112, showName: false),
        ]),
      ),
    ));

    expect(find.byType(ENetMark), findsNWidgets(3));
    expect(find.text('eNet'), findsNothing);
    expect(tester.getSize(find.byType(ENetMark).first), const Size(22, 22));
    expect(tester.getSize(find.byType(ENetMark).last), const Size(112, 112));
    expect(tester.takeException(), isNull);
  });
}
