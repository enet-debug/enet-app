import 'package:flutter/foundation.dart';
import '../domain/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);
  final AuthRepository _repository;
  AuthUser? user;
  bool busy = false;
  bool initializing = true;
  String? sessionMessage;
  bool canRetrySession = false;
  int _sessionEpoch = 0;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _signedIn(AuthUser account) {
    _sessionEpoch++;
    user = account;
    initializing = false;
    sessionMessage = null;
    canRetrySession = false;
  }

  Future<void> restoreSession() async {
    if (busy || _disposed) return;
    final epoch = ++_sessionEpoch;
    initializing = true;
    sessionMessage = null;
    canRetrySession = false;
    _notify();
    try {
      final account = await _repository.restoreSession();
      if (!_disposed && epoch == _sessionEpoch) user = account;
    } on SessionExpiredException {
      if (!_disposed && epoch == _sessionEpoch) {
        user = null;
        sessionMessage = SessionExpiredException.message;
      }
    } catch (_) {
      if (!_disposed && epoch == _sessionEpoch) {
        user = null;
        canRetrySession = true;
        sessionMessage = 'Не удалось проверить сохранённый сеанс. '
            'Проверьте соединение и повторите попытку.';
      }
    } finally {
      if (!_disposed && epoch == _sessionEpoch) {
        initializing = false;
        _notify();
      }
    }
  }

  Future<T> _accountRequest<T>(Future<T> Function() action) async {
    final epoch = _sessionEpoch;
    try {
      return await action();
    } on SessionExpiredException {
      // A response from an older account must not close a newer sign-in.
      if (!_disposed && epoch == _sessionEpoch) {
        _sessionEpoch++;
        user = null;
        sessionMessage = SessionExpiredException.message;
        canRetrySession = false;
        _notify();
      }
      rethrow;
    }
  }

  Future<void> _execute(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    _notify();
    try {
      await action();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> signIn(String email, String password) => _execute(() async {
    _signedIn(await _repository.signIn(email: email, password: password));
  });

  Future<void> signUp(String name, String email, String password) =>
      _execute(() async {
        _signedIn(await _repository.signUp(
          name: name, email: email, password: password,
        ));
      });

  Future<void> signOut() => _execute(() async {
    await _repository.signOut();
    _sessionEpoch++;
    user = null;
    sessionMessage = null;
    canRetrySession = false;
  });

  Future<void> updateName(String name) => _execute(() async {
    final account = await _accountRequest(() => _repository.updateName(name));
    if (!_disposed) user = account;
  });

  Future<List<AccountSession>> listSessions() =>
      _accountRequest(_repository.listSessions);

  Future<void> revokeSession(String sessionId) =>
      _execute(() => _accountRequest(() => _repository.revokeSession(sessionId)));

  Future<String> getApiEndpoint() => _repository.getApiEndpoint();

  Future<void> setApiEndpoint(String value) => _execute(() async {
    final previous = await _repository.getApiEndpoint();
    await _repository.setApiEndpoint(value);
    final current = await _repository.getApiEndpoint();
    if (previous != current) {
      _sessionEpoch++;
      user = null;
      sessionMessage = null;
      canRetrySession = false;
    }
  });

  Future<List<String>> favoriteServices() =>
      _accountRequest(_repository.favoriteServices);

  Future<List<String>> saveFavoriteServices(List<String> serviceIds) =>
      _accountRequest(() => _repository.saveFavoriteServices(serviceIds));

  Future<bool> checkServer() => _repository.checkServer();

  Future<List<EcosystemService>> listServices() =>
      _accountRequest(_repository.listServices);

  Future<void> changePassword(String currentPassword, String nextPassword) =>
      _execute(() => _accountRequest(
        () => _repository.changePassword(currentPassword, nextPassword),
      ));

  Future<int> revokeOtherSessions() => _executeWithResult(
    () => _accountRequest(_repository.revokeOtherSessions),
  );

  Future<T> _executeWithResult<T>(Future<T> Function() action) async {
    if (busy || _disposed) {
      throw StateError('Дождитесь завершения предыдущей операции.');
    }
    busy = true;
    _notify();
    try {
      return await action();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<NotificationFeed> listNotifications() =>
      _accountRequest(_repository.listNotifications);
  Future<void> readNotification(String id) =>
      _accountRequest(() => _repository.readNotification(id));
  Future<int> readAllNotifications() =>
      _accountRequest(_repository.readAllNotifications);

  Future<void> requestPasswordReset(String email) =>
      _execute(() => _repository.requestPasswordReset(email));

  @override
  void dispose() {
    _disposed = true;
    _sessionEpoch++;
    super.dispose();
  }
}
