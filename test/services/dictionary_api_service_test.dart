import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vocably/services/dictionary_api_service.dart';

void main() {
  group('DictionaryApiService.lookup', () {
    test('returns success with a parsed entry on 200', () async {
      String? capturedUrl;
      final client = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response(
          jsonEncode([
            {
              'phonetic': 'həˈloʊ',
              'meanings': [
                {
                  'partOfSpeech': 'exclamation',
                  'definitions': [
                    {'definition': 'Used as a greeting.'},
                  ],
                },
              ],
            },
          ]),
          200,
          // http.Response derives its string encoding from the
          // `content-type` header — with none set, it falls back to
          // Latin-1, which can't represent the IPA phonetic characters
          // above (U+0259 'ə' etc.) and throws when `.body` is read. A
          // real DictionaryAPI response sends a proper
          // `application/json; charset=utf-8` content-type, so this
          // header makes the fake response match that instead of
          // tripping over a test-only encoding mismatch.
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = DictionaryApiService(client: client);

      final result = await service.lookup('hello');

      expect(
        capturedUrl,
        'https://api.dictionaryapi.dev/api/v2/entries/en/hello',
      );
      expect(result, isA<DictionaryLookupSuccess>());
      final entry = (result as DictionaryLookupSuccess).entry;
      expect(entry.phoneticText, 'həˈloʊ');
      expect(entry.meaningsByPos.keys, contains('exclamation'));
    });

    test('URL-encodes multi-word/phrase lookups', () async {
      String? capturedPath;
      final client = MockClient((request) async {
        capturedPath = request.url.path;
        return http.Response('[]', 200);
      });
      final service = DictionaryApiService(client: client);

      await service.lookup('wake up');

      expect(capturedPath, '/api/v2/entries/en/wake%20up');
    });

    test('returns notFound on a 404 response', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'title': 'No Definitions Found'}),
          404,
        );
      });
      final service = DictionaryApiService(client: client);

      final result = await service.lookup('zzzznotaword');

      expect(result, isA<DictionaryLookupError>());
      expect(
        (result as DictionaryLookupError).reason,
        DictionaryLookupFailure.notFound,
      );
    });

    test('returns networkError on a non-200/404 status', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });
      final service = DictionaryApiService(client: client);

      final result = await service.lookup('word');

      expect(result, isA<DictionaryLookupError>());
      expect(
        (result as DictionaryLookupError).reason,
        DictionaryLookupFailure.networkError,
      );
    });

    test('returns networkError when the response body is not valid JSON', () async {
      final client = MockClient((request) async {
        return http.Response('not json', 200);
      });
      final service = DictionaryApiService(client: client);

      final result = await service.lookup('word');

      expect(result, isA<DictionaryLookupError>());
      expect(
        (result as DictionaryLookupError).reason,
        DictionaryLookupFailure.networkError,
      );
    });

    test('returns networkError when the client throws (e.g. no connectivity)', () async {
      final client = MockClient((request) async {
        throw Exception('connection refused');
      });
      final service = DictionaryApiService(client: client);

      final result = await service.lookup('word');

      expect(result, isA<DictionaryLookupError>());
      expect(
        (result as DictionaryLookupError).reason,
        DictionaryLookupFailure.networkError,
      );
    });

    test('returns networkError when the decoded body is not a JSON array', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'unexpected': 'shape'}), 200);
      });
      final service = DictionaryApiService(client: client);

      final result = await service.lookup('word');

      expect(result, isA<DictionaryLookupError>());
      expect(
        (result as DictionaryLookupError).reason,
        DictionaryLookupFailure.networkError,
      );
    });
  });
}
