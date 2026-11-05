import 'package:enet_app/core/theme/enet_theme.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/shell/presentation/tasks_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tasks can be created, completed, edited and deleted', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthController(DemoAuthRepository());
    addTearDown(auth.dispose);
    await auth.signIn('tasks@example.org', 'Test-Password-12345');

    await tester.pumpWidget(MaterialApp(
      theme: ENetTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: TasksPanel(auth: auth),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Список пока пуст'), findsOneWidget);

    await tester.tap(find.text('Новая задача'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Подготовить релиз');
    await tester.enterText(find.byType(TextFormField).last, 'Проверить Windows и iOS');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Подготовить релиз'), findsOneWidget);
    expect(find.text('В работе'), findsWidgets);

    final checkbox = find.byType(Checkbox).first;
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    expect(find.text('Выполнено'), findsWidgets);

    await tester.tap(find.text('Подготовить релиз'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Релиз eNet 0.9');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Релиз eNet 0.9'), findsOneWidget);

    await tester.tap(find.byTooltip('Действия с задачей'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();
    expect(find.text('Релиз eNet 0.9'), findsNothing);
    expect(find.text('Список пока пуст'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
