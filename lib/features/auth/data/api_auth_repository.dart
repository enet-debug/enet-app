import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:http/http.dart' as http;
import '../domain/auth_repository.dart';
import 'api_endpoint_policy.dart';

/// Real eNet ID backend. Use HTTPS when the API is outside localhost.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({http.Client? client}) : _client = client ?? http.Client();

  static const apiUrl = String.fromEnvironment(
    'ENET_API_URL', defaultValue: 'http://127.0.0.1:8787',
  );
  static const _sessionKey = 'enet_id_session';
  static const _endpointKey = 'enet.api.endpoint';
  final http.Client _client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  Future<void> _sessionQueue = Future<void>.value();

  // Serialize token writes, endpoint changes and rejection cleanup. A late 401
  // must never delete the token belonging to a more recent sign-in.
  Future<T> _withSessionStorage<T>(Future<T> Function() action) {
    final operation = _sessionQueue.then((_) => action());
    _sessionQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  @override
  Future<String> getApiEndpoint() async {
    final stored = await _prefs.getString(_endpointKey);
    return stored ?? ApiEndpointPolicy.normalize(apiUrl);
  }

  @override
  Future<void> setApiEndpoint(String value) async {
    final normalized = ApiEndpointPolicy.normalize(value);
    await _withSessionStorage(() async {
      final current = await getApiEndpoint();
      if (current == normalized) return;
      await _storage.delete(key: _sessionKey);
      await _prefs.setString(_endpointKey, normalized);
    });
  }

  Future<Uri> _requestUri(String path, String? token) =>
      _withSessionStorage(() async {
        // Capture the destination together with its current token. If the
        // endpoint changed after a caller read the token, send nothing.
        final endpoint = await getApiEndpoint();
        if (token != null && await _storage.read(key: _sessionKey) != token) {
          throw const SessionExpiredException();
        }
        return Uri.parse('$endpoint$path');
      });

  Future<Map<String, dynamic>> _request(
    String method, String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-eNet-Client': 'eNet APP / ${defaultTargetPlatform.name}',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = await _requestUri(path, token);
    final http.Response response;
    try {
      response = await (method == 'GET'
        ? _client.get(uri, headers: headers)
        : _client.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw Exception('Сервер eNet не ответил. Проверьте, запущен ли API.');
    } on http.ClientException {
      throw Exception('Нет соединения с eNet API. Проверьте адрес сервера.');
    }
    if (response.statusCode == 401 && token != null) {
      await _withSessionStorage(() async {
        if (await _storage.read(key: _sessionKey) == token) {
          await _storage.delete(key: _sessionKey);
        }
      });
      throw const SessionExpiredException();
    }
    Map<String, dynamic> result;
    try {
      result = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw Exception('Сервер вернул некорректный ответ.');
    }
    if (response.statusCode >= 400) {
      final error = result['error'];
      final message = error is Map ? error['message'] : null;
      final description = message is String
          ? message : 'Ошибка API: ${response.statusCode}';
      if (response.statusCode == 429) {
        final seconds = int.tryParse(response.headers['retry-after'] ?? '');
        if (seconds != null && seconds > 0 && seconds <= 86400) {
          throw Exception('$description Повторите через $seconds сек.');
        }
      }
      throw Exception(description);
    }
    return result;
  }

  AuthUser _user(Map<String, dynamic> data) {
    final item = Map<String, dynamic>.from(data['user'] as Map);
    return AuthUser(
      id: item['id'] as String,
      email: item['email'] as String,
      name: item['name'] as String,
    );
  }

  Future<AuthUser> _setSession(Map<String, dynamic> response) async {
    final token = response['token'] as String;
    final user = _user(response);
    await _withSessionStorage(
      () => _storage.write(key: _sessionKey, value: token),
    );
    return user;
  }

  @override
  Future<AuthUser> signIn({required String email, required String password}) async =>
      _setSession(await _request('POST', '/v1/auth/login', body: {
        'email': email.trim(), 'password': password,
      }));

  @override
  Future<AuthUser> signUp({
    required String name, required String email, required String password,
  }) async => _setSession(await _request('POST', '/v1/auth/register', body: {
        'name': name.trim(), 'email': email.trim(), 'password': password,
      }));

  @override
  Future<AuthUser?> restoreSession() async {
    final token = await _withSessionStorage(
      () => _storage.read(key: _sessionKey),
    );
    if (token == null || token.isEmpty) return null;
    // Network errors preserve the saved token and let the UI offer a retry.
    // Only a server rejection invalidates it.
    return _user(await _request('GET', '/v1/auth/me', token: token));
  }

  Future<String> _token() async {
    final token = await _withSessionStorage(
      () => _storage.read(key: _sessionKey),
    );
    if (token == null || token.isEmpty) {
      throw const SessionExpiredException();
    }
    return token;
  }

  @override
  Future<bool> checkServer() async {
    try {
      final response = await _request('GET', '/ready');
      return response['status'] == 'ready';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<EcosystemService>> listServices() async {
    final result = await _request('GET', '/v1/services', token: await _token());
    final services = result['services'];
    if (services is! List) throw const FormatException('Некорректный каталог сервисов');
    return services.map((value) {
      final item = Map<String, dynamic>.from(value as Map);
      return EcosystemService(
        id: item['id'] as String,
        name: item['name'] as String,
        description: item['description'] as String? ?? '',
        url: item['url'] as String,
      );
    }).toList(growable: false);
  }

  @override
  Future<List<String>> favoriteServices() async {
    final response = await _request('GET', '/v1/me/preferences', token: await _token());
    final favorites = response['favorite_services'];
    if (favorites is! List) throw const FormatException('Некорректные избранные сервисы');
    return favorites.cast<String>().toList(growable: false);
  }

  @override
  Future<List<String>> saveFavoriteServices(List<String> serviceIds) async {
    final response = await _request('POST', '/v1/me/preferences',
      token: await _token(), body: {'favorite_services': serviceIds});
    final favorites = response['favorite_services'];
    if (favorites is! List) throw const FormatException('Некорректное избранное');
    return favorites.cast<String>().toList(growable: false);
  }

  @override
  Future<void> changePassword(String currentPassword, String nextPassword) async {
    await _request('POST', '/v1/auth/change-password', token: await _token(), body: {
      'current_password': currentPassword,
      'new_password': nextPassword,
    });
  }

  @override
  Future<int> revokeOtherSessions() async {
    final response = await _request('POST', '/v1/auth/logout-others', token: await _token());
    return response['revoked'] as int;
  }

  @override
  Future<AuthUser> updateName(String name) async {
    final result = await _request('POST', '/v1/auth/profile',
      token: await _token(), body: {'name': name});
    return _user(result);
  }

  @override
  Future<List<AccountSession>> listSessions() async {
    final response = await _request('GET', '/v1/auth/sessions', token: await _token());
    final sessions = response['sessions'];
    if (sessions is! List) throw const FormatException('Некорректные данные сессий');
    return sessions.map((value) {
      final item = Map<String, dynamic>.from(value as Map);
      return AccountSession(
        id: item['id'] as String,
        device: item['device'] as String,
        createdAt: DateTime.parse(item['created_at'] as String),
        lastSeenAt: DateTime.parse(item['last_seen_at'] as String),
        expiresAt: DateTime.parse(item['expires_at'] as String),
        current: item['current'] as bool,
      );
    }).toList(growable: false);
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    await _request('POST', '/v1/auth/sessions/revoke',
      token: await _token(), body: {'session_id': sessionId});
  }

  @override
  Future<NotificationFeed> listNotifications() async {
    final response = await _request(
      'GET', '/v1/notifications', token: await _token(),
    );
    final entries = response['notifications'];
    if (entries is! List || response['unread_count'] is! int) {
      throw const FormatException('Некорректный ответ сервера уведомлений.');
    }
    return NotificationFeed(
      unreadCount: response['unread_count'] as int,
      notifications: entries.map((entry) {
        final item = Map<String, dynamic>.from(entry as Map);
        return AccountNotification(
          id: item['id'] as String,
          type: item['type'] as String,
          title: item['title'] as String,
          body: item['body'] as String,
          createdAt: DateTime.parse(item['created_at'] as String),
          readAt: item['read_at'] == null
              ? null : DateTime.parse(item['read_at'] as String),
        );
      }).toList(growable: false),
    );
  }

  @override
  Future<void> readNotification(String id) async {
    await _request(
      'POST', '/v1/notifications/read',
      token: await _token(), body: {'id': id},
    );
  }

  @override
  Future<int> readAllNotifications() async {
    final response = await _request(
      'POST', '/v1/notifications/read-all', token: await _token(),
    );
    return response['updated'] as int;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    throw Exception('Восстановление пароля пока не настроено на сервере.');
  }

  @override
  Future<void> signOut() async {
    final token = await _withSessionStorage(
      () => _storage.read(key: _sessionKey),
    );
    try {
      if (token != null) {
        await _request('POST', '/v1/auth/logout', token: token);
      }
    } catch (_) {
      // Local logout must work even without an API connection.
    } finally {
      await _withSessionStorage(() async {
        if (await _storage.read(key: _sessionKey) == token) {
          await _storage.delete(key: _sessionKey);
        }
      });
    }
  }
}
