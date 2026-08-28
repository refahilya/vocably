import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/topic.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/ai_worker_providers.dart';
import 'package:vocably/providers/vocab_management_providers.dart';
import 'package:vocably/screens/teacher/vocab_management/tambah_kosakata_screen.dart';
import 'package:vocably/services/ai_worker_service.dart';
import 'package:vocably/services/topics_service.dart';
import 'package:vocably/services/vocab_word_service.dart';
import 'package:vocably/utils/role.dart';

class _FakeVocabWordService extends VocabWordService {
  VocabWord? existing;
  bool shouldFailCreate = false;
  bool shouldFailAppend = false;
  final List<String> createdWords = [];
  final List<String> appendedTo = [];

  @override
  Future<VocabWord?> findByWord(String normalizedWord) async => existing;

  @override
  Future<void> createWord({
    required String word,
    required List<VocabMeaning> meanings,
    required String cefrLevel,
    required List<String> topics,
    required String teacherId,
  }) async {
    if (shouldFailCreate) throw Exception('simulated Firestore failure');
    createdWords.add(word);
  }

  @override
  Future<void> appendMeaning({
    required String normalizedWord,
    required VocabMeaning newMeaning,
  }) async {
    if (shouldFailAppend) throw Exception('simulated Firestore failure');
    appendedTo.add(normalizedWord);
  }
}

class _FakeTopicsService extends TopicsService {
  List<Topic> topics = [];

  @override
  Future<List<Topic>> fetchAll() async => topics;

  @override
  Future<Topic> createOrGetTopic({required String name, required String teacherId}) async {
    final topic = Topic(name: name, createdBy: teacherId, createdAt: DateTime.now());
    topics = [...topics, topic];
    return topic;
  }
}

class _FakeAiWorkerService extends AiWorkerService {
  @override
  Future<String> translate({required String word, required String pos}) async {
    return 'terjemahan-$pos';
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
  required _FakeVocabWordService vocabWordService,
  required _FakeTopicsService topicsService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vocabWordServiceProvider.overrideWithValue(vocabWordService),
        topicsServiceProvider.overrideWithValue(topicsService),
        aiWorkerServiceProvider.overrideWithValue(_FakeAiWorkerService()),
      ],
      child: MaterialApp(home: Scaffold(body: TambahKosakataScreen(profile: _teacherProfile))),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types [word] into the word field, then unfocuses it — mirroring how a
/// real user tabbing/clicking away triggers the duplicate check
/// (`SPEC.md` §4.1: "dicek saat field kehilangan fokus").
Future<void> _enterWordAndBlur(WidgetTester tester, String word) async {
  await tester.enterText(find.widgetWithText(TextField, 'Kata (Bahasa Inggris)'), word);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  group('TambahKosakataScreen — new word', () {
    testWidgets('renders the empty form with one meaning row and a disabled submit', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        vocabWordService: _FakeVocabWordService(),
        topicsService: _FakeTopicsService(),
      );

      expect(find.text('Tambah Kosakata'), findsOneWidget);
      expect(find.text('Simpan Kata'), findsOneWidget);
      expect(find.text('Makna utama'), findsOneWidget);

      final submitButton = tester.widget<FilledButton>(
        find.ancestor(of: find.text('Simpan Kata'), matching: find.byType(FilledButton)),
      );
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('no duplicate notice appears for a genuinely new word', (tester) async {
      final vocabWordService = _FakeVocabWordService();
      await _pumpScreen(
        tester,
        vocabWordService: vocabWordService,
        topicsService: _FakeTopicsService(),
      );

      await _enterWordAndBlur(tester, 'banana');

      expect(find.text('Kata ini sudah ada di bank kosakata.'), findsNothing);
      expect(find.text('Level CEFR'), findsOneWidget);
    });

    testWidgets(
      'generating a translation then submitting creates the word via VocabWordService',
      (tester) async {
        final vocabWordService = _FakeVocabWordService();
        await _pumpScreen(
          tester,
          vocabWordService: vocabWordService,
          topicsService: _FakeTopicsService(),
        );

        await _enterWordAndBlur(tester, 'banana');

        await tester.enterText(find.widgetWithText(TextField, 'Part of speech (POS)'), 'noun');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Buat Terjemahan').first);
        await tester.pumpAndSettle();

        expect(find.text('terjemahan-noun'), findsOneWidget);

        final submitButton = tester.widget<FilledButton>(
          find.ancestor(of: find.text('Simpan Kata'), matching: find.byType(FilledButton)),
        );
        expect(submitButton.onPressed, isNotNull);

        await tester.tap(find.text('Simpan Kata'));
        await tester.pumpAndSettle();

        expect(vocabWordService.createdWords, ['banana']);
        expect(find.text('Kata baru berhasil ditambahkan.'), findsOneWidget);
      },
    );

    testWidgets('shows an inline error (not a raw exception) when createWord fails', (
      tester,
    ) async {
      final vocabWordService = _FakeVocabWordService()..shouldFailCreate = true;
      await _pumpScreen(
        tester,
        vocabWordService: vocabWordService,
        topicsService: _FakeTopicsService(),
      );

      await _enterWordAndBlur(tester, 'banana');
      await tester.enterText(find.widgetWithText(TextField, 'Part of speech (POS)'), 'noun');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat Terjemahan').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan Kata'));
      await tester.pumpAndSettle();

      expect(
        find.text('Gagal menyimpan kata. Periksa koneksi lalu coba lagi.'),
        findsOneWidget,
      );
      expect(vocabWordService.createdWords, isEmpty);
    });

    testWidgets('adding a new meaning row shows a second (non-primary) meaning block', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        vocabWordService: _FakeVocabWordService(),
        topicsService: _FakeTopicsService(),
      );

      await tester.tap(find.text('+ Tambah makna lain'));
      await tester.pumpAndSettle();

      expect(find.text('Makna utama'), findsOneWidget);
      expect(find.text('Makna 2'), findsOneWidget);
    });
  });

  group('TambahKosakataScreen — duplicate word', () {
    testWidgets('shows the duplicate notice and offers "Tambah makna baru ke kata ini"', (
      tester,
    ) async {
      final vocabWordService = _FakeVocabWordService()
        ..existing = VocabWord(
          word: 'run',
          meanings: [const VocabMeaning(pos: 'verb', translation: 'berlari')],
          cefrLevel: 'A1',
          topics: const ['General'],
          source: 'oxford3000',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
      await _pumpScreen(
        tester,
        vocabWordService: vocabWordService,
        topicsService: _FakeTopicsService(),
      );

      await _enterWordAndBlur(tester, 'run');

      expect(find.text('Kata ini sudah ada di bank kosakata.'), findsOneWidget);
      expect(find.text('Tambah makna baru ke kata ini'), findsOneWidget);
      // The full new-word form (level/topics) shouldn't show for a
      // duplicate — only the compact append-meaning flow should.
      expect(find.text('Level CEFR'), findsNothing);
    });

    testWidgets('appending a new meaning calls VocabWordService.appendMeaning', (tester) async {
      final vocabWordService = _FakeVocabWordService()
        ..existing = VocabWord(
          word: 'run',
          meanings: [const VocabMeaning(pos: 'verb', translation: 'berlari')],
          cefrLevel: 'A1',
          topics: const ['General'],
          source: 'oxford3000',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
      await _pumpScreen(
        tester,
        vocabWordService: vocabWordService,
        topicsService: _FakeTopicsService(),
      );

      await _enterWordAndBlur(tester, 'run');
      await tester.tap(find.text('Tambah makna baru ke kata ini'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Part of speech (POS)'), 'noun');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat Terjemahan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan makna baru'));
      await tester.pumpAndSettle();

      expect(vocabWordService.appendedTo, ['run']);
      expect(find.text('Makna baru berhasil ditambahkan.'), findsOneWidget);
    });
  });
}
