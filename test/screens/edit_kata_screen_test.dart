import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/topic.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/providers/vocab_management_providers.dart';
import 'package:vocably/screens/teacher/vocab_management/edit_kata_screen.dart';
import 'package:vocably/services/topics_service.dart';
import 'package:vocably/services/vocab_bundle_service.dart';
import 'package:vocably/services/vocab_word_service.dart';
import 'package:vocably/utils/role.dart';

class _FakeVocabWordService extends VocabWordService {
  String? updatedWord;
  List<String>? updatedTopics;
  bool shouldFail = false;

  @override
  Future<void> updateTopics({
    required String normalizedWord,
    required List<String> topics,
  }) async {
    if (shouldFail) throw Exception('simulated Firestore failure');
    updatedWord = normalizedWord;
    updatedTopics = topics;
  }
}

class _FakeTopicsService extends TopicsService {
  List<Topic> topics = [
    Topic(name: 'Buah', createdBy: 'teacher-1', createdAt: DateTime(2026, 1, 1)),
    Topic(name: 'Makanan', createdBy: 'teacher-1', createdAt: DateTime(2026, 1, 1)),
  ];

  @override
  Future<List<Topic>> fetchAll() async => topics;

  @override
  Future<Topic> createOrGetTopic({required String name, required String teacherId}) async {
    final topic = Topic(name: name, createdBy: teacherId, createdAt: DateTime.now());
    topics = [...topics, topic];
    return topic;
  }
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
      VocabBundleEntry(
        word: 'banana',
        meanings: const [VocabMeaning(pos: 'noun', translation: 'pisang')],
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
  required _FakeVocabWordService vocabService,
  required _FakeTopicsService topicsService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vocabWordServiceProvider.overrideWithValue(vocabService),
        topicsServiceProvider.overrideWithValue(topicsService),
        vocabBundleServiceProvider.overrideWithValue(_FakeVocabBundleService()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EditKataScreen(profile: _teacherProfile),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('EditKataScreen', () {
    testWidgets('renders words and allows searching', (tester) async {
      final vocabService = _FakeVocabWordService();
      final topicsService = _FakeTopicsService();

      await _pumpScreen(tester, vocabService: vocabService, topicsService: topicsService);

      expect(find.text('apple'), findsOneWidget);
      expect(find.text('banana'), findsOneWidget);

      // Search for 'ban'
      await tester.enterText(find.byType(TextField).first, 'ban');
      await tester.pumpAndSettle();

      expect(find.text('banana'), findsOneWidget);
      expect(find.text('apple'), findsNothing);
    });

    testWidgets('opening edit modal displays read-only info and handles topic updates', (
      tester,
    ) async {
      final vocabService = _FakeVocabWordService();
      final topicsService = _FakeTopicsService();

      await _pumpScreen(tester, vocabService: vocabService, topicsService: topicsService);

      // Tap on 'apple' row
      await tester.tap(find.text('apple'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Topik Kata'), findsOneWidget);
      expect(find.text('apel'), findsOneWidget);
      expect(find.text('A1'), findsWidgets);

      // Initial state: topics unchanged -> Save button disabled
      final saveButtonFinder = find.widgetWithText(FilledButton, 'Simpan Perubahan Topik');
      expect(tester.widget<FilledButton>(saveButtonFinder).onPressed, isNull);

      // Select 'Makanan' chip
      await tester.tap(find.widgetWithText(FilterChip, 'Makanan'));
      await tester.pumpAndSettle();

      // Save button should now be enabled
      expect(tester.widget<FilledButton>(saveButtonFinder).onPressed, isNotNull);

      // Tap Save
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(vocabService.updatedWord, 'apple');
      expect(vocabService.updatedTopics, ['Buah', 'Makanan']);
      expect(find.textContaining('berhasil diperbarui'), findsOneWidget);
    });

    testWidgets('adding a new topic inline adds it to available topics', (tester) async {
      final vocabService = _FakeVocabWordService();
      final topicsService = _FakeTopicsService();

      await _pumpScreen(tester, vocabService: vocabService, topicsService: topicsService);

      await tester.tap(find.text('apple'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Tambah topik baru'), 'Camilan');
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ Tambah'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, 'Camilan'), findsOneWidget);
    });
  });
}
