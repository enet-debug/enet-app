import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enet_app/main.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';

void main() {
  testWidgets('Authentication screen is available', (tester) async {
    await tester.pumpWidget(ENetApp(authRepository: DemoAuthRepository()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('С возвращением!'), findsOneWidget);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
