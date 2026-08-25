import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/screens/student/vocab_browser/vocab_browser_screen.dart';

void main() {
  testWidgets(
    'VocabBrowserScreen renders without throwing through loading and '
    'the eventual state (Firebase is not initialized in flutter test, '
    'so the level provider settles into an error state — same situation '
    'test/widget_test.dart already documents for the whole app)',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: VocabBrowserScreen())),
      );

      // First frame: still loading.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Jelajah Kosakata'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
