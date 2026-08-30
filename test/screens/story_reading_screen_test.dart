import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/learning_session.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/providers/ai_worker_providers.dart';
import 'package:vocably/providers/history_providers.dart';
import 'package:vocably/providers/learning_session_controller.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/screens/student/learning_flow/cloze_test_screen.dart';
import 'package:vocably/screens/student/learning_flow/story_reading_screen.dart';
import 'package:vocably/services/ai_worker_service.dart';
import 'package:vocably/services/learning_session_service.dart';
import 'package:vocably/services/vocab_bundle_service.dart';

class _FakeAiWorkerService extends AiWorkerService {
  GenerateStoryResult Function(String prompt)? handler;

  @override
  Future<GenerateStoryResult> generateStory({
    required List<String> targetWords,
    required String prompt,
  }) async {
    final h = handler;
    if (h == null) throw const AiWorkerException('simulated failure');
    return h(prompt);
  }
}

class _FakeLearningSessionService extends LearningSessionService {
  bool throwOnAdvanceToClozeTest = false;
  int overwriteStoryCallCount = 0;
  int advanceToClozeTestCallCount = 0;

  @override
  Future<String> createSession({
    required String studentId,
    required List<String> wordIds,
    required String sourceType,
    required String storyTitle,
    required String storyContent,
    required String? storyTranslation,
  }) async => 'session-1';

  @override
  Future<void> overwriteStory({
    required String sessionId,
    required String storyTitle,
    required String storyContent,
    required String? storyTranslation,
  }) async {
    overwriteStoryCallCount++;
  }

  @override
  Future<void> advanceToClozeTest(String sessionId) async {
    advanceToClozeTestCallCount++;
    if (throwOnAdvanceToClozeTest) {
      throw Exception('permission-denied (simulated)');
    }
  }
}

class _FakeVocabBundleService extends VocabBundleService {
  Map<String, List<VocabBundleEntry>> byLevel = {};

  @override
  Future<List<VocabBundleEntry>> loadLevelWithDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async {
    return byLevel[cefrLevel] ?? const [];
  }
}

Future<ProviderContainer> _pumpStoryReading(
  WidgetTester tester, {
  _FakeAiWorkerService? aiWorkerService,
  _FakeVocabBundleService? bundleService,
}) async {
  final container = ProviderContainer(
    overrides: [
      aiWorkerServiceProvider.overrideWithValue(aiWorkerService ?? _FakeAiWorkerService()),
      learningSessionServiceProvider.overrideWithValue(_FakeLearningSessionService()),
      vocabBundleServiceProvider.overrideWithValue(bundleService ?? _FakeVocabBundleService()),
    ],
  );
  container
      .read(learningFlowControllerProvider.notifier)
      .startFlow(
        studentId: 'student-1',
        wordIds: ['run'],
        sourceType: LearningSessionSourceType.targetGuru,
      );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: StoryReadingScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('generating a story shows the highlighted story and enables Selanjutnya', (
    tester,
  ) async {
    final ai = _FakeAiWorkerService()
      ..handler = (prompt) =>
          GenerateStoryResult(story: 'I [[run|ran]] today.', translation: 'Saya berlari hari ini.');
    await _pumpStoryReading(tester, aiWorkerService: ai);

    await tester.enterText(find.byType(TextField), 'liburan');
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(find.textContaining('I ran today.', findRichText: true), findsOneWidget);
    final next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Selanjutnya →'));
    expect(next.onPressed, isNotNull);

    await tester.tap(find.text('Selanjutnya →'));
    await tester.pumpAndSettle();

    expect(find.byType(ClozeTestScreen), findsOneWidget);
  });

  testWidgets('a failed generate shows a friendly error with a retry button', (tester) async {
    final ai = _FakeAiWorkerService(); // handler null -> always throws
    await _pumpStoryReading(tester, aiWorkerService: ai);

    await tester.enterText(find.byType(TextField), 'liburan');
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal membuat cerita. Periksa koneksi lalu coba lagi.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);

    final next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Selanjutnya →'));
    expect(next.onPressed, isNull);
  });

  testWidgets('regenerating overwrites the displayed story', (tester) async {
    var callCount = 0;
    final ai = _FakeAiWorkerService()
      ..handler = (prompt) {
        callCount++;
        return GenerateStoryResult(story: 'Story #$callCount [[run|ran]].', translation: 'T');
      };
    await _pumpStoryReading(tester, aiWorkerService: ai);

    await tester.enterText(find.byType(TextField), 'A');
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Story #1', findRichText: true), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'B');
    await tester.tap(find.text('Generate Ulang'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Story #2', findRichText: true), findsOneWidget);
    expect(find.textContaining('Story #1', findRichText: true), findsNothing);
  });

  testWidgets(
    'Stage 6: a failed advanceToClozeTest stays on Reading, shows an error, and does '
    'NOT open Cloze Test',
    (tester) async {
      final ai = _FakeAiWorkerService()
        ..handler = (prompt) =>
            GenerateStoryResult(story: 'I [[run|ran]] today.', translation: 'T');
      final container = await _pumpStoryReading(tester, aiWorkerService: ai);
      (container.read(learningSessionServiceProvider) as _FakeLearningSessionService)
          .throwOnAdvanceToClozeTest = true;

      await tester.enterText(find.byType(TextField), 'liburan');
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Selanjutnya →'));
      await tester.pumpAndSettle();

      expect(find.byType(ClozeTestScreen), findsNothing);
      expect(find.byType(StoryReadingScreen), findsOneWidget);
      expect(find.text('Gagal melanjutkan ke Cloze Test. Coba lagi.'), findsOneWidget);
      // Still retryable — the story and the button are both still there.
      expect(find.textContaining('I ran today.', findRichText: true), findsOneWidget);
      final next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Selanjutnya →'));
      expect(next.onPressed, isNotNull);
    },
  );

  testWidgets(
    'Stage 7: Back from Cloze Test to Reading, then Selanjutnya again navigates '
    'straight to ClozeTestScreen without a second advanceToClozeTest() write',
    (tester) async {
      final ai = _FakeAiWorkerService()
        ..handler = (prompt) =>
            GenerateStoryResult(story: 'I [[run|ran]] today.', translation: 'T');
      final container = await _pumpStoryReading(tester, aiWorkerService: ai);
      final fakeSessionService =
          container.read(learningSessionServiceProvider) as _FakeLearningSessionService;

      await tester.enterText(find.byType(TextField), 'liburan');
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selanjutnya →'));
      await tester.pumpAndSettle();
      expect(find.byType(ClozeTestScreen), findsOneWidget);
      expect(fakeSessionService.advanceToClozeTestCallCount, 1);

      // Simulate the system/AppBar Back button — pure local navigation,
      // does not touch LearningFlowState or Firestore.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(StoryReadingScreen), findsOneWidget);
      expect(find.byType(ClozeTestScreen), findsNothing);

      await tester.tap(find.text('Selanjutnya →'));
      await tester.pumpAndSettle();

      // Navigates straight to ClozeTestScreen again...
      expect(find.byType(ClozeTestScreen), findsOneWidget);
      // ...but the underlying Firestore write was never attempted a
      // second time (the controller's phase-aware no-op handled it).
      expect(fakeSessionService.advanceToClozeTestCallCount, 1);
    },
  );

  testWidgets(
    'Stage 7: Back from Cloze Test to Reading locks Generate/Generate Ulang and '
    'shows the "sudah dikunci" message, without attempting overwriteStory()',
    (tester) async {
      final ai = _FakeAiWorkerService()
        ..handler = (prompt) =>
            GenerateStoryResult(story: 'I [[run|ran]] today.', translation: 'T');
      final container = await _pumpStoryReading(tester, aiWorkerService: ai);
      final fakeSessionService =
          container.read(learningSessionServiceProvider) as _FakeLearningSessionService;

      await tester.enterText(find.byType(TextField), 'liburan');
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selanjutnya →'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Cerita sudah dikunci dan tidak dapat diubah lagi.'), findsOneWidget);
      final generateUlang = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Generate Ulang'),
      );
      expect(generateUlang.onPressed, isNull);

      // Even if something did try to tap it, the button being disabled
      // means no tap can land — confirm no overwriteStory() call happened.
      expect(fakeSessionService.overwriteStoryCallCount, 0);
    },
  );
}
