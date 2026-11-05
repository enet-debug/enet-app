import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../domain/auth_repository.dart';

/// Real eNet ID backend. Use HTTPS when the API is outside localhost.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({http.Client? client}) : _client = client ?? http.Client();

  static const apiUrl = String.fromEnvironment(
    'ENET_API_URL', defaultValue: 'http://127.0.0.1:8787',
  );
  static const _sessionKey = 'enet_id_session';
  final http.Client _client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Uri _uri(String path) => Uri.parse(
    '${apiUrl.replaceAll(RegExp(r'/$'), '')}$path',
  );

  Future<Map<String, dynamic>> _request(
    String method, String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final http.Response response;
    try {
      response = await (method == 'GET'
        ? _client.get(_uri(path), headers: headers)
        : _client.post(
            _uri(path),
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw Exception('Сервер eNet не ответил. Проверьте, запущен ли API.');
    } on http.ClientException {
      throw Exception('Нет соединения с eNet API. Проверьте адрес сервера.');
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
      throw Exception(message is String ? message : 'Ошибка API: ${response.statusCode}');
    }
    return result;
  }

  AuthUser _user(Map<String, dynamic> data) {
    final item = Map<String, dynamic>.from(data['user'] as Map);
    return AuthUser(email: item['email'] as String, name: item['name'] as String);
  }

  Future<AuthUser> _setSession(Map<String, dynamic> response) async {
    final token = response['token'] as String;
    await _storage.write(key: _sessionKey, value: token);
    return _user(response);
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
    final token = await _storage.read(key: _sessionKey);
    if (token == null || token.isEmpty) return null;
    try {
      return _user(await _request('GET', '/v1/auth/me', token: token));
    } catch (_) {
      // The session may have expired or the local API may be offline.
      // Do not expose an unverified account as authenticated.
      return null;
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    throw Exception('Восстановление пароля пока не настроено на сервере.');
  }

  @override
  Future<void> signOut() async {
    final token = await _storage.read(key: _sessionKey);
    try {
      if (token != null) {
        await _request('POST', '/v1/auth/logout', token: token);
      }
    } catch (_) {
      // Local logout must work even without an API connection.
    } finally {
      await _storage.delete(key: _sessionKey);
    }
  }
}
