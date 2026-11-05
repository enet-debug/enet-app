import 'dart:async';
import 'dart:convert';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/api_auth_repository.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/domain/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _sessionKey = 'enet_id_session';
const _oldToken = 'old-session-token-for-regression-testing';
const _newToken = 'new-session-token-for-regression-testing';
const _account = AuthUser(email: 'user@example.org', name: 'User');

String _accountResponse({String? token}) => jsonEncode({
  'user': {'id': 'account-id', 'email': _account.email, 'name': _account.name},
  if (token != null) 'token': token,
});

class _SessionRepository extends DemoAuthRepository {
  bool expired = false;
  bool offline = false;
  Completer<List<EcosystemService>>? pendingCatalog;
  Completer<AuthUser?>? pendingRestore;

  @override
  Future<AuthUser?> restoreSession() async {
    if (pendingRestore != null) return pendingRestore!.future;
    if (offline) throw Exception('Network unavailable');
    return _account;
  }

  @override
  Future<List<EcosystemService>> listServices() async {
    if (pendingCatalog != null) return pendingCatalog!.future;
    if (expired) throw const SessionExpiredException();
    if (offline) throw Exception('Network unavailable');
    return const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({_sessionKey: _oldToken});
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  test('a protected 401 clears only the rejected saved session', () async {
    final repository = ApiAuthRepository(client: MockClient((request) async {
      expect(request.url.path, '/v1/services');
      expect(request.headers['Authorization'], 'Bearer $_oldToken');
      // A proxy may return a non-JSON 401; session handling still applies.
      return http.Response('Unauthorized', 401);
    }));

    await expectLater(repository.listServices(), throwsA(isA<SessionExpiredException>()));
    expect(await const FlutterSecureStorage().read(key: _sessionKey), isNull);
    expect(await repository.restoreSession(), isNull);
  });

  test('incorrect login credentials do not expire an existing session', () async {
    final repository = ApiAuthRepository(client: MockClient((request) async =>
      http.Response('{"error":{"message":"Неверная почта или пароль."}}', 401),
    ));

    await expectLater(
      repository.signIn(email: _account.email, password: 'Incorrect-password'),
      throwsA(isNot(isA<SessionExpiredException>())),
    );
    expect(await const FlutterSecureStorage().read(key: _sessionKey), _oldToken);
  });

  test('offline restore preserves its token and succeeds when retried', () async {
    var offline = true;
    final repository = ApiAuthRepository(client: MockClient((request) async {
      if (offline) throw http.ClientException('offline');
      expect(request.headers['Authorization'], 'Bearer $_oldToken');
      return http.Response(_accountResponse(), 200);
    }));

    await expectLater(repository.restoreSession(), throwsException);
    expect(await const FlutterSecureStorage().read(key: _sessionKey), _oldToken);
    offline = false;
    expect((await repository.restoreSession())?.email, _account.email);
  });

  test('a late 401 cannot erase a token from a newer login', () async {
    final started = Completer<void>();
    final oldResponse = Completer<http.Response>();
    final repository = ApiAuthRepository(client: MockClient((request) async {
      if (request.url.path == '/v1/services') {
        started.complete();
        return oldResponse.future;
      }
      return http.Response(_accountResponse(token: _newToken), 200);
    }));

    final pending = repository.listServices();
    final rejected = expectLater(pending, throwsA(isA<SessionExpiredException>()));
    await started.future;
    await repository.signIn(email: _account.email, password: 'New-login-password');
    oldResponse.complete(http.Response('{}', 401));
    await rejected;
    expect(await const FlutterSecureStorage().read(key: _sessionKey), _newToken);
  });

  test('a revoked session signs out while a network error keeps the account', () async {
    final repository = _SessionRepository();
    final auth = AuthController(repository);
    addTearDown(auth.dispose);
    await auth.signIn(_account.email, 'Example-password');
    repository.offline = true;
    await expectLater(auth.listServices(), throwsException);
    expect(auth.user, isNotNull);

    repository.offline = false;
    repository.expired = true;
    await expectLater(auth.listServices(), throwsA(isA<SessionExpiredException>()));
    expect(auth.user, isNull);
    expect(auth.sessionMessage, SessionExpiredException.message);
    expect(auth.canRetrySession, isFalse);
  });

  test('an older account response cannot close a new controller session', () async {
    final repository = _SessionRepository();
    final auth = AuthController(repository);
    addTearDown(auth.dispose);
    await auth.signIn(_account.email, 'Example-password');
    repository.pendingCatalog = Completer<List<EcosystemService>>();
    final rejected = expectLater(
      auth.listServices(), throwsA(isA<SessionExpiredException>()),
    );
    await auth.signIn('another@example.org', 'Another-password');
    repository.pendingCatalog!.completeError(const SessionExpiredException());
    await rejected;
    expect(auth.user?.email, 'another@example.org');
    expect(auth.sessionMessage, isNull);
  });

  test('controller offers a retry after offline restore without exposing an account', () async {
    final repository = _SessionRepository()..offline = true;
    final auth = AuthController(repository);
    addTearDown(auth.dispose);
    await auth.restoreSession();
    expect(auth.user, isNull);
    expect(auth.initializing, isFalse);
    expect(auth.canRetrySession, isTrue);
    repository.offline = false;
    await auth.restoreSession();
    expect(auth.user?.email, _account.email);
    expect(auth.sessionMessage, isNull);
    expect(auth.canRetrySession, isFalse);
  });

  test('a restore completing after disposal does not notify a dead controller', () async {
    final repository = _SessionRepository()..pendingRestore = Completer<AuthUser?>();
    final auth = AuthController(repository);
    final restore = auth.restoreSession();
    auth.dispose();
    repository.pendingRestore!.complete(_account);
    await expectLater(restore, completes);
    expect(auth.user, isNull);
  });
}
