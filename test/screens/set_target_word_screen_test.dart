import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/dashboard_providers.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/screens/teacher/target_words/set_target_word_screen.dart';
import 'package:vocably/services/target_word_set_service.dart';
import 'package:vocably/services/vocab_bundle_service.dart';
import 'package:vocably/utils/role.dart';

class _FakeTargetWordSetService extends TargetWordSetService {
  String? createdTeacherId;
  List<String>? createdWordIds;
  String? createdCefrLevel;
  bool shouldFail = false;

  @override
  Future<String> createTargetWordSet({
    required String teacherId,
    required List<String> wordIds,
    required String cefrLevel,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    if (shouldFail) throw Exception('simulated failure');
    createdTeacherId = teacherId;
    createdWordIds = wordIds;
    createdCefrLevel = cefrLevel;
    return 'new-set-id';
  }
}

class _FakeVocabBundleService extends VocabBundleService {
  @override
  Future<List<VocabBundleEntry>> loadLevelWithDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async {
    if (cefrLevel == 'A1') {
      return [
        VocabBundleEntry(
          word: 'apple',
          meanings: const [VocabMeaning(pos: 'noun', translation: 'apel')],
          cefrLevel: 'A1',
          topics: const ['Buah'],
        ),
        VocabBundleEntry(
          word: 'banana',
          meanings: const [VocabMeaning(pos: 'noun', translation: 'pisang')],
          cefrLevel: 'A1',
          topics: const ['Buah'],
        ),
      ];
    }
    return [
      VocabBundleEntry(
        word: 'souvenir',
        meanings: const [VocabMeaning(pos: 'noun', translation: 'oleh-oleh')],
        cefrLevel: 'B1',
        topics: const ['Perjalanan'],
      ),
    ];
  }
}

final _teacherProfile = AppUser(
  uid: 'teacher-1',
  email: 'guru@example.com',
  name: 'Guru Uji',
  role: Role.guru,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeTargetWordSetService targetService,
  required _FakeVocabBundleService bundleService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        targetWordSetServiceProvider.overrideWithValue(targetService),
        vocabBundleServiceProvider.overrideWithValue(bundleService),
      ],
      child: MaterialApp(
        home: SetTargetWordScreen(profile: _teacherProfile),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SetTargetWordScreen', () {
    testWidgets('submit is disabled when no words are selected', (tester) async {
      final targetService = _FakeTargetWordSetService();
      final bundleService = _FakeVocabBundleService();

      await _pumpScreen(tester, targetService: targetService, bundleService: bundleService);

      expect(find.text('Set Target Baru'), findsOneWidget);
      expect(find.text('0 kata dipilih'), findsOneWidget);

      final submitFinder = find.widgetWithText(FilledButton, 'Simpan Target Kata');
      final submitButton = tester.widget<FilledButton>(submitFinder);
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('selecting words enables submit and saving succeeds', (tester) async {
      final targetService = _FakeTargetWordSetService();
      final bundleService = _FakeVocabBundleService();

      await _pumpScreen(tester, targetService: targetService, bundleService: bundleService);

      // Select 'apple' chip
      await tester.tap(find.widgetWithText(FilterChip, 'apple'));
      await tester.pumpAndSettle();

      expect(find.text('1 kata dipilih'), findsOneWidget);

      // Select 'banana' chip
      await tester.tap(find.widgetWithText(FilterChip, 'banana'));
      await tester.pumpAndSettle();

      expect(find.text('2 kata dipilih'), findsOneWidget);

      // Deselect 'apple'
      await tester.tap(find.widgetWithText(FilterChip, 'apple'));
      await tester.pumpAndSettle();

      expect(find.text('1 kata dipilih'), findsOneWidget);

      // Submit
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan Target Kata'));
      await tester.pumpAndSettle();

      expect(targetService.createdTeacherId, 'teacher-1');
      expect(targetService.createdWordIds, ['banana']);
      expect(targetService.createdCefrLevel, 'A1');
    });

    testWidgets('switching level updates words and resets selection', (tester) async {
      final targetService = _FakeTargetWordSetService();
      final bundleService = _FakeVocabBundleService();

      await _pumpScreen(tester, targetService: targetService, bundleService: bundleService);

      await tester.tap(find.widgetWithText(FilterChip, 'apple'));
      await tester.pumpAndSettle();
      expect(find.text('1 kata dipilih'), findsOneWidget);

      // Switch to B1
      await tester.tap(find.widgetWithText(ChoiceChip, 'B1'));
      await tester.pumpAndSettle();

      expect(find.text('0 kata dipilih'), findsOneWidget);
      expect(find.text('souvenir'), findsOneWidget);
      expect(find.text('apple'), findsNothing);
    });
  });
}
