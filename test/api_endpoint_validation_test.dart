import 'package:enet_app/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeApiBaseUrl', () {
    test('accepts remote HTTPS and removes trailing slashes', () {
      expect(normalizeApiBaseUrl('  https://api.example.com/api/  '),
          'https://api.example.com/api');
    });

    test('allows HTTP only on loopback development addresses', () {
      expect(normalizeApiBaseUrl('http://127.0.0.1:8787/'),
          'http://127.0.0.1:8787');
      expect(normalizeApiBaseUrl('http://localhost:8787'),
          'http://localhost:8787');
    });

    test('rejects insecure remote HTTP', () {
      expect(() => normalizeApiBaseUrl('http://api.example.com'),
          throwsA(isA<FormatException>()));
    });

    test('rejects credentials, query strings and fragments', () {
      for (final value in [
        'https://user:password@api.example.com',
        'https://api.example.com?token=secret',
        'https://api.example.com#fragment',
      ]) {
        expect(() => normalizeApiBaseUrl(value),
            throwsA(isA<FormatException>()));
      }
    });

    test('rejects invalid and unsupported schemes', () {
      for (final value in ['', 'not a url', 'ftp://api.example.com',
        'file:///tmp/enet', 'http://192.168.1.10:8787']) {
        expect(() => normalizeApiBaseUrl(value),
            throwsA(isA<FormatException>()));
      }
    });
  });
}
