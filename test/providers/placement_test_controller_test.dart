import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/placement_attempt.dart';
import 'package:vocably/models/placement_instrument.dart';
import 'package:vocably/models/placement_status.dart';
import 'package:vocably/models/research_participant.dart';
import 'package:vocably/providers/placement_test_providers.dart';
import 'package:vocably/providers/research_assessment_providers.dart';
import 'package:vocably/services/research_assessment_service.dart';

import '../support/fake_placement_service.dart';
import '../support/fake_research_assessment_service.dart' show FakeFault, FakeFaultSpec, openStudy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uid = 'student-1';

  late FakePlacementService service;
  late ProviderContainer container;

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      placementServiceProvider.overrideWithValue(service),
      researchAssessmentRandomProvider.overrideWithValue(Random(7)),
    ],
  );

  PlacementTestController controller() => container.read(placementTestControllerProvider(uid).notifier);
  PlacementTestState state() => container.read(placementTestControllerProvider(uid));

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<PlacementTestState> load() async {
    container.listen(placementTestControllerProvider(uid), (_, _) {});
    state();
    await settle();
    return state();
  }

  /// Answers every item with the synthetic key for band scores [s] (rest E).
  Future<void> answerAll(List<int> s) async {
    await service.loadInstrument();
    final answers = service.answersFor(s);
    final st = state() as PlacementTestAnswering;
    for (var i = 0; i < st.items.length; i++) {
      controller().goTo(i);
      await controller().select(answers[st.items[i].id]!);
    }
    controller().openSummary();
  }

  setUp(() {
    service = FakePlacementService();
    container = makeContainer();
  });
  tearDown(() => container.dispose());

  test('ordinary user: start → answer all 50 → summary → submit → level shown only after the server scored it', () async {
    expect(await load(), isA<PlacementTestReady>().having((s) => s.context, 'context', PlacementContext.learning));
    await controller().start();
    var s = state() as PlacementTestAnswering;
    expect(s.index, 0);
    expect(s.items, hasLength(50));
    await answerAll([10, 9, 7, 3, 0]);
    s = state() as PlacementTestAnswering;
    expect(s.reviewing, isTrue);
    expect(s.unansweredNumbers, isEmpty);
    await controller().submit();
    final result = state() as PlacementTestResult;
    expect(result.justFinished, isTrue);
    expect(result.attempt.result!.resultLevel, 'B1');
    expect(service.userResultLevel, 'B1');
    expect(service.attempts.values.single.status, PlacementAttemptStatus.scored);
  });

  test('answers can be changed before submission; the summary lists unanswered items and submit is refused locally', () async {
    await load();
    await controller().start();
    await controller().select('B');
    await controller().select('E');
    final s = state() as PlacementTestAnswering;
    expect(s.attempt.answers.values.single, 'E');
    controller().openSummary();
    expect((state() as PlacementTestAnswering).unansweredNumbers, hasLength(49));
    await controller().submit();
    expect(service.submitCalls, 0);
  });

  test('a lost save is reported and can be retried; a lost acknowledgement is not an error', () async {
    await load();
    await controller().start();
    service.writeFaults.add(const FakeFaultSpec(FakeFault.failBefore, ResearchFailureKind.unavailable));
    await controller().select('A');
    var s = state() as PlacementTestAnswering;
    expect(s.error, PlacementActionError.network);
    expect(s.attempt.answers, isEmpty);
    await controller().select('A');
    s = state() as PlacementTestAnswering;
    expect(s.error, isNull);
    expect(s.attempt.answers.values.single, 'A');
    controller().next();
    service.writeFaults.add(const FakeFaultSpec(FakeFault.applyThenFail, ResearchFailureKind.timeout));
    await controller().select('C');
    s = state() as PlacementTestAnswering;
    expect(s.error, isNull);
    expect(s.attempt.answers, hasLength(2));
  });

  test('duplicate taps do not create a second attempt or a second save', () async {
    await load();
    service.holdWrites = Completer<void>();
    final first = controller().start();
    final second = controller().start();
    service.holdWrites!.complete();
    service.holdWrites = null;
    await Future.wait([first, second]);
    expect(service.createCalls, 1);
  });

  test('research participant: blocked while the window is closed, then starts the authorized research attempt', () async {
    service.participant = pendingParticipant();
    service.study = openStudy(open: const {});
    expect((await load() as PlacementTestBlocked).reason, PlacementBlock.researchClosed);
    service.study = openStudy(open: const {'placement'});
    await controller().reload();
    expect(state(), isA<PlacementTestReady>().having((s) => s.context, 'context', PlacementContext.research));
    await controller().start();
    expect(service.attempts.keys.single, 'student-1_research_1');
  });

  group('start() after a refused or failed create', () {
    PlacementAttemptRecord ownAttempt(PlacementContext context, int number) => PlacementAttemptRecord(
      id: PlacementAttemptRecord.idFor(uid, context, number),
      studentId: uid,
      context: context,
      attemptNumber: number,
      instrumentVersion: kPlacementInstrumentVersion,
      itemOrder: List.generate(kPlacementItemCount, (i) => 'item-$i'),
      answers: const {},
      status: PlacementAttemptStatus.inProgress,
    );

    test('the fake refuses a get on a missing attempt, as the rules do; the own-attempts query still answers', () async {
      await expectLater(
        service.fetchAttempt('student-1_research_1'),
        throwsA(isA<ResearchServiceException>().having((e) => e.kind, 'kind', ResearchFailureKind.permissionDenied)),
      );
      expect(await service.fetchOwnAttempts(uid), isEmpty);
    });

    test('Ready → the window closes → start() shows the closed state, not a connection error', () async {
      service.participant = pendingParticipant();
      expect(await load(), isA<PlacementTestReady>());
      service.study = openStudy(open: const {});
      await controller().start();
      expect(state(), isA<PlacementTestBlocked>().having((s) => s.reason, 'reason', PlacementBlock.researchClosed));
      expect(service.createCalls, 1);
      expect(service.attempts, isEmpty);
    });

    test('a pending review opened after Ready shows the review state', () async {
      service.participant = pendingParticipant();
      await load();
      service.participant = pendingParticipant(reviewPending: true);
      await controller().start();
      expect(state(), isA<PlacementTestBlocked>().having((s) => s.reason, 'reason', PlacementBlock.reviewPending));
    });

    test('learning placement closing after Ready leaves the Ready screen', () async {
      await load();
      service.config = const PlacementConfig(instrumentVersion: kPlacementInstrumentVersion, learningOpen: false);
      await controller().start();
      expect(state(), isA<PlacementTestBlocked>());
    });

    test('a refusal the status re-read cannot explain (device clock ahead of the server) says so instead of doing nothing', () async {
      service.participant = pendingParticipant();
      await load();
      service.writeFaults.add(const FakeFaultSpec(FakeFault.failBefore, ResearchFailureKind.permissionDenied));
      await controller().start();
      expect(state(), isA<PlacementTestReady>().having((s) => s.error, 'error', PlacementActionError.refused));
    });

    test('a real connection failure is still reported as one, and a retry starts the test', () async {
      service.participant = pendingParticipant();
      await load();
      service.writeFaults.add(const FakeFaultSpec(FakeFault.failBefore, ResearchFailureKind.unavailable));
      await controller().start();
      expect(state(), isA<PlacementTestReady>().having((s) => s.error, 'error', PlacementActionError.network));
      await controller().start();
      expect(state(), isA<PlacementTestAnswering>());
    });

    test('a failed read after a refused create is reported as a connection problem', () async {
      service.participant = pendingParticipant();
      await load();
      service.writeFaults.add(const FakeFaultSpec(FakeFault.failBefore, ResearchFailureKind.permissionDenied));
      service.readFaults.add(ResearchFailureKind.unavailable);
      await controller().start();
      expect(state(), isA<PlacementTestReady>().having((s) => s.error, 'error', PlacementActionError.network));
    });

    test('a create that landed but lost its acknowledgement enters the stored attempt', () async {
      service.participant = pendingParticipant();
      await load();
      service.writeFaults.add(const FakeFaultSpec(FakeFault.applyThenFail, ResearchFailureKind.timeout));
      await controller().start();
      final s = state() as PlacementTestAnswering;
      expect(s.attempt.id, 'student-1_research_1');
      expect(s.attempt.studentId, uid);
      expect(s.attempt.context, PlacementContext.research);
    });

    test('another own attempt is never mistaken for the one being started', () async {
      service.participant = pendingParticipant();
      await load();
      service.attempts['student-1_learning_1'] = ownAttempt(PlacementContext.learning, 1);
      service.writeFaults.add(const FakeFaultSpec(FakeFault.failBefore, ResearchFailureKind.unavailable));
      await controller().start();
      expect(state(), isA<PlacementTestReady>().having((s) => s.error, 'error', PlacementActionError.network));
    });
  });

  test('closing the window mid-test pauses it; answers stay saved; submission after closure is refused', () async {
    service.participant = pendingParticipant();
    await load();
    await controller().start();
    await answerAll([7, 7, 7, 0, 0]);
    service.study = openStudy(open: const {});
    await controller().submit();
    expect(state(), isA<PlacementTestPaused>());
    final stored = service.attempts.values.single;
    expect(stored.status, PlacementAttemptStatus.inProgress);
    expect(stored.answers, hasLength(50));
  });

  test('a research result assigns the band; C1 excludes the participant without a band', () async {
    service.participant = pendingParticipant();
    await load();
    await controller().start();
    await answerAll([10, 10, 10, 10, 9]);
    await controller().submit();
    expect((state() as PlacementTestResult).attempt.result!.resultLevel, 'C1');
    expect(service.participant!.status, ResearchParticipantStatus.excluded);
    expect(service.participant!.assignment, isNull);
  });

  test('scoring refused (e.g. pending review) keeps the submission and shows a retryable message', () async {
    service.participant = pendingParticipant();
    service.refuseBandWrite = true;
    await load();
    await controller().start();
    await answerAll([8, 8, 0, 0, 0]);
    await controller().submit();
    expect(state(), isA<PlacementTestScoring>().having((s) => s.error, 'error', PlacementActionError.refused));
    expect(service.attempts.values.single.status, PlacementAttemptStatus.submitted);
    service.refuseBandWrite = false;
    await controller().retryScoring();
    expect((state() as PlacementTestResult).attempt.result!.resultLevel, 'A2');
  });

  test('a submitted attempt found on load is scored automatically (also after closure)', () async {
    service.participant = pendingParticipant();
    await service.loadInstrument();
    final instrument = await service.loadInstrument();
    final order = PlacementAttemptRecord.buildItemOrder(instrument, Random(1));
    service.attempts['student-1_research_1'] = PlacementAttemptRecord(
      id: 'student-1_research_1',
      studentId: uid,
      context: PlacementContext.research,
      attemptNumber: 1,
      instrumentVersion: kPlacementInstrumentVersion,
      itemOrder: order,
      answers: service.answersFor([7, 0, 0, 0, 0]),
      status: PlacementAttemptStatus.submitted,
    );
    service.study = openStudy(open: const {});
    expect(await load(), isA<PlacementTestResult>().having((s) => s.attempt.result!.resultLevel, 'level', 'A1'));
  });

  test('a resumed attempt shows the instructions, then the first unanswered item', () async {
    final instrument = await service.loadInstrument();
    final order = PlacementAttemptRecord.buildItemOrder(instrument, Random(1));
    service.attempts['student-1_learning_1'] = PlacementAttemptRecord(
      id: 'student-1_learning_1',
      studentId: uid,
      context: PlacementContext.learning,
      attemptNumber: 1,
      instrumentVersion: kPlacementInstrumentVersion,
      itemOrder: order,
      answers: {for (final id in order.take(12)) id: 'E'},
      status: PlacementAttemptStatus.inProgress,
    );
    final s = await load() as PlacementTestAnswering;
    expect(s.showIntro, isTrue);
    expect(s.index, 12);
  });

  test('"app hidden" signals are recorded and never change the test; failures are ignored', () async {
    await load();
    await controller().start();
    await controller().recordHidden();
    await controller().recordHidden();
    expect(service.attempts.values.single.tabSwitchCount, 2);
    service.writeFaults.add(const FakeFaultSpec(FakeFault.failBefore, ResearchFailureKind.unavailable));
    await controller().recordHidden();
    final s = state() as PlacementTestAnswering;
    expect(s.error, isNull);
    expect(s.attempt.status, PlacementAttemptStatus.inProgress);
  });

  test('voided research attempts: technical vs integrity; never a punitive message', () async {
    service.participant = pendingParticipant();
    final instrument = await service.loadInstrument();
    service.attempts['student-1_research_1'] = PlacementAttemptRecord(
      id: 'student-1_research_1',
      studentId: uid,
      context: PlacementContext.research,
      attemptNumber: 1,
      instrumentVersion: kPlacementInstrumentVersion,
      itemOrder: PlacementAttemptRecord.buildItemOrder(instrument, Random(1)),
      answers: const {},
      status: PlacementAttemptStatus.voided,
      voidCategory: 'technical',
    );
    expect((await load() as PlacementTestBlocked).reason, PlacementBlock.voidedTechnical);
  });

  test('a stored attempt with an item outside the bank is invalid, never repaired', () async {
    final instrument = await service.loadInstrument();
    final order = PlacementAttemptRecord.buildItemOrder(instrument, Random(1))..[0] = 'pt-zz-99';
    service.attempts['student-1_learning_1'] = PlacementAttemptRecord(
      id: 'student-1_learning_1',
      studentId: uid,
      context: PlacementContext.learning,
      attemptNumber: 1,
      instrumentVersion: kPlacementInstrumentVersion,
      itemOrder: order,
      answers: const {},
      status: PlacementAttemptStatus.inProgress,
    );
    expect(await load(), isA<PlacementTestInvalid>());
  });

  test('a network failure while loading is retryable', () async {
    service.readFaults.add(ResearchFailureKind.unavailable);
    expect(await load(), isA<PlacementTestLoadFailed>());
    await controller().reload();
    expect(state(), isA<PlacementTestReady>());
  });
}
