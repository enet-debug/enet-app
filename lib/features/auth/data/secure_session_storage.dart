import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists Supabase sessions in Keychain / Windows protected storage.
/// Supabase's default SharedPreferences storage is deliberately not used.
class SecureSessionStorage extends LocalStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() =>
      _storage.read(key: supabasePersistSessionKey);

  @override
  Future<bool> hasAccessToken() =>
      _storage.containsKey(key: supabasePersistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(
        key: supabasePersistSessionKey,
        value: persistSessionString,
      );

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: supabasePersistSessionKey);
}
