import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/app.dart';

void main() {
  testWidgets('VocablyApp builds without throwing', (tester) async {
    // `flutter test` has no platform channels, so Firebase is never
    // initialized here and authStateProvider's stream never emits — the
    // app correctly stays on its loading state rather than crashing.
    // Exercising the real sign-up/login/routing flow needs a running app
    // against the real Firebase project (manual verification — see the
    // Milestone 2 test matrix), not this smoke test.
    await tester.pumpWidget(const ProviderScope(child: VocablyApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
