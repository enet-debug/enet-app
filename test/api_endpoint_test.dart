import 'package:enet_app/features/auth/data/api_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('API endpoint validation', () {
    test('accepts secure public URLs and local development loopback', () {
      expect(
        ApiAuthRepository.normalizeApiEndpoint('https://api.example.org/'),
        'https://api.example.org',
      );
      expect(
        ApiAuthRepository.normalizeApiEndpoint('https://api.example.org/enet/'),
        'https://api.example.org/enet',
      );
      expect(
        ApiAuthRepository.normalizeApiEndpoint('http://127.0.0.1:8787/'),
        'http://127.0.0.1:8787',
      );
      expect(
        ApiAuthRepository.normalizeApiEndpoint('http://localhost:8787'),
        'http://localhost:8787',
      );
    });

    test('rejects insecure remote endpoints and malformed URLs', () {
      expect(() => ApiAuthRepository.normalizeApiEndpoint('http://api.example.org'),
          throwsFormatException);
      expect(() => ApiAuthRepository.normalizeApiEndpoint('ftp://api.example.org'),
          throwsFormatException);
      expect(() => ApiAuthRepository.normalizeApiEndpoint('https://user:pass@example.org'),
          throwsFormatException);
      expect(() => ApiAuthRepository.normalizeApiEndpoint('https://api.example.org?token=x'),
          throwsFormatException);
      expect(() => ApiAuthRepository.normalizeApiEndpoint('https://api.example.org#fragment'),
          throwsFormatException);
      expect(() => ApiAuthRepository.normalizeApiEndpoint('not-a-url'),
          throwsFormatException);
    });
  });
}
