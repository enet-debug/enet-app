import '../domain/auth_repository.dart';

/// UI-only: accepts any validated email/password. No account is created,
/// no password is stored, and no email is sent.
class DemoAuthRepository implements AuthRepository {
  @override
  Future<AuthUser> signIn({required String email, required String password}) async {
    return AuthUser(email: email.trim(), name: email.trim().split('@').first);
  }

  @override
  Future<AuthUser> signUp({required String name, required String email, required String password}) async {
    return AuthUser(email: email.trim(), name: name.trim());
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<bool> checkServer() async => false;

  @override
  Future<List<EcosystemService>> listServices() async => const [];

  @override
  Future<void> changePassword(String currentPassword, String nextPassword) async {
    throw UnsupportedError('Демо-аккаунт');
  }

  @override
  Future<int> revokeOtherSessions() async => 0;

  @override
  Future<AuthUser> updateName(String name) async =>
      AuthUser(email: 'demo@example.org', name: name);

  @override
  Future<List<AccountSession>> listSessions() async => const [];

  @override
  Future<void> revokeSession(String sessionId) async {}

  @override
  Future<void> signOut() async {}
}
