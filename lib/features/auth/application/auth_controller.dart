import 'package:flutter/foundation.dart';
import '../domain/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);
  final AuthRepository _repository;
  AuthUser? user;
  bool busy = false;
  bool initializing = true;

  Future<void> initialize() async {
    try { await _repository.initialize(); } catch (_) {}
    await restoreSession();
  }

  String get apiBaseUrl => _repository.apiBaseUrl;

  Future<void> updateApiBaseUrl(String value) async {
    final normalized = normalizeApiBaseUrl(value);
    if (normalized == apiBaseUrl) return;
    await _execute(() async {
      await _repository.updateApiBaseUrl(normalized);
      user = null;
    });
  }

  Future<void> restoreSession() async {
    try {
      user = await _repository.restoreSession();
    } catch (_) {
      user = null;
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> _execute(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try { await action(); } finally { busy = false; notifyListeners(); }
  }

  Future<void> signIn(String email, String password) => _execute(() async {
    user = await _repository.signIn(email: email, password: password);
  });

  Future<void> signUp(String name, String email, String password) => _execute(() async {
    user = await _repository.signUp(name: name, email: email, password: password);
  });

  Future<void> signOut() => _execute(() async {
    await _repository.signOut();
    user = null;
  });

  Future<void> updateName(String name) => _execute(() async {
    user = await _repository.updateName(name);
  });

  Future<List<AccountSession>> listSessions() => _repository.listSessions();

  Future<void> revokeSession(String sessionId) =>
      _execute(() => _repository.revokeSession(sessionId));

  Future<bool> checkServer() => _repository.checkServer();
  Future<List<EcosystemService>> listServices() => _repository.listServices();
  Future<void> changePassword(String currentPassword, String nextPassword) =>
      _execute(() => _repository.changePassword(currentPassword, nextPassword));

  Future<int> revokeOtherSessions() async {
    if (busy) throw StateError('Дождитесь завершения предыдущей операции.');
    busy = true;
    notifyListeners();
    try {
      return await _repository.revokeOtherSessions();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> requestPasswordReset(String email) => _execute(() => _repository.requestPasswordReset(email));
}
