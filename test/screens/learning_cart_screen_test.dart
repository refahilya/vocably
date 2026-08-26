import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/providers/learning_cart_providers.dart';
import 'package:vocably/screens/student/vocab_browser/learning_cart_screen.dart';

void main() {
  VocabBundleEntry entry(String word) {
    return VocabBundleEntry.fromMap({
      'word': word,
      'meanings': [
        {'pos': 'noun', 'translation': 'terjemahan'},
      ],
      'posList': [],
      'cefrLevel': 'A1',
      'topics': ['Umum'],
    });
  }

  testWidgets('shows the empty-cart state when nothing has been added', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LearningCartScreen())),
    );

    expect(find.text('Keranjang Pelajari masih kosong.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a word already in the cart, and removing it returns to the empty state', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(learningCartProvider.notifier).add(entry('apple'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LearningCartScreen()),
      ),
    );

    expect(find.text('apple'), findsOneWidget);
    expect(find.text('Keranjang Pelajari masih kosong.'), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('apple'), findsNothing);
    expect(find.text('Keranjang Pelajari masih kosong.'), findsOneWidget);
    expect(container.read(learningCartProvider), isEmpty);
  });

  testWidgets('the "Belajar Kata Ini dengan Cerita" CTA is disabled (Milestone 7 not built yet)', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(learningCartProvider.notifier).add(entry('apple'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LearningCartScreen()),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
