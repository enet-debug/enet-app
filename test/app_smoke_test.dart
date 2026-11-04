import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enet_app/main.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/domain/auth_repository.dart';

class _FakeRepository implements AuthRepository {
  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get authChanges => const Stream<AuthUser?>.empty();

  @override
  Future<AuthUser> signIn({required String email, required String password}) async =>
      const AuthUser(id: 'server-issued-123', email: 'test@example.com', name: 'Tester');

  @override
  Future<AuthUser?> signUp({
    required String name,
    required String email,
    required String password,
  }) async => null; // Confirmation required: no session.

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('Authentication screen is available', (tester) async {
    await tester.pumpWidget(ENetApp(repository: _FakeRepository()));
    expect(find.text('С возвращением!'), findsOneWidget);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  test('Unconfirmed registration does not authenticate user', () async {
    final auth = AuthController(_FakeRepository());
    final active = await auth.signUp('Tester', 'test@example.com', 'password123');
    expect(active, isFalse);
    expect(auth.user, isNull);
    auth.dispose();
  });

  test('Login retains the server-issued user ID', () async {
    final auth = AuthController(_FakeRepository());
    await auth.signIn('test@example.com', 'password123');
    expect(auth.user?.id, 'server-issued-123');
    auth.dispose();
  });
}
