import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/dictionary_providers.dart';
import 'package:vocably/screens/student/vocab_browser/word_detail_screen.dart';
import 'package:vocably/services/dictionary_api_service.dart';

void main() {
  final entry = VocabBundleEntry(
    word: 'address',
    meanings: const [
      VocabMeaning(pos: 'noun', translationId: 'alamat'),
      VocabMeaning(pos: 'verb', translationId: null),
    ],
    cefrLevel: 'A1',
    topics: const ['General'],
  );

  testWidgets(
    'WordDetailScreen renders both meaning blocks and degrades gracefully '
    'when the DictionaryAPI lookup fails (Layer 1, SPEC.md §3.5)',
    (tester) async {
      // A MockClient that always errors — exercises the "no English
      // definition available" degradation path without hitting the
      // network from a test.
      final fakeClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dictionaryApiServiceProvider.overrideWithValue(
              DictionaryApiService(client: fakeClient),
            ),
          ],
          child: MaterialApp(home: WordDetailScreen(entry: entry)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Word title, both POS badges, the available translation, and the
      // "translation not available" fallback text should all render.
      expect(find.text('ADDRESS'), findsOneWidget);
      expect(find.text('noun'), findsOneWidget);
      expect(find.text('verb'), findsOneWidget);
      expect(find.text('alamat'), findsOneWidget);
      expect(find.text('Terjemahan belum tersedia'), findsOneWidget);
      expect(
        find.text('Definisi bahasa Inggris tidak tersedia untuk kata ini.'),
        findsNWidgets(2),
      );
    },
  );
}
