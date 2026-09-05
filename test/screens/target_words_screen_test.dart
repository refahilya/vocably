import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/target_word_set.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/dashboard_providers.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/screens/teacher/target_words/set_target_word_screen.dart';
import 'package:vocably/screens/teacher/target_words/target_words_screen.dart';
import 'package:vocably/services/target_word_set_service.dart';
import 'package:vocably/services/vocab_bundle_service.dart';
import 'package:vocably/utils/role.dart';
import 'package:vocably/utils/target_word_constants.dart';

class _FakeTargetWordSetService extends TargetWordSetService {
  List<TargetWordSet> stubSets = [];

  @override
  Future<List<TargetWordSet>> fetchForTeacher(String teacherId) async =>
      stubSets;
}

class _FakeVocabBundleService extends VocabBundleService {
  @override
  Future<List<VocabBundleEntry>> loadLevelWithDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async {
    return [
      VocabBundleEntry(
        word: 'apple',
        meanings: const [VocabMeaning(pos: 'noun', translation: 'apel')],
        cefrLevel: 'A1',
        topics: const ['Buah'],
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
  required _FakeTargetWordSetService service,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        targetWordSetServiceProvider.overrideWithValue(service),
        vocabBundleServiceProvider.overrideWithValue(_FakeVocabBundleService()),
      ],
      child: MaterialApp(
        home: Scaffold(body: TargetWordsScreen(profile: _teacherProfile)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TargetWordsScreen', () {
    testWidgets('shows empty state when no target sets exist', (tester) async {
      await _pumpScreen(tester, service: _FakeTargetWordSetService());

      expect(find.text('Target Kata'), findsOneWidget);
      expect(find.text('Belum ada target kata yang dibuat.'), findsOneWidget);
      expect(find.text('Set Target Baru'), findsOneWidget);
    });

    testWidgets(
      'renders list of target set cards with active and no-end-date badges',
      (tester) async {
        final now = DateTime.now();
        final service = _FakeTargetWordSetService()
          ..stubSets = [
            TargetWordSet(
              id: 'set-active',
              teacherId: 'teacher-1',
              wordIds: const ['apple', 'banana'],
              cefrLevel: 'A1',
              startAt: now.subtract(const Duration(days: 1)),
              endAt: kNoEndDate.toDate(),
              targetStudentIds: const ['__all__'],
              createdAt: now,
            ),
            TargetWordSet(
              id: 'set-expired',
              teacherId: 'teacher-1',
              wordIds: const ['souvenir'],
              cefrLevel: 'B1',
              startAt: now.subtract(const Duration(days: 10)),
              endAt: now.subtract(const Duration(days: 2)),
              targetStudentIds: const ['__all__'],
              createdAt: now.subtract(const Duration(days: 10)),
            ),
          ];

        await _pumpScreen(tester, service: service);

        expect(find.text('2 kata'), findsOneWidget);
        expect(find.text('1 kata'), findsOneWidget);
        expect(find.text('Aktif'), findsOneWidget);
        expect(find.text('Selesai'), findsOneWidget);
        expect(find.text('apple'), findsOneWidget);
        expect(find.text('banana'), findsOneWidget);
        expect(find.text('souvenir'), findsOneWidget);
        expect(find.textContaining('Tanpa batas akhir'), findsOneWidget);
      },
    );

    testWidgets('tapping Set Target Baru navigates to SetTargetWordScreen', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeTargetWordSetService());

      await tester.tap(find.text('Set Target Baru'));
      await tester.pumpAndSettle();

      expect(find.byType(SetTargetWordScreen), findsOneWidget);
    });
  });
}
