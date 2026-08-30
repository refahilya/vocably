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

  group('AiWorkerService.generateStory', () {
    test('returns story + translation on a well-formed 200 response', () async {
      Uri? capturedUri;
      String? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'story': 'Yesterday I [[run|ran]] to the park.',
            'translation': 'Kemarin saya berlari ke taman.',
          }),
          200,
        );
      });
      final service = AiWorkerService(
        client: client,
        authService: _FakeAuthService('fake-id-token'),
      );

      final result = await service.generateStory(targetWords: ['run'], prompt: 'liburan');

      expect(result.story, 'Yesterday I [[run|ran]] to the park.');
      expect(result.translation, 'Kemarin saya berlari ke taman.');
      expect(capturedUri?.path, '/generate-story');
      expect(jsonDecode(capturedBody!), {
        'targetWords': ['run'],
        'prompt': 'liburan',
      });
    });

    test('throws AiWorkerException on the Worker\'s structured error response (e.g. 502)', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'AI backend failed to mark every target word.'}),
          502,
        ),
      );
      final service = AiWorkerService(
        client: client,
        authService: _FakeAuthService('fake-id-token'),
      );

      expect(
        () => service.generateStory(targetWords: ['run'], prompt: 'liburan'),
        throwsA(isA<AiWorkerException>()),
      );
    });

    test('throws AiWorkerException when "story" is missing from the response', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'translation': 'saja'}), 200),
      );
      final service = AiWorkerService(
        client: client,
        authService: _FakeAuthService('fake-id-token'),
      );

      expect(
        () => service.generateStory(targetWords: ['run'], prompt: 'liburan'),
        throwsA(isA<AiWorkerException>()),
      );
    });
  });

  group('AiWorkerService.cowriteTurn', () {
    test('returns every structured field on a well-formed 200 response', () async {
      Uri? capturedUri;
      String? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'aiTurn': 'The dog barked loudly.',
            'feedback': 'Good sentence!',
            'hasError': false,
            'wordsUsedCorrectly': ['run'],
            'suggestion': null,
            'aiUsedWords': [],
          }),
          200,
        );
      });
      final service = AiWorkerService(
        client: client,
        authService: _FakeAuthService('fake-id-token'),
      );

      final result = await service.cowriteTurn(
        transcript: [
          {'sender': 'siswa', 'text': 'I ran fast.'},
        ],
        remainingWords: ['souvenir'],
        requestSuggestion: false,
      );

      expect(result.aiTurn, 'The dog barked loudly.');
      expect(result.feedback, 'Good sentence!');
      expect(result.hasError, isFalse);
      expect(result.wordsUsedCorrectly, ['run']);
      expect(result.suggestion, isNull);
      expect(result.aiUsedWords, isEmpty);
      expect(capturedUri?.path, '/cowrite-turn');
      expect(jsonDecode(capturedBody!), {
        'transcript': [
          {'sender': 'siswa', 'text': 'I ran fast.'},
        ],
        'remainingWords': ['souvenir'],
        'requestSuggestion': false,
      });
    });

    test('returns a non-null suggestion when requested', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'aiTurn': 'Continuing...',
            'feedback': null,
            'hasError': false,
            'wordsUsedCorrectly': <String>[],
            'suggestion': 'You could write about a souvenir.',
            'aiUsedWords': <String>[],
          }),
          200,
        ),
      );
      final service = AiWorkerService(
        client: client,
        authService: _FakeAuthService('fake-id-token'),
      );

      final result = await service.cowriteTurn(
        transcript: const [],
        remainingWords: ['souvenir'],
        requestSuggestion: true,
      );

      expect(result.suggestion, 'You could write about a souvenir.');
    });

    test('throws AiWorkerException when "hasError" has the wrong type', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'aiTurn': 'Continuing...',
            'feedback': null,
            'hasError': 'not-a-bool',
            'wordsUsedCorrectly': <String>[],
            'suggestion': null,
          }),
          200,
        ),
      );
      final service = AiWorkerService(
        client: client,
        authService: _FakeAuthService('fake-id-token'),
      );

      expect(
        () => service.cowriteTurn(
          transcript: const [],
          remainingWords: const [],
          requestSuggestion: false,
        ),
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
        () => service.cowriteTurn(
          transcript: const [],
          remainingWords: const [],
          requestSuggestion: false,
        ),
        throwsA(isA<AiWorkerException>()),
      );
    });

    test(
      'Stage 8: parses a non-empty aiUsedWords (a fallback turn)',
      () async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({
              'aiTurn': 'My baby cousin was there too.',
              'feedback': 'Bagus!',
              'hasError': false,
              'wordsUsedCorrectly': <String>[],
              'suggestion': null,
              'aiUsedWords': ['baby'],
            }),
            200,
          ),
        );
        final service = AiWorkerService(
          client: client,
          authService: _FakeAuthService('fake-id-token'),
        );

        final result = await service.cowriteTurn(
          transcript: const [],
          remainingWords: const ['baby'],
          requestSuggestion: false,
        );

        expect(result.aiUsedWords, ['baby']);
      },
    );

    test(
      'Stage 8: throws AiWorkerException when aiUsedWords is missing from the response',
      () async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({
              'aiTurn': 'Continuing...',
              'feedback': null,
              'hasError': false,
              'wordsUsedCorrectly': <String>[],
              'suggestion': null,
              // aiUsedWords omitted on purpose.
            }),
            200,
          ),
        );
        final service = AiWorkerService(
          client: client,
          authService: _FakeAuthService('fake-id-token'),
        );

        expect(
          () => service.cowriteTurn(
            transcript: const [],
            remainingWords: const [],
            requestSuggestion: false,
          ),
          throwsA(isA<AiWorkerException>()),
        );
      },
    );
  });
}
