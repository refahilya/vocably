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

/// Controllable fake for the three lazy-translation states
/// (`DATA_MODEL.md` §2 point 4 / `DESIGN_REFERENCE.md` §5.8) — completes
/// or throws on demand, same `Completer` trick
/// `test/screens/word_detail_screen_test.dart` already uses for the
/// DictionaryAPI loading state (a real `Timer`-based delay would leave a
/// pending timer the test framework flags as leaked).
class _ControllableAiWorkerService extends AiWorkerService {
  final Completer<String> _completer = Completer<String>();

  @override
  Future<String> translate({required String word, required String pos}) => _completer.future;

  void succeedWith(String translation) => _completer.complete(translation);
  void failWith(Object error) => _completer.completeError(error);
}

/// A 404 from DictionaryAPI keeps this test focused on the translation
/// states only — the "Definisi bahasa Inggris tidak tersedia" text is
/// already covered by `word_detail_screen_test.dart`.
DictionaryApiService _notFoundDictionaryService() {
  return DictionaryApiService(
    client: MockClient((request) async => http.Response(jsonEncode({}), 404)),
  );
}

void main() {
  final entryWithMissingTranslation = VocabBundleEntry(
    word: 'run',
    meanings: const [VocabMeaning(pos: 'verb', translation: null)],
    cefrLevel: 'A1',
    topics: const ['General'],
  );

  testWidgets('shows a loading indicator while the Worker call is in flight', (tester) async {
    final aiWorkerService = _ControllableAiWorkerService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryApiServiceProvider.overrideWithValue(_notFoundDictionaryService()),
          aiWorkerServiceProvider.overrideWithValue(aiWorkerService),
        ],
        child: MaterialApp(home: WordDetailScreen(entry: entryWithMissingTranslation)),
      ),
    );
    await tester.pump();

    expect(find.text('Menerjemahkan...'), findsOneWidget);
    expect(find.text('berlari'), findsNothing);
    expect(find.text('—'), findsNothing);

    // Resolve before the test ends so nothing is left pending.
    aiWorkerService.succeedWith('berlari');
    await tester.pumpAndSettle();
  });

  testWidgets('shows the translation once the Worker call succeeds', (tester) async {
    final aiWorkerService = _ControllableAiWorkerService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryApiServiceProvider.overrideWithValue(_notFoundDictionaryService()),
          aiWorkerServiceProvider.overrideWithValue(aiWorkerService),
        ],
        child: MaterialApp(home: WordDetailScreen(entry: entryWithMissingTranslation)),
      ),
    );
    await tester.pump();

    aiWorkerService.succeedWith('berlari');
    await tester.pumpAndSettle();

    expect(find.text('berlari'), findsOneWidget);
    expect(find.text('Menerjemahkan...'), findsNothing);
  });

  testWidgets('shows a dim "—" (not an error screen) when the Worker call fails', (tester) async {
    final aiWorkerService = _ControllableAiWorkerService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryApiServiceProvider.overrideWithValue(_notFoundDictionaryService()),
          aiWorkerServiceProvider.overrideWithValue(aiWorkerService),
        ],
        child: MaterialApp(home: WordDetailScreen(entry: entryWithMissingTranslation)),
      ),
    );
    await tester.pump();

    aiWorkerService.failWith(const AiWorkerException('simulated failure'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Menerjemahkan...'), findsNothing);
  });
}
