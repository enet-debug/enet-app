import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_repository.dart';

/// Real eNet ID accounts backed by Supabase Auth.
/// The publishable key is a client identifier, never a service-role secret.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  AuthUser? _fromUser(User? user) {
    if (user == null) return null;
    final email = user.email ?? '';
    final metadata = user.userMetadata ?? <String, dynamic>{};
    final name = metadata['display_name'];
    return AuthUser(
      id: user.id,
      email: email,
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : email.split('@').first,
    );
  }

  @override
  AuthUser? get currentUser =>
      _client.auth.currentSession == null
          ? null
          : _fromUser(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get authChanges => _client.auth.onAuthStateChange
      .map((state) => _fromUser(state.session?.user));

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = _fromUser(response.user);
    if (response.session == null || user == null) {
      throw StateError('Не удалось создать сеанс. Попробуйте снова.');
    }
    return user;
  }

  @override
  Future<AuthUser?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
    );
    // Never enter the app when email confirmation is still pending.
    if (response.session == null) return null;
    return _fromUser(response.user);
  }

  @override
  Future<void> requestPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: const String.fromEnvironment('ENET_RESET_REDIRECT_URL')
                .isEmpty
            ? null
            : const String.fromEnvironment('ENET_RESET_REDIRECT_URL'),
      );

  @override
  Future<void> signOut() => _client.auth.signOut();
}
