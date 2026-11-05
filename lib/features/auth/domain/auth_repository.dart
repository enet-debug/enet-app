class AuthUser {
  const AuthUser({required this.email, required this.name});
  final String email;
  final String name;
}

class EcosystemService {
  const EcosystemService({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
  });

  final String id;
  final String name;
  final String description;
  final String url;
}

/// Abstract authentication and account services. Demo implementation is only for tests.
abstract class AuthRepository {
  Future<AuthUser> signIn({required String email, required String password});
  Future<AuthUser> signUp({required String name, required String email, required String password});
  Future<void> requestPasswordReset(String email);
  Future<void> signOut();
  Future<AuthUser?> restoreSession();
  Future<bool> checkServer();
  Future<List<EcosystemService>> listServices();
  Future<void> changePassword(String currentPassword, String nextPassword);
  Future<int> revokeOtherSessions();
}
