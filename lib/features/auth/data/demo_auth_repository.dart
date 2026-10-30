import '../domain/auth_repository.dart';

/// UI-only: accepts validated credentials. No account is created,
/// no password is stored, and no email is sent.
class DemoAuthRepository implements AuthRepository {
  @override
  Future<AuthUser> signIn({required String email, required String password}) async =>
      AuthUser(email: email.trim(), name: email.trim().split('@').first);
  @override
  Future<AuthUser> signUp({required String name, required String email, required String password}) async =>
      AuthUser(email: email.trim(), name: name.trim());
  @override
  Future<void> requestPasswordReset(String email) async {}
  @override
  Future<void> signOut() async {}
}
