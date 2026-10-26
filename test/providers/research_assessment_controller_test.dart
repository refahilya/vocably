import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/research_attempt.dart';
import 'package:vocably/models/research_attempt_plan.dart';
import 'package:vocably/models/research_instrument.dart';
import 'package:vocably/providers/research_assessment_providers.dart';
import 'package:vocably/services/research_assessment_service.dart';
import 'package:vocably/utils/research_attempt_planner.dart';

import '../support/fake_research_assessment_service.dart';

const _uid = 'stu1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeResearchAssessmentService server;
  late ProviderContainer container;
  late ResearchInstrument instrument;

  Future<ProviderContainer> makeContainer({int seed = 11}) async {
    final c = ProviderContainer(
      overrides: [
        researchAssessmentServiceProvider.overrideWithValue(server),
        researchAssessmentRandomProvider.overrideWithValue(Random(seed)),
      ],
    );
    instrument = await c.read(researchInstrumentProvider('v1').future);
    return c;
  }

  setUp(() async {
    server = FakeResearchAssessmentService(participant: participantFor());
    container = await makeContainer();
  });

  tearDown(() => container.dispose());

  final pre = researchAssessmentControllerProvider(_uid, ResearchStage.preTest);
  final post = researchAssessmentControllerProvider(
    _uid,
    ResearchStage.postTest,
  );
  String preId([int n = 1]) =>
      ResearchAttemptRecord.idFor(_uid, ResearchStage.preTest, n);

  Future<ResearchAssessmentState> settle(
    ResearchAssessmentControllerProvider provider,
  ) async {
    container.listen(provider, (_, _) {});
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(provider);
  }

  ResearchAssessmentController ctl(
    ResearchAssessmentControllerProvider provider,
  ) => container.read(provider.notifier);

  ResearchAssessmentInProgress inProgress(
    ResearchAssessmentControllerProvider provider,
  ) => container.read(provider) as ResearchAssessmentInProgress;

  /// A stored attempt in [band] with the first [answered] plan items
  /// answered (position 1), as if created earlier.
  ResearchAttemptPlan seedAttempt({
    int answered = 0,
    ResearchAttemptStatus status = ResearchAttemptStatus.inProgress,
    int number = 1,
    ResearchStage stage = ResearchStage.preTest,
    int seed = 99,
    List<int>? answeredIndexes,
  }) {
    final plan = planResearchAttempt(
      instrument: instrument,
      assignment: server.participant!.assignment,
      random: Random(seed),
    );
    final indexes = answeredIndexes ?? List.generate(answered, (i) => i);
    server.putAttempt(
      ResearchAttemptRecord(
        attemptId: ResearchAttemptRecord.idFor(_uid, stage, number),
        studentId: _uid,
        stage: stage,
        attemptNumber: number,
        band: plan.band,
        instrumentVersion: plan.instrumentVersion,
        itemOrder: plan.itemOrder,
        optionOrder: plan.optionOrder,
        responses: {
          for (final i in indexes)
            plan.items[i].itemId: ResearchResponse.forPlannedItem(
              plan.items[i],
              plan.items[i].substantiveOptions.first.id,
            ),
        },
        status: status,
      ),
    );
    return plan;
  }

  Future<void> answerCurrent(String optionId) async {
    ctl(pre).select(optionId);
    await ctl(pre).submit();
  }

  group('eligibility from the participant record', () {
    test('not enrolled', () async {
      server.participant = null;
      final s = await settle(pre);
      expect(
        (s as ResearchAssessmentUnavailable).kind,
        ResearchStageKind.notEnrolled,
      );
    });

    test('enrolled but this stage is not authorized', () async {
      server.participant = participantFor(preTest: 0);
      final s = await settle(pre);
      expect(
        (s as ResearchAssessmentUnavailable).kind,
        ResearchStageKind.notAuthorized,
      );
    });

    test(
      'posttest is locked until the authorized pretest is completed',
      () async {
        server.participant = participantFor(postTest: 1);
        seedAttempt(answered: 20);
        expect(
          ((await settle(post)) as ResearchAssessmentUnavailable).kind,
          ResearchStageKind.locked,
        );
      },
    );

    test('posttest is available once the pretest is completed', () async {
      server.participant = participantFor(postTest: 1);
      seedAttempt(answered: 20, status: ResearchAttemptStatus.completed);
      expect(await settle(post), isA<ResearchAssessmentReady>());
    });

    test(
      'a voided attempt is unavailable until a retake is authorized',
      () async {
        seedAttempt(answered: 3, status: ResearchAttemptStatus.voided);
        expect(
          ((await settle(pre)) as ResearchAssessmentUnavailable).kind,
          ResearchStageKind.voided,
        );

        server.participant = participantFor(preTest: 2);
        await ctl(pre).reload();
        expect(container.read(pre), isA<ResearchAssessmentReady>());
      },
    );

    test('a completed attempt shows as completed', () async {
      seedAttempt(answered: 20, status: ResearchAttemptStatus.completed);
      expect(await settle(pre), isA<ResearchAssessmentCompleted>());
    });
  });

  group('invalid or unreadable data', () {
    test(
      'an attempt whose band contradicts the participant is invalid',
      () async {
        seedAttempt();
        server.putAttempt(
          server.copyAttempt(server.attempts[preId()]!, band: 'B1'),
        );
        expect(await settle(pre), isA<ResearchAssessmentInvalid>());
      },
    );

    test(
      'a saved answer inconsistent with the stored order is invalid',
      () async {
        final plan = seedAttempt();
        final item = plan.items.first;
        server.putAttempt(
          server.copyAttempt(
            server.attempts[preId()]!,
            responses: {
              item.itemId: ResearchResponse(
                optionId: item.substantiveOptions.first.id,
                optionText: item.substantiveOptions.first.text,
                displayPosition: 4,
              ),
            },
          ),
        );
        expect(await settle(pre), isA<ResearchAssessmentInvalid>());
      },
    );

    test('malformed stored data is invalid, not a crash', () async {
      server.readFaults.add(ResearchFailureKind.invalidData);
      expect(await settle(pre), isA<ResearchAssessmentInvalid>());
    });

    test('a network failure while loading can be retried', () async {
      server.readFaults.add(ResearchFailureKind.unavailable);
      expect(await settle(pre), isA<ResearchAssessmentLoadFailed>());
      await ctl(pre).reload();
      expect(container.read(pre), isA<ResearchAssessmentReady>());
    });
  });

  group('starting an attempt', () {
    test(
      'creates the attempt with the injected random plan and shows the stored order',
      () async {
        await settle(pre);
        await ctl(pre).start();

        final expected = planResearchAttempt(
          instrument: instrument,
          assignment: server.participant!.assignment,
          random: Random(11),
        );
        final stored = server.attempts[preId()]!;
        expect(stored.itemOrder, expected.itemOrder);
        expect(stored.optionOrder, expected.optionOrder);
        final s = inProgress(pre);
        expect(s.plan.itemOrder, stored.itemOrder);
        expect(s.currentIndex, 0);
        expect(s.showIntro, isFalse);
        expect(server.createCalls, 1);
      },
    );

    test(
      'a create that lost a race shows the order already stored, not a new one',
      () async {
        await settle(pre);
        late ResearchAttemptPlan other;
        server.beforeNextWrite = () => other = seedAttempt(seed: 1234);
        await ctl(pre).start();

        expect(inProgress(pre).plan.itemOrder, other.itemOrder);
        expect(inProgress(pre).plan.optionOrder, other.optionOrder);
      },
    );

    test(
      'a lost acknowledgement on create still continues with the stored attempt',
      () async {
        await settle(pre);
        server.writeFaults.add(
          const FakeFaultSpec(
            FakeFault.applyThenFail,
            ResearchFailureKind.timeout,
          ),
        );
        await ctl(pre).start();
        expect(container.read(pre), isA<ResearchAssessmentInProgress>());
      },
    );

    test(
      'a network failure leaves the attempt unstarted and retryable',
      () async {
        await settle(pre);
        server.writeFaults.add(
          const FakeFaultSpec(
            FakeFault.failBefore,
            ResearchFailureKind.unavailable,
          ),
        );
        await ctl(pre).start();
        expect(
          (container.read(pre) as ResearchAssessmentReady).error,
          ResearchActionError.network,
        );
        expect(server.attempts, isEmpty);

        await ctl(pre).start();
        expect(container.read(pre), isA<ResearchAssessmentInProgress>());
      },
    );

    test(
      'a refused create with nothing stored asks for the researcher',
      () async {
        await settle(pre);
        server.writeFaults.add(
          const FakeFaultSpec(
            FakeFault.failBefore,
            ResearchFailureKind.permissionDenied,
          ),
        );
        await ctl(pre).start();
        expect(
          (container.read(pre) as ResearchAssessmentReady).error,
          ResearchActionError.refused,
        );
      },
    );

    test(
      'a start against a stale authorization moves to the current attempt',
      () async {
        await settle(pre);
        // Meanwhile, attempt 1 was started elsewhere, voided, and a retake
        // (attempt 2) authorized.
        seedAttempt(answered: 2, status: ResearchAttemptStatus.voided);
        server.participant = participantFor(preTest: 2);

        await ctl(pre).start();
        final s = container.read(pre);
        expect(s, isA<ResearchAssessmentReady>());
        expect((s as ResearchAssessmentReady).error, isNull);
        await ctl(pre).start();
        expect(server.attempts.containsKey(preId(2)), isTrue);
        expect(container.read(pre), isA<ResearchAssessmentInProgress>());
      },
    );

    test(
      'an unexpected error while starting is retryable, not a stuck spinner',
      () async {
        await settle(pre);
        server.unexpectedNextWriteError = StateError('unmapped');
        await ctl(pre).start();
        expect(
          (container.read(pre) as ResearchAssessmentReady).error,
          ResearchActionError.network,
        );
      },
    );
  });

  group('answering', () {
    setUp(() async {
      await settle(pre);
      await ctl(pre).start();
    });

    test('nothing is saved without a selection', () async {
      await ctl(pre).submit();
      expect(server.saveCalls, 0);
      expect(inProgress(pre).currentIndex, 0);
    });

    test(
      'saves the displayed position and exact text, then moves on',
      () async {
        final item = inProgress(pre).currentItem;
        final choice = item.substantiveOptions[2];
        await answerCurrent(choice.id);

        final saved = server.attempts[preId()]!.responses[item.itemId]!;
        expect(saved.optionId, choice.id);
        expect(saved.optionText, choice.text);
        expect(saved.displayPosition, 3);
        expect(inProgress(pre).currentIndex, 1);
        expect(inProgress(pre).selectedOptionId, isNull);
      },
    );

    test(
      '"Saya tidak tahu kata ini" is saved as dont_know at position 5',
      () async {
        final item = inProgress(pre).currentItem;
        await answerCurrent('dont_know');
        final saved = server.attempts[preId()]!.responses[item.itemId]!;
        expect(saved.optionId, 'dont_know');
        expect(saved.displayPosition, 5);
      },
    );

    test(
      'a failed save keeps the item and the selection, and a retry saves once',
      () async {
        final item = inProgress(pre).currentItem;
        final choice = item.substantiveOptions[1].id;
        server.writeFaults.add(
          const FakeFaultSpec(
            FakeFault.failBefore,
            ResearchFailureKind.unavailable,
          ),
        );
        await answerCurrent(choice);

        final failed = inProgress(pre);
        expect(failed.currentIndex, 0);
        expect(failed.error, ResearchActionError.network);
        expect(failed.selectedOptionId, choice);
        expect(failed.saving, isFalse);
        expect(failed.selectionLocked, isTrue);
        expect(server.attempts[preId()]!.responses, isEmpty);

        // The submitted choice can't be swapped: an unconfirmed write may
        // still land later and would be the stored answer.
        ctl(pre).select(item.substantiveOptions[3].id);
        expect(inProgress(pre).selectedOptionId, choice);

        await ctl(pre).submit();
        expect(inProgress(pre).currentIndex, 1);
        expect(inProgress(pre).selectionLocked, isFalse, reason: 'new item');
        expect(server.attempts[preId()]!.responses.keys, [item.itemId]);
        expect(
          server.attempts[preId()]!.responses[item.itemId]!.optionId,
          choice,
        );
      },
    );

    test('an unexpected error never leaves the save spinning', () async {
      server.unexpectedNextWriteError = StateError('unmapped platform error');
      await answerCurrent('dont_know');
      final s = inProgress(pre);
      expect(s.saving, isFalse);
      expect(s.error, ResearchActionError.network);
      await ctl(pre).submit();
      expect(inProgress(pre).currentIndex, 1);
    });

    test('a lost acknowledgement is not reported as a failure', () async {
      server.writeFaults.add(
        const FakeFaultSpec(
          FakeFault.applyThenFail,
          ResearchFailureKind.timeout,
        ),
      );
      await answerCurrent('dont_know');
      expect(inProgress(pre).currentIndex, 1);
      expect(inProgress(pre).error, isNull);
      expect(server.attempts[preId()]!.responses, hasLength(1));
    });

    test(
      'if the confirming read fails, the retry is refused as a duplicate and resolves to saved',
      () async {
        final item = inProgress(pre).currentItem;
        final choice = item.substantiveOptions.first.id;
        server.readFaults.add(ResearchFailureKind.unavailable);
        await answerCurrent(choice);
        expect(inProgress(pre).error, ResearchActionError.network);
        expect(server.attempts[preId()]!.responses, hasLength(1));

        await ctl(pre).submit();
        expect(server.saveCalls, 2);
        expect(inProgress(pre).currentIndex, 1);
        expect(
          server.attempts[preId()]!.responses[item.itemId]!.optionId,
          choice,
        );
      },
    );

    test(
      'an answer already saved elsewhere stands; the new choice never replaces it',
      () async {
        final item = inProgress(pre).currentItem;
        final first = item.substantiveOptions[3];
        server.beforeNextWrite = () {
          final a = server.attempts[preId()]!;
          server.putAttempt(
            server.copyAttempt(
              a,
              responses: {
                item.itemId: ResearchResponse.forPlannedItem(item, first.id),
              },
            ),
          );
        };
        await answerCurrent(item.substantiveOptions[0].id);

        expect(
          server.attempts[preId()]!.responses[item.itemId]!.optionId,
          first.id,
        );
        expect(inProgress(pre).currentIndex, 1);
      },
    );

    test('concurrent submits write once', () async {
      ctl(pre).select('dont_know');
      await Future.wait([ctl(pre).submit(), ctl(pre).submit()]);
      expect(server.saveCalls, 1);
      expect(inProgress(pre).currentIndex, 1);
    });

    test('selection is ignored while saving', () async {
      final item = inProgress(pre).currentItem;
      ctl(pre).select(item.substantiveOptions.first.id);
      final pending = ctl(pre).submit();
      ctl(pre).select(item.substantiveOptions[1].id);
      await pending;
      expect(
        server.attempts[preId()]!.responses[item.itemId]!.optionId,
        item.substantiveOptions.first.id,
      );
    });

    test(
      'an option not shown for the current item cannot be selected',
      () async {
        final other = inProgress(pre).plan.items[1].substantiveOptions.first.id;
        ctl(pre).select(other);
        expect(inProgress(pre).selectedOptionId, isNull);
      },
    );

    test(
      'answering all 20 completes the attempt only after the server holds them',
      () async {
        for (var i = 0; i < 20; i++) {
          final item = inProgress(pre).currentItem;
          await answerCurrent(
            i.isEven ? item.substantiveOptions[i % 4].id : 'dont_know',
          );
          if (i < 19) expect(inProgress(pre).currentIndex, i + 1);
        }
        expect(container.read(pre), isA<ResearchAssessmentCompleted>());
        final stored = server.attempts[preId()]!;
        expect(stored.status, ResearchAttemptStatus.completed);
        expect(stored.responses, hasLength(20));
        expect(server.completeCalls, 1);
      },
    );

    test('a failed completion can be retried', () async {
      for (var i = 0; i < 19; i++) {
        await answerCurrent('dont_know');
      }
      // The 20th answer saves; marking the attempt completed then fails.
      server.writeFaults.addAll([
        null,
        const FakeFaultSpec(FakeFault.failBefore, ResearchFailureKind.timeout),
      ]);
      await answerCurrent('dont_know');
      expect(
        (container.read(pre) as ResearchAssessmentCompleting).error,
        ResearchActionError.network,
      );
      expect(server.attempts[preId()]!.responses, hasLength(20));
      expect(
        server.attempts[preId()]!.status,
        ResearchAttemptStatus.inProgress,
      );

      await ctl(pre).retryCompletion();
      expect(container.read(pre), isA<ResearchAssessmentCompleted>());
    });

    test(
      'a retake authorized mid-attempt sends the student to the new attempt',
      () async {
        await answerCurrent('dont_know');
        // Researcher voids attempt 1 and authorizes attempt 2.
        server.putAttempt(
          server.copyAttempt(
            server.attempts[preId()]!,
            status: ResearchAttemptStatus.voided,
          ),
        );
        server.participant = participantFor(preTest: 2);
        await answerCurrent('dont_know');
        expect(container.read(pre), isA<ResearchAssessmentReady>());
        expect(server.attempts[preId()]!.responses, hasLength(1));
      },
    );
  });

  group('resuming', () {
    test(
      'resumes at the first unanswered item in the stored order, after the instructions',
      () async {
        final plan = seedAttempt(answeredIndexes: [0, 1, 3, 7]);
        final s = await settle(pre) as ResearchAssessmentInProgress;
        expect(s.plan.itemOrder, plan.itemOrder);
        expect(s.plan.optionOrder, plan.optionOrder);
        expect(s.currentIndex, 2);
        expect(s.showIntro, isTrue);

        ctl(pre).select('dont_know');
        await ctl(pre).submit();
        expect(server.saveCalls, 0, reason: 'no answering behind the intro');

        ctl(pre).continueFromIntro();
        await answerCurrent('dont_know');
        expect(inProgress(pre).currentIndex, 4);
        expect(
          server.createCalls,
          0,
          reason: 'an existing attempt is never re-randomized',
        );
      },
    );

    test(
      'a fully answered but uncompleted attempt is completed on load',
      () async {
        seedAttempt(answered: 20);
        expect(await settle(pre), isA<ResearchAssessmentCompleted>());
        expect(
          server.attempts[preId()]!.status,
          ResearchAttemptStatus.completed,
        );
      },
    );
  });
}
