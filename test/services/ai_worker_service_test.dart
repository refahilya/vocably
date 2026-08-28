import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vocably/services/ai_worker_service.dart';
import 'package:vocably/services/auth_service.dart';

/// Stands in for a signed-in user without touching real Firebase Auth —
/// same reasoning as `_FakeAuthService` in
/// `test/screens/destination_placeholders_test.dart`, extended here with
/// a controllable [getIdToken].
class _FakeAuthService extends AuthService {
  _FakeAuthService(this._idToken);
  final String? _idToken;

  @override
  Future<String?> getIdToken() async => _idToken;
}

void main() {
  group('AiWorkerService.translate', () {
    test('returns the translation on a well-formed 200 response', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      String? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = request.body;
        return http.Response(jsonEncode({'translation': 'berlari'}), 200);
      });
      final service = AiWorkerService(
        client: client,
        authService: _FakeAuthService('fake-id-token'),
      );

      final translation = await service.translate(word: 'run', pos: 'verb');

      expect(translation, 'berlari');
      expect(capturedUri?.path, '/translate');
      expect(capturedHeaders?['Authorization'], 'Bearer fake-id-token');
      expect(jsonDecode(capturedBody!), {'word': 'run', 'pos': 'verb'});
    });

    test('throws AiWorkerException when not signed in (no ID token)', () async {
      final client = MockClient((request) async {
        fail('should not call the Worker at all when there is no ID token');
      });
      final service = AiWorkerService(client: client, authService: _FakeAuthService(null));

      expect(
        () => service.translate(word: 'run', pos: 'verb'),
        throwsA(isA<AiWorkerException>()),
      );
    });

    test('throws AiWorkerException on a non-200 response', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final service = AiWorkerService(
        client: client,
        authService: _FakeAuthService('fake-id-token'),
      );

      expect(
        () => service.translate(word: 'run', pos: 'verb'),
        throwsA(isA<AiWorkerException>()),
      );
    });

    test('throws AiWorkerException on a network failure', () async {
      final client = MockClient((request) async => throw Exception('no network'));
      final service = AiWorkerService(
        client: client,
        authService: _FakeAuthService('fake-id-token'),
      );

      expect(
        () => service.translate(word: 'run', pos: 'verb'),
        throwsA(isA<AiWorkerException>()),
      );
    });

    test('throws AiWorkerException when the response has no translation field', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'oops': true}), 200),
      );
      final service = AiWorkerService(
        client: client,
        authService: _FakeAuthService('fake-id-token'),
      );

      expect(
        () => service.translate(word: 'run', pos: 'verb'),
        throwsA(isA<AiWorkerException>()),
      );
    });

    test('throws AiWorkerException when the response body is not valid JSON', () async {
      final client = MockClient((request) async => http.Response('not json', 200));
      final service = AiWorkerService(
        client: client,
        authService: _FakeAuthService('fake-id-token'),
      );

      expect(
        () => service.translate(word: 'run', pos: 'verb'),
        throwsA(isA<AiWorkerException>()),
      );
    });
  });
}
