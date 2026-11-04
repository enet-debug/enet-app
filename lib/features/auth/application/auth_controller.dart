import 'dart:async';
import 'package:flutter/foundation.dart';

import '../domain/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository) {
    user = _repository.currentUser;
    _subscription = _repository.authChanges.listen(
      (next) {
        user = next;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        // Token refresh/network errors must not become uncaught stream errors.
        lastSessionError = error.toString();
        notifyListeners();
      },
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthUser?> _subscription;

  AuthUser? user;
  String? lastSessionError;
  bool busy = false;

  Future<T> _execute<T>(Future<T> Function() action) async {
    if (busy) throw StateError('Дождитесь завершения предыдущего запроса.');
    busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) => _execute(() async {
    user = await _repository.signIn(email: email, password: password);
    notifyListeners();
  });

  /// Returns false when the user must verify their email first.
  Future<bool> signUp(String name, String email, String password) =>
      _execute(() async {
        user = await _repository.signUp(
          name: name, email: email, password: password,
        );
        notifyListeners();
        return user != null;
      });

  Future<void> signOut() => _execute(() async {
    await _repository.signOut();
    user = null;
    notifyListeners();
  });

  Future<void> requestPasswordReset(String email) =>
      _execute(() => _repository.requestPasswordReset(email));

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
