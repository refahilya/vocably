import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/learning_session.dart';
import 'package:vocably/providers/ai_worker_providers.dart';
import 'package:vocably/providers/history_providers.dart';
import 'package:vocably/providers/learning_session_controller.dart';
import 'package:vocably/screens/student/learning_flow/cloze_test_screen.dart';
import 'package:vocably/screens/student/learning_flow/cowrite_screen.dart';
import 'package:vocably/services/ai_worker_service.dart';
import 'package:vocably/services/learning_progress_service.dart';
import 'package:vocably/services/learning_session_service.dart';

class _FakeAiWorkerService extends AiWorkerService {
  @override
  Future<GenerateStoryResult> generateStory({
    required List<String> targetWords,
    required String prompt,
  }) async {
    return GenerateStoryResult(
      story: 'I [[run|ran]] and bought a [[souvenir|souvenir]].',
      translation: 'T',
    );
  }
}

class _FakeLearningSessionService extends LearningSessionService {
  final recordClozeResultCalls = <Map<String, dynamic>>[];

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
  Future<void> advanceToClozeTest(String sessionId) async {}

  @override
  Future<void> recordClozeResult({
    required String sessionId,
    required Map<String, bool> clozeTestResult,
  }) async {
    recordClozeResultCalls.add({'sessionId': sessionId, 'clozeTestResult': clozeTestResult});
  }
}

class _FakeLearningProgressService extends LearningProgressService {
  bool throwOnRecordClozeCompletion = false;

  @override
  Future<void> recordClozeCompletion({
    required String studentId,
    required List<String> wordIds,
    required String sessionId,
  }) async {
    if (throwOnRecordClozeCompletion) {
      throw Exception('permission-denied (simulated)');
    }
  }
}

Future<ProviderContainer> _pumpClozeTest(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      aiWorkerServiceProvider.overrideWithValue(_FakeAiWorkerService()),
      learningSessionServiceProvider.overrideWithValue(_FakeLearningSessionService()),
      learningProgressServiceProvider.overrideWithValue(_FakeLearningProgressService()),
    ],
  );
  final controller = container.read(learningFlowControllerProvider.notifier);
  controller.startFlow(
    studentId: 'student-1',
    wordIds: ['run', 'souvenir'],
    sourceType: LearningSessionSourceType.targetGuru,
  );
  await controller.generateStory(prompt: 'judul');
  await controller.advanceToClozeTest();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ClozeTestScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('renders one dropdown per target word, Submit disabled until all answered', (
    tester,
  ) async {
    await _pumpClozeTest(tester);

    expect(find.byType(DropdownButton<String>), findsNWidgets(2));
    final submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit'));
    expect(submit.onPressed, isNull);
  });

  testWidgets('answering every blank enables Submit; submitting reveals grading + Selanjutnya', (
    tester,
  ) async {
    await _pumpClozeTest(tester);

    final dropdowns = find.byType(DropdownButton<String>);
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('run').last);
    await tester.pumpAndSettle();

    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    // Wrong on purpose — pick "run" for the "souvenir" blank too.
    await tester.tap(find.text('run').last);
    await tester.pumpAndSettle();

    final submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit'));
    expect(submit.onPressed, isNotNull);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Submit'), findsNothing);
    expect(find.text('Selanjutnya →'), findsOneWidget);
    expect(
      find.text('Ada jawaban yang salah. Jawaban yang benar ditandai hijau.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping Selanjutnya after Submit writes the result and opens Fase 3', (
    tester,
  ) async {
    final container = await _pumpClozeTest(tester);

    final dropdowns = find.byType(DropdownButton<String>);
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('run').last);
    await tester.pumpAndSettle();

    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('souvenir').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selanjutnya →'));
    await tester.pumpAndSettle();

    final sessionService =
        container.read(learningSessionServiceProvider) as _FakeLearningSessionService;
    expect(sessionService.recordClozeResultCalls.single['clozeTestResult'], {
      'run': true,
      'souvenir': true,
    });
    expect(find.byType(CowriteScreen), findsOneWidget);
  });

  testWidgets(
    'Stage 5: an answer can be changed before Submit, but is locked after Submit — '
    'attempting to change it has no effect, grading stays stable, and Selanjutnya '
    'still proceeds normally',
    (tester) async {
      final container = await _pumpClozeTest(tester);
      final dropdowns = find.byType(DropdownButton<String>);

      // Before Submit: answering, then CHANGING an answer, both work.
      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('souvenir').last); // wrong on purpose, changed below
      await tester.pumpAndSettle();
      expect(
        container.read(learningFlowControllerProvider).clozeAnswers['run'],
        'souvenir',
      );

      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('run').last);
      await tester.pumpAndSettle();
      expect(container.read(learningFlowControllerProvider).clozeAnswers['run'], 'run');

      await tester.tap(dropdowns.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('souvenir').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      final answersAfterSubmit = Map.of(
        container.read(learningFlowControllerProvider).clozeAnswers,
      );
      expect(answersAfterSubmit, {'run': 'run', 'souvenir': 'souvenir'});
      expect(find.text('Selanjutnya →'), findsOneWidget);

      // After Submit: the exact same interaction that changed an answer
      // moments ago must now do nothing at all — the dropdown is disabled,
      // so no menu opens and there is no option to tap into.
      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();
      expect(
        container.read(learningFlowControllerProvider).clozeAnswers,
        answersAfterSubmit,
      );
      // The grading result — entirely derived from clozeAnswers — is
      // therefore unchanged too, so the stepper/result UI stays intact.
      expect(find.text('Selanjutnya →'), findsOneWidget);
      expect(
        find.text('Ada jawaban yang salah. Jawaban yang benar ditandai hijau.'),
        findsNothing, // both answers are correct, so this banner never shows
      );

      // "Selanjutnya" still proceeds normally when the save succeeds.
      await tester.tap(find.text('Selanjutnya →'));
      await tester.pumpAndSettle();
      expect(find.byType(CowriteScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Stage 3: a failed write on Selanjutnya stays on Cloze Test, shows an error, '
    'and does NOT open Fase 3',
    (tester) async {
      final container = await _pumpClozeTest(tester);
      (container.read(learningProgressServiceProvider) as _FakeLearningProgressService)
          .throwOnRecordClozeCompletion = true;

      final dropdowns = find.byType(DropdownButton<String>);
      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('run').last);
      await tester.pumpAndSettle();

      await tester.tap(dropdowns.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('souvenir').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selanjutnya →'));
      await tester.pumpAndSettle();

      expect(find.byType(CowriteScreen), findsNothing);
      expect(find.byType(ClozeTestScreen), findsOneWidget);
      expect(find.text('Gagal menyimpan hasil Cloze Test. Coba lagi.'), findsOneWidget);
      // Still retryable — the button is still there, unchanged.
      expect(find.text('Selanjutnya →'), findsOneWidget);
    },
  );
}
