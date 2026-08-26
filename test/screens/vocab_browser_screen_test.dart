import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/screens/student/vocab_browser/vocab_browser_screen.dart';
import 'package:vocably/services/vocab_bundle_service.dart';

/// Bare-minimum fake — same pattern as
/// `test/services/vocab_bundle_service_test.dart`'s `_FakeAssetBundle`.
/// Used here (rather than the real `rootBundle`, now that real
/// multi-hundred-KB bundle files exist under `assets/vocab/` — Milestone
/// 4 Stage 10) so this widget test's `pumpAndSettle` doesn't depend on
/// genuine disk I/O completing within `flutter test`'s fake-async pump
/// loop (it doesn't, without `tester.runAsync()` — an artifact of the
/// test harness, not a production bug: a real running app resolves this
/// `rootBundle.loadString` call immediately either way).
class _EmptyAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(jsonEncode(<dynamic>[]));
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

/// A fake bundle serving different per-level JSON content — lets the
/// pagination tests below give A1 many words while other levels stay
/// small (or empty), same idea as `_EmptyAssetBundle` above.
class _MapAssetBundle extends AssetBundle {
  _MapAssetBundle(this._assets);
  final Map<String, List<Map<String, dynamic>>> _assets;

  @override
  Future<ByteData> load(String key) async {
    final content = _assets[key] ?? const <Map<String, dynamic>>[];
    final bytes = utf8.encode(jsonEncode(content));
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

Map<String, dynamic> _word(
  String word, {
  String cefrLevel = 'A1',
  List<String> topics = const ['General'],
}) {
  return {
    'word': word,
    'meanings': [
      {'pos': 'noun', 'translation': 'terjemahan-$word'},
    ],
    'posList': ['noun'],
    'cefrLevel': cefrLevel,
    'topics': topics,
  };
}

void main() {
  testWidgets(
    'VocabBrowserScreen renders without throwing through loading and '
    'the eventual state (Firebase is not initialized in flutter test, '
    'so the level provider settles into an error state — same situation '
    'test/widget_test.dart already documents for the whole app)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vocabBundleServiceProvider.overrideWithValue(
              VocabBundleService(assetBundle: _EmptyAssetBundle()),
            ),
          ],
          child: const MaterialApp(home: VocabBrowserScreen()),
        ),
      );

      // First frame: still loading.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Jelajah Kosakata'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  group('Pagination (Milestone 4 finalization)', () {
    // 120 A1 words -> 3 pages of 50/50/20 at the default page size. The
    // first 30 additionally carry a "Special" topic (fewer than one
    // page once filtered by it); the rest only have "General".
    final a1Words = [
      for (var i = 0; i < 120; i++)
        _word(
          'word${i.toString().padLeft(3, '0')}',
          topics: i < 30 ? ['General', 'Special'] : ['General'],
        ),
    ];
    // A different, also-paginated level, to prove switching levels
    // resets to page 1 rather than carrying over A1's current page.
    final a2Words = [for (var i = 0; i < 75; i++) _word('a2word$i', cefrLevel: 'A2')];

    Future<void> pumpBrowser(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vocabBundleServiceProvider.overrideWithValue(
              VocabBundleService(
                assetBundle: _MapAssetBundle({
                  'assets/vocab/vocab_a1.json': a1Words,
                  'assets/vocab/vocab_a2.json': a2Words,
                }),
              ),
            ),
          ],
          child: const MaterialApp(home: VocabBrowserScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows "Halaman 1 dari 3" and the first page\'s words for 120 results', (
      tester,
    ) async {
      await pumpBrowser(tester);

      expect(find.text('Halaman 1 dari 3'), findsOneWidget);
      // word049 (the page's last item) isn't asserted here — the
      // ListView only builds visible items and this is above the fold
      // without scrolling; exact page-boundary slicing is already
      // exhaustively covered by the pure `paginate()` unit tests.
      expect(find.text('word000'), findsOneWidget);
      expect(find.text('word050'), findsNothing); // that's page 2
    });

    testWidgets(
      'pagination bar does not overflow at the canonical ~390px mobile '
      'width (regression test for the real-Chrome layout overflow found '
      'during manual verification — see PROJECT_STATE.md)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpBrowser(tester);

        expect(find.text('Halaman 1 dari 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Previous is disabled on the first page', (tester) async {
      await pumpBrowser(tester);

      final previousButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('vocabBrowserPreviousPage')),
      );
      expect(previousButton.onPressed, isNull);
    });

    testWidgets('Next moves to page 2, showing page 2\'s words and enabling Previous', (
      tester,
    ) async {
      await pumpBrowser(tester);

      await tester.tap(find.byKey(const Key('vocabBrowserNextPage')));
      await tester.pumpAndSettle();

      expect(find.text('Halaman 2 dari 3'), findsOneWidget);
      expect(find.text('word050'), findsOneWidget);
      expect(find.text('word000'), findsNothing);

      final previousButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('vocabBrowserPreviousPage')),
      );
      expect(previousButton.onPressed, isNotNull);
    });

    testWidgets(
      'the last page is smaller than the page size and disables Next',
      (tester) async {
        await pumpBrowser(tester);

        await tester.tap(find.byKey(const Key('vocabBrowserNextPage')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('vocabBrowserNextPage')));
        await tester.pumpAndSettle();

        expect(find.text('Halaman 3 dari 3'), findsOneWidget);
        expect(find.text('word100'), findsOneWidget);

        final nextButton = tester.widget<OutlinedButton>(
          find.byKey(const Key('vocabBrowserNextPage')),
        );
        expect(nextButton.onPressed, isNull);
      },
    );

    testWidgets('Previous navigates back a page', (tester) async {
      await pumpBrowser(tester);

      await tester.tap(find.byKey(const Key('vocabBrowserNextPage')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vocabBrowserPreviousPage')));
      await tester.pumpAndSettle();

      expect(find.text('Halaman 1 dari 3'), findsOneWidget);
      expect(find.text('word000'), findsOneWidget);
    });

    testWidgets('switching CEFR level resets pagination to page 1', (tester) async {
      await pumpBrowser(tester);

      await tester.tap(find.byKey(const Key('vocabBrowserNextPage')));
      await tester.pumpAndSettle();
      expect(find.text('Halaman 2 dari 3'), findsOneWidget);

      await tester.tap(find.text('A2'));
      await tester.pumpAndSettle();

      expect(find.text('Halaman 1 dari 2'), findsOneWidget);
      expect(find.text('a2word0'), findsOneWidget);
    });

    testWidgets(
      'switching browse mode resets pagination to page 1',
      (tester) async {
        await pumpBrowser(tester);

        await tester.tap(find.byKey(const Key('vocabBrowserNextPage')));
        await tester.pumpAndSettle();
        expect(find.text('Halaman 2 dari 3'), findsOneWidget);

        await tester.tap(find.text('POS'));
        await tester.pumpAndSettle();

        expect(find.text('Halaman 1 dari 3'), findsOneWidget);
      },
    );

    testWidgets(
      'filtering to a smaller result (topic) resets to page 1 and hides '
      'pagination once everything fits on one page',
      (tester) async {
        await pumpBrowser(tester);

        await tester.tap(find.byKey(const Key('vocabBrowserNextPage')));
        await tester.pumpAndSettle();
        expect(find.text('Halaman 2 dari 3'), findsOneWidget);

        await tester.tap(find.text('Tema'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Special').last);
        await tester.pumpAndSettle();

        // 30 "Special"-topic words fit on a single 50-item page — no
        // pagination bar should be shown at all (not unnecessarily
        // prominent), and it must not still be stuck on page 2.
        expect(find.textContaining('Halaman'), findsNothing);
        expect(find.text('word000'), findsOneWidget);
      },
    );

    testWidgets(
      'an empty level (no data at all, e.g. C2) shows the empty state and '
      'no pagination controls — the exhaustive "a real filter narrows to '
      'zero" case is already covered by the pure applyVocabBrowseFilter/'
      'paginate unit tests; this confirms the pagination bar specifically '
      'stays absent whenever the screen renders any empty state',
      (tester) async {
        await pumpBrowser(tester);

        await tester.tap(find.text('C2'));
        await tester.pumpAndSettle();

        expect(find.text('Belum ada kata di level ini.'), findsOneWidget);
        expect(find.textContaining('Halaman'), findsNothing);
      },
    );
  });
}
