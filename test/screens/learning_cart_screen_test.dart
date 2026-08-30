import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/providers/auth_providers.dart';
import 'package:vocably/providers/learning_cart_providers.dart';
import 'package:vocably/screens/student/vocab_browser/learning_cart_screen.dart';
import 'package:vocably/utils/role.dart';

final _studentProfile = AppUser(
  uid: 'student-1',
  email: 'siswa@example.com',
  name: 'Siswa Uji',
  role: Role.siswa,
  createdAt: DateTime(2026, 1, 1),
);

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

  testWidgets('the CTA is disabled when the cart is empty', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LearningCartScreen()),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('tapping the CTA starts the flow (sourceType keranjangPelajari) and opens Fase 1', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        currentUserProfileProvider.overrideWith((ref) => Stream.value(_studentProfile)),
      ],
    );
    addTearDown(container.dispose);
    container.read(learningCartProvider.notifier).add(entry('apple'));
    // `Stream.value(...)`'s single event lands on a microtask, not
    // synchronously — subscribe now and let it flow through before the
    // button is tapped, so `currentUserProfileProvider`'s `.value` is
    // actually populated by then (in the real app this is a non-issue:
    // `appAuthStatusProvider` keeps this provider permanently subscribed
    // from the moment the student is signed in, long before this screen
    // ever renders).
    container.listen(currentUserProfileProvider, (_, _) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LearningCartScreen()),
      ),
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);

    await tester.tap(find.text('Belajar Kata Ini dengan Cerita (1 kata)'));
    await tester.pumpAndSettle();

    expect(find.text('Baca Cerita'), findsOneWidget);
  });
}
