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

class AccountSession {
  const AccountSession({
    required this.id,
    required this.device,
    required this.createdAt,
    required this.lastSeenAt,
    required this.expiresAt,
    required this.current,
  });

  final String id;
  final String device;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final DateTime expiresAt;
  final bool current;
}

/// Abstract authentication and account services. Demo implementation is only for tests.
abstract class AuthRepository {
  String get apiEndpoint;
  Future<void> configureApiEndpoint(String endpoint);
  Future<AuthUser> signIn({required String email, required String password});
  Future<AuthUser> signUp({required String name, required String email, required String password});
  Future<void> requestPasswordReset(String email);
  Future<void> signOut();
  Future<AuthUser?> restoreSession();
  Future<bool> checkServer();
  Future<List<EcosystemService>> listServices();
  Future<void> changePassword(String currentPassword, String nextPassword);
  Future<int> revokeOtherSessions();
  Future<AuthUser> updateName(String name);
  Future<List<AccountSession>> listSessions();
  Future<void> revokeSession(String sessionId);
}
