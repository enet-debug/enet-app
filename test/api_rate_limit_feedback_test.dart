import 'package:enet_app/features/auth/data/api_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  test('rate-limited login displays the server retry time', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ApiAuthRepository(client: MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/v1/auth/login');
      return http.Response(
        '{"error":{"code":"rate_limited","message":"Слишком много попыток."}}',
        429,
        headers: {'content-type': 'application/json', 'retry-after': '37'},
      );
    }));

    await expectLater(
      repository.signIn(email: 'test@example.org', password: 'Wrong-Password-123'),
      throwsA(predicate((error) =>
        error.toString().contains('Повторите через 37 сек.'))),
    );
  });

  test('unexpected or unsafe Retry-After values are not printed', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ApiAuthRepository(client: MockClient((request) async =>
      http.Response(
        '{"error":{"code":"rate_limited","message":"Слишком много попыток."}}',
        429, headers: {'retry-after': '9999999999'},
      ),
    ));
    await expectLater(
      repository.signIn(email: 'test@example.org', password: 'Wrong-Password-123'),
      throwsA(predicate((error) =>
        error.toString().contains('Слишком много попыток.') &&
        !error.toString().contains('9999999999'))),
    );
  });
}
