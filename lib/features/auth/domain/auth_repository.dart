class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
  });

  /// Stable, server-generated identity shared across eNet products.
  final String id;
  final String email;
  final String name;
}

/// Implementations must never allow a UI-only fake login in release builds.
abstract class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authChanges;

  Future<AuthUser> signIn({required String email, required String password});
  /// Returns null when a verification email was sent and no session exists.
  Future<AuthUser?> signUp({
    required String name,
    required String email,
    required String password,
  });
  Future<void> requestPasswordReset(String email);
  Future<void> signOut();
}
