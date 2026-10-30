class AuthUser {
  const AuthUser({required this.email, required this.name});
  final String email;
  final String name;
}

/// Replace the demo implementation with a real backend before release.
abstract class AuthRepository {
  Future<AuthUser> signIn({required String email, required String password});
  Future<AuthUser> signUp({required String name, required String email, required String password});
  Future<void> requestPasswordReset(String email);
  Future<void> signOut();
}
