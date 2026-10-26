import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/research_attempt.dart';
import 'package:vocably/models/research_attempt_plan.dart';
import 'package:vocably/models/research_instrument.dart';
import 'package:vocably/providers/research_assessment_providers.dart';
import 'package:vocably/screens/student/research_assessment/research_assessment_screen.dart';
import 'package:vocably/screens/student/research_assessment/research_instructions.dart';
import 'package:vocably/services/research_assessment_service.dart';
import 'package:vocably/utils/research_attempt_planner.dart';

import '../support/fake_research_assessment_service.dart';

const _uid = 'stu1';

void main() {
  late ResearchInstrument instrument;
  late FakeResearchAssessmentService server;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    instrument = ResearchInstrument.fromJson(
      jsonDecode(
        await rootBundle.loadString('assets/research/instrument_v1.json'),
      ),
      expectedVersion: 'v1',
    );
  });

  setUp(() {
    server = FakeResearchAssessmentService(participant: participantFor());
  });

  Future<void> pump(
    WidgetTester tester, {
    ResearchStage stage = ResearchStage.preTest,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        retry: (_, _) => null,
        overrides: [
          researchAssessmentServiceProvider.overrideWithValue(server),
          researchAssessmentRandomProvider.overrideWithValue(Random(3)),
          researchInstrumentProvider(
            'v1',
          ).overrideWith((ref) async => instrument),
        ],
        child: MaterialApp(
          home: ResearchAssessmentScreen(uid: _uid, stage: stage),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ResearchAttemptRecord stored() =>
      server.attempts[ResearchAttemptRecord.idFor(
        _uid,
        ResearchStage.preTest,
        1,
      )]!;

  ResearchAttemptPlan seed({List<int> answered = const []}) {
    final plan = planResearchAttempt(
      instrument: instrument,
      assignment: server.participant!.assignment,
      random: Random(77),
    );
    server.putAttempt(
      ResearchAttemptRecord(
        attemptId: ResearchAttemptRecord.idFor(_uid, ResearchStage.preTest, 1),
        studentId: _uid,
        stage: ResearchStage.preTest,
        attemptNumber: 1,
        band: plan.band,
        instrumentVersion: plan.instrumentVersion,
        itemOrder: plan.itemOrder,
        optionOrder: plan.optionOrder,
        responses: {
          for (final i in answered)
            plan.items[i].itemId: ResearchResponse.forPlannedItem(
              plan.items[i],
              'dont_know',
            ),
        },
        status: ResearchAttemptStatus.inProgress,
      ),
    );
    return plan;
  }

  FilledButton button(WidgetTester tester, String label) => tester.widget(
    find.ancestor(of: find.text(label), matching: find.byType(FilledButton)),
  );

  Future<void> choose(WidgetTester tester, String optionId) async {
    await tester.ensureVisible(
      find.byKey(ValueKey('research-option-$optionId')),
    );
    await tester.tap(find.byKey(ValueKey('research-option-$optionId')));
    await tester.pump();
  }

  Future<void> next(WidgetTester tester, [String label = 'Lanjut']) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// Every option tile's text, top to bottom.
  List<String> shownOptionTexts(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith(
                  'research-option-',
                ),
          ),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data!)
      .toList();

  testWidgets(
    'shows the instrument instructions and example verbatim, then starts',
    (tester) async {
      await pump(tester);
      for (final text in [
        kResearchInstructionsTitle,
        kResearchInstructionsParagraph1,
        kResearchInstructionsParagraph2,
        kResearchExampleHeading,
        'a) Buku',
        'e) Saya tidak tahu kata ini',
        kResearchExampleExplanation,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(server.attempts, isEmpty);

      await next(tester, 'Mulai');
      expect(server.attempts, hasLength(1));
      final first = stored().itemOrder.first;
      final item = instrument.items.firstWhere((i) => i.id == first);
      expect(
        find.text('${item.word} (${item.posLabel})', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'one item per screen: stored option order, "tidak tahu" last, Lanjut needs a choice',
    (tester) async {
      await pump(tester);
      await next(tester, 'Mulai');

      final plan = ResearchAttemptPlan.fromOrder(
        instrument: instrument,
        assignment: server.participant!.assignment,
        itemOrder: stored().itemOrder,
        optionOrder: stored().optionOrder,
      );
      final item = plan.items.first;
      expect(shownOptionTexts(tester), [
        for (var i = 0; i < 4; i++)
          '${'abcd'[i]}) ${item.substantiveOptions[i].text}',
        'e) Saya tidak tahu kata ini',
      ]);
      expect(button(tester, 'Lanjut').onPressed, isNull);

      await choose(tester, item.substantiveOptions[1].id);
      expect(button(tester, 'Lanjut').onPressed, isNotNull);
      await next(tester);

      expect(stored().responses[item.itemId]!.displayPosition, 2);
      expect(
        find.byKey(ValueKey('research-item-${plan.items[1].itemId}')),
        findsOneWidget,
      );
      expect(
        button(tester, 'Lanjut').onPressed,
        isNull,
        reason: 'fresh item, no choice',
      );
    },
  );

  testWidgets(
    'does not advance until the save is confirmed; options are locked meanwhile',
    (tester) async {
      await pump(tester);
      await next(tester, 'Mulai');
      final firstId = stored().itemOrder.first;

      server.holdWrites = Completer<void>();
      await choose(tester, 'dont_know');
      await tester.tap(find.text('Lanjut'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(ValueKey('research-item-$firstId')), findsOneWidget);
      expect(stored().responses, isEmpty);

      server.holdWrites!.complete();
      server.holdWrites = null;
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('research-item-$firstId')), findsNothing);
      expect(stored().responses.keys, [firstId]);
    },
  );

  testWidgets(
    'a failed save shows a retry message, keeps the choice, and the retry saves once',
    (tester) async {
      await pump(tester);
      await next(tester, 'Mulai');
      final firstId = stored().itemOrder.first;

      server.writeFaults.add(
        const FakeFaultSpec(
          FakeFault.failBefore,
          ResearchFailureKind.unavailable,
        ),
      );
      await choose(tester, 'dont_know');
      await next(tester);
      expect(find.textContaining('Jawaban belum tersimpan'), findsOneWidget);
      expect(find.byKey(ValueKey('research-item-$firstId')), findsOneWidget);
      expect(
        button(tester, 'Lanjut').onPressed,
        isNotNull,
        reason: 'choice kept',
      );
      // The submitted choice is locked: tapping another option does nothing.
      final other = stored().optionOrder[firstId]!.first;
      await choose(tester, other);

      await next(tester);
      expect(find.textContaining('Jawaban belum tersimpan'), findsNothing);
      expect(stored().responses, hasLength(1));
      expect(stored().responses[firstId]!.optionId, 'dont_know');
    },
  );

  testWidgets(
    'resumes after a restart at the first unanswered item, in the stored order',
    (tester) async {
      final plan = seed(answered: [0, 1, 2, 5]);
      await pump(tester);
      expect(find.text(kResearchInstructionsParagraph1), findsOneWidget);
      await next(tester, 'Lanjutkan');

      expect(
        find.byKey(ValueKey('research-item-${plan.items[3].itemId}')),
        findsOneWidget,
      );
      expect(server.createCalls, 0);
      expect(find.text('Sebelumnya'), findsNothing);
      expect(find.text('Kembali'), findsNothing);
    },
  );

  testWidgets(
    'finishing all 20 completes the attempt and shows no score or feedback',
    (tester) async {
      seed(answered: List.generate(19, (i) => i));
      await pump(tester);
      await next(tester, 'Lanjutkan');
      expect(find.text('Kirim'), findsOneWidget, reason: 'last item');
      await choose(tester, 'dont_know');
      await next(tester, 'Kirim');

      expect(find.text('Pre-Test selesai'), findsOneWidget);
      expect(stored().status, ResearchAttemptStatus.completed);
      for (final word in [
        'Skor',
        'skor',
        'Benar',
        'benar',
        'Salah',
        'salah',
        '/20',
        'Nilai',
      ]) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
    },
  );

  testWidgets('a failed completion can be retried', (tester) async {
    seed(answered: List.generate(19, (i) => i));
    server.writeFaults.addAll([
      null,
      const FakeFaultSpec(
        FakeFault.failBefore,
        ResearchFailureKind.unavailable,
      ),
    ]);
    await pump(tester);
    await next(tester, 'Lanjutkan');
    await choose(tester, 'dont_know');
    await next(tester, 'Kirim');
    expect(find.text('Penyelesaian tes belum tersimpan'), findsOneWidget);

    await next(tester, 'Coba lagi');
    expect(find.text('Pre-Test selesai'), findsOneWidget);
  });

  testWidgets(
    'load failure, not enrolled, not authorized, locked, voided and invalid states',
    (tester) async {
      server.readFaults.add(ResearchFailureKind.unavailable);
      await pump(tester);
      expect(find.text('Gagal memuat tes'), findsOneWidget);
      await next(tester, 'Coba lagi');
      expect(find.text('Mulai'), findsOneWidget);

      server = FakeResearchAssessmentService();
      await pump(tester);
      expect(find.text('Belum terdaftar'), findsOneWidget);

      server = FakeResearchAssessmentService(
        participant: participantFor(preTest: 0),
      );
      await pump(tester);
      expect(
        find.text('Pre-Test belum dibuka. Tunggu arahan dari peneliti.'),
        findsOneWidget,
      );

      server = FakeResearchAssessmentService(
        participant: participantFor(postTest: 1),
      );
      await pump(tester, stage: ResearchStage.postTest);
      expect(find.textContaining('setelah Pre-Test selesai'), findsOneWidget);

      server = FakeResearchAssessmentService(participant: participantFor());
      seed();
      server.putAttempt(
        server.copyAttempt(stored(), status: ResearchAttemptStatus.voided),
      );
      await pump(tester);
      expect(find.text('Tes dibatalkan'), findsOneWidget);

      server = FakeResearchAssessmentService(participant: participantFor());
      seed();
      server.putAttempt(server.copyAttempt(stored(), band: 'C1'));
      await pump(tester);
      expect(find.text('Tes tidak dapat dilanjutkan'), findsOneWidget);
    },
  );

  testWidgets(
    'a start that cannot reach the server says so and can be retried',
    (tester) async {
      server.writeFaults.add(
        const FakeFaultSpec(
          FakeFault.failBefore,
          ResearchFailureKind.unavailable,
        ),
      );
      await pump(tester);
      await next(tester, 'Mulai');
      expect(find.textContaining('Tes belum dapat dimulai'), findsOneWidget);
      await next(tester, 'Mulai');
      expect(server.attempts, hasLength(1));
      expect(find.text('Lanjut'), findsOneWidget);
    },
  );
}
