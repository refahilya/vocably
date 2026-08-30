import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/ai_worker_providers.dart';
import 'package:vocably/providers/dictionary_providers.dart';
import 'package:vocably/screens/student/vocab_browser/word_detail_screen.dart';
import 'package:vocably/services/ai_worker_service.dart';
import 'package:vocably/services/dictionary_api_service.dart';

/// Always fails — used everywhere in this file except the dedicated lazy-
/// translation test group, so the `verb` meaning below (deliberately
/// `translation: null`, to exercise the lazy-translate display alongside
/// the DictionaryAPI states this file is actually about) settles to a
/// deterministic "—" instead of incidentally depending on Firebase not
/// being initialized under `flutter test`.
class _AlwaysFailingAiWorkerService extends AiWorkerService {
  @override
  Future<String> translate({required String word, required String pos}) {
    throw const AiWorkerException('simulated failure for this test');
  }
}

void main() {
  final entry = VocabBundleEntry(
    word: 'address',
    meanings: const [
      VocabMeaning(pos: 'noun', translation: 'alamat'),
      VocabMeaning(pos: 'verb', translation: null),
    ],
    cefrLevel: 'A1',
    topics: const ['General'],
  );

  testWidgets(
    'WordDetailScreen renders both meaning blocks and degrades gracefully '
    'to the permanent "not available" message on a genuine 404 '
    '(Layer 1, SPEC.md §3.5) — not the retryable message',
    (tester) async {
      final fakeClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'title': 'No Definitions Found'}),
          404,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dictionaryApiServiceProvider.overrideWithValue(
              DictionaryApiService(client: fakeClient),
            ),
            aiWorkerServiceProvider.overrideWithValue(_AlwaysFailingAiWorkerService()),
          ],
          child: MaterialApp(home: WordDetailScreen(entry: entry)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ADDRESS'), findsOneWidget);
      expect(find.text('noun'), findsOneWidget);
      expect(find.text('verb'), findsOneWidget);
      expect(find.text('alamat'), findsOneWidget);
      // "verb"'s translation is null — lazy-translate is attempted via
      // aiWorkerServiceProvider (stubbed to always fail here, see
      // _AlwaysFailingAiWorkerService), so it settles to "—" rather than
      // hanging or showing an error screen (DESIGN_REFERENCE.md §5.8).
      expect(find.text('—'), findsOneWidget);
      expect(
        find.text('Definisi bahasa Inggris tidak tersedia untuk kata ini.'),
        findsNWidgets(2),
      );
      // A genuine 404 is not retryable — no "Coba lagi" should appear.
      expect(find.text('Coba lagi'), findsNothing);
    },
  );

  testWidgets(
    'shows the loading state (not "not available") while the lookup is '
    'still in flight — regression: the old whenOrNull-based code treated '
    'loading identically to "no data", flashing a false "unavailable" '
    'message before the API even responded',
    (tester) async {
      // A Completer left uncompleted while we inspect the loading frame
      // — unlike Future.delayed, this itself leaves no pending Timer.
      // Completed further down before the test ends (see there for why).
      final pendingResponse = Completer<http.Response>();
      final fakeClient = MockClient((request) => pendingResponse.future);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dictionaryApiServiceProvider.overrideWithValue(
              DictionaryApiService(client: fakeClient),
            ),
            aiWorkerServiceProvider.overrideWithValue(_AlwaysFailingAiWorkerService()),
          ],
          child: MaterialApp(home: WordDetailScreen(entry: entry)),
        ),
      );
      await tester.pump();

      expect(find.text('Memuat definisi...'), findsNWidgets(2));
      expect(
        find.text('Definisi bahasa Inggris tidak tersedia untuk kata ini.'),
        findsNothing,
      );

      // Resolve the in-flight request before the test ends — an
      // abandoned request still has its own pending 8s HTTP timeout
      // Timer running underneath, which the test framework flags as
      // "leaked" if the test finishes while it's still outstanding.
      pendingResponse.complete(http.Response('[]', 200));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a transient/network failure shows a retryable message with "Coba '
    'lagi" (regression: previously a 500/network failure rendered the '
    'exact same permanent "not available" text as a genuine 404, giving '
    'no way to tell a fixable failure apart from a real content gap)',
    (tester) async {
      var callCount = 0;
      final fakeClient = MockClient((request) async {
        callCount++;
        return http.Response('Internal Server Error', 500);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dictionaryApiServiceProvider.overrideWithValue(
              DictionaryApiService(client: fakeClient),
            ),
            aiWorkerServiceProvider.overrideWithValue(_AlwaysFailingAiWorkerService()),
          ],
          child: MaterialApp(home: WordDetailScreen(entry: entry)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Gagal memuat definisi. Periksa koneksi lalu coba lagi.'),
        findsNWidgets(2),
      );
      expect(
        find.text('Definisi bahasa Inggris tidak tersedia untuk kata ini.'),
        findsNothing,
      );
      expect(find.text('Coba lagi'), findsNWidgets(2));

      final callsBeforeRetry = callCount;
      await tester.tap(find.text('Coba lagi').first);
      await tester.pumpAndSettle();

      expect(callCount, greaterThan(callsBeforeRetry));
    },
  );

  testWidgets(
    'regression: a "modal"-tagged meaning (Vocably/Oxford taxonomy) now '
    'shows the definition DictionaryAPI returns under "verb" — this used '
    'to silently show "not available" before the POS-alias fix, even '
    'though the API genuinely had the content (confirmed against the '
    'real API for "can"/"must")',
    (tester) async {
      final modalEntry = VocabBundleEntry(
        word: 'can',
        meanings: const [VocabMeaning(pos: 'modal', translation: 'bisa')],
        cefrLevel: 'A1',
        topics: const ['General'],
      );
      final fakeClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'meanings': [
                {
                  'partOfSpeech': 'verb',
                  'definitions': [
                    {'definition': 'to be able to'},
                  ],
                },
              ],
            },
          ]),
          200,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dictionaryApiServiceProvider.overrideWithValue(
              DictionaryApiService(client: fakeClient),
            ),
            aiWorkerServiceProvider.overrideWithValue(_AlwaysFailingAiWorkerService()),
          ],
          child: MaterialApp(home: WordDetailScreen(entry: modalEntry)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('to be able to'), findsOneWidget);
      expect(
        find.text('Definisi bahasa Inggris tidak tersedia untuk kata ini.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Stage 7: normal Word Detail (default hideCartAction) still shows the '
    '"+ Pelajari" cart toggle, exactly as before',
    (tester) async {
      final fakeClient = MockClient((request) async {
        return http.Response(jsonEncode({'title': 'No Definitions Found'}), 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dictionaryApiServiceProvider.overrideWithValue(
              DictionaryApiService(client: fakeClient),
            ),
            aiWorkerServiceProvider.overrideWithValue(_AlwaysFailingAiWorkerService()),
          ],
          child: MaterialApp(home: WordDetailScreen(entry: entry)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Tambah ke Keranjang Pelajari'), findsOneWidget);
    },
  );

  testWidgets(
    'Stage 7: Word Detail opened from Learning Flow (hideCartAction: true) '
    'hides the "+ Pelajari" cart toggle',
    (tester) async {
      final fakeClient = MockClient((request) async {
        return http.Response(jsonEncode({'title': 'No Definitions Found'}), 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dictionaryApiServiceProvider.overrideWithValue(
              DictionaryApiService(client: fakeClient),
            ),
            aiWorkerServiceProvider.overrideWithValue(_AlwaysFailingAiWorkerService()),
          ],
          child: MaterialApp(
            home: WordDetailScreen(entry: entry, hideCartAction: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Tambah ke Keranjang Pelajari'), findsNothing);
      expect(find.byTooltip('Hapus dari Keranjang Pelajari'), findsNothing);
      // Everything else about the screen is unaffected.
      expect(find.text('ADDRESS'), findsOneWidget);
      expect(find.text('alamat'), findsOneWidget);
    },
  );
}
