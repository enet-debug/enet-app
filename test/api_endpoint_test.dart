import 'package:flutter_test/flutter_test.dart';
import 'package:enet_app/features/auth/application/auth_controller.dart';
import 'package:enet_app/features/auth/data/demo_auth_repository.dart';
import 'package:enet_app/features/auth/data/api_endpoint_policy.dart';

class _EndpointRepository extends DemoAuthRepository {
  String endpoint = 'http://127.0.0.1:8787';
  @override
  Future<String> getApiEndpoint() async => endpoint;
  @override
  Future<void> setApiEndpoint(String value) async {
    endpoint = ApiEndpointPolicy.normalize(value);
  }
}

void main() {
  test('only a different API endpoint clears an existing sign-in', () async {
    final repository = _EndpointRepository();
    final auth = AuthController(repository);
    try {
      await auth.signIn('me@example.org', 'TestPassword-123');
      expect(auth.user, isNotNull);
      await auth.setApiEndpoint('http://127.0.0.1:8787/');
      expect(auth.user, isNotNull);
      await auth.setApiEndpoint('https://api.example.org');
      expect(auth.user, isNull);
    } finally {
      auth.dispose();
    }
  });

  test('allows remote HTTPS and strips a trailing slash', () {
    expect(ApiEndpointPolicy.normalize(' https://api.enet-dev.ru/ '), 'https://api.enet-dev.ru');
    expect(ApiEndpointPolicy.normalize('https://example.org:8443'), 'https://example.org:8443');
  });

  test('allows loopback-only HTTP for local API development', () {
    expect(ApiEndpointPolicy.normalize('http://127.0.0.1:8787/'), 'http://127.0.0.1:8787');
    expect(ApiEndpointPolicy.normalize('http://localhost:8787'), 'http://localhost:8787');
  });

  test('rejects insecure remote endpoints and ambiguous URL forms', () {
    for (final url in [
      'http://api.enet-dev.ru', 'http://192.168.1.15:8787',
      'https://example.org/path', 'https://example.org/?key=x',
      'https://example.org/#anchor', 'https://name:password@example.org',
      'file:///etc/shadow', 'not a URL', 'https://',
    ]) {
      expect(() => ApiEndpointPolicy.normalize(url), throwsFormatException, reason: url);
    }
  });
}
