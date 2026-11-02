import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/placement_attempt.dart';
import 'package:vocably/models/research_attempt.dart';
import 'package:vocably/models/research_panel.dart';
import 'package:vocably/models/research_participant.dart';

import '../support/fake_research_panel_service.dart';

void main() {
  PanelCell cell(PanelParticipant p, PanelStage stage, [List<PanelProgress> progress = const []]) =>
      PanelRow.derive(p, null, {for (final m in progress) m.attemptId: m}).cells[stage]!;

  group('placement cell', () {
    test('band-less participant: not started, answering (count), submitted', () {
      final p = panelParticipant('u1', status: ResearchParticipantStatus.awaitingPlacement);
      expect(cell(p, PanelStage.placement).kind, PanelCellKind.placementNotStarted);
      final answering = cell(p, PanelStage.placement, [panelProgress('u1', PanelStage.placement, answered: 23)]);
      expect([answering.kind, answering.answered, answering.total], [PanelCellKind.placementInProgress, 23, 50]);
      expect(
        cell(p, PanelStage.placement, [panelProgress('u1', PanelStage.placement, answered: 50, status: 'submitted')]).kind,
        PanelCellKind.placementSubmitted,
      );
    });

    test('banded, excluded (C1), and the cases only the tooling handles', () {
      expect(cell(panelParticipant('u1', band: 'B2'), PanelStage.placement).band, 'B2');
      expect(cell(panelParticipant('u1', status: ResearchParticipantStatus.excluded, band: null), PanelStage.placement).kind, PanelCellKind.excluded);
      for (final p in [
        panelParticipant('u1', reviewPending: true),
        panelParticipant('u1', status: ResearchParticipantStatus.awaitingManualBand, band: null),
        panelParticipant('u1', status: ResearchParticipantStatus.conditional),
      ]) {
        final c = cell(p, PanelStage.placement);
        expect(c.kind, PanelCellKind.needsResearcher);
        expect(c.hasAction, isFalse);
      }
    });

    test('a mirror of another attempt number is ignored', () {
      final p = panelParticipant('u1', status: ResearchParticipantStatus.awaitingPlacement, placement: 2);
      expect(cell(p, PanelStage.placement, [panelProgress('u1', PanelStage.placement, n: 1, answered: 9)]).kind, PanelCellKind.placementNotStarted);
    });
  });

  group('pretest / posttest cells', () {
    test('no band yet: waiting, and never an action', () {
      final p = panelParticipant('u1', status: ResearchParticipantStatus.awaitingPlacement);
      for (final stage in [PanelStage.preTest, PanelStage.postTest]) {
        expect(cell(p, stage).kind, PanelCellKind.waitingForBand);
        expect(cell(p, stage).hasAction, isFalse);
      }
      expect(cell(panelParticipant('u1', status: ResearchParticipantStatus.excluded, band: null), PanelStage.preTest).kind, PanelCellKind.notEligible);
      expect(cell(panelParticipant('u1', reviewPending: true), PanelStage.preTest).kind, PanelCellKind.notEligible);
    });

    test('pretest: authorize → not started → answering (void + retake) → completed', () {
      expect(cell(panelParticipant('u1'), PanelStage.preTest).canAuthorize, isTrue);
      final p = panelParticipant('u1', pre: 1);
      expect(cell(p, PanelStage.preTest).kind, PanelCellKind.notStarted);
      final answering = cell(p, PanelStage.preTest, [panelProgress('u1', PanelStage.preTest, answered: 7)]);
      expect([answering.kind, answering.answered, answering.canVoidAndRetake], [PanelCellKind.inProgress, 7, true]);
      final done = cell(p, PanelStage.preTest, [panelProgress('u1', PanelStage.preTest, answered: 20, status: 'completed')]);
      expect([done.kind, done.hasAction], [PanelCellKind.completed, false]);
    });

    test('a voided attempt offers a retake; attempt 2 is shown as such', () {
      final voided = cell(panelParticipant('u1', pre: 1), PanelStage.preTest, [panelProgress('u1', PanelStage.preTest, status: 'voided')]);
      expect([voided.kind, voided.canRetake], [PanelCellKind.voided, true]);
      final second = cell(panelParticipant('u1', pre: 2), PanelStage.preTest, [panelProgress('u1', PanelStage.preTest, status: 'voided')]);
      expect([second.kind, second.attemptNumber], [PanelCellKind.notStarted, 2]);
    });

    test('posttest waits for a completed pretest; pretest retakes stop once the posttest is authorized', () {
      expect(cell(panelParticipant('u1', pre: 1), PanelStage.postTest).kind, PanelCellKind.waitingForPreTest);
      final preDone = [panelProgress('u1', PanelStage.preTest, answered: 20, status: 'completed')];
      expect(cell(panelParticipant('u1', pre: 1), PanelStage.postTest, preDone).canAuthorize, isTrue);
      final both = panelParticipant('u1', pre: 1, post: 1);
      final pre = cell(both, PanelStage.preTest, [panelProgress('u1', PanelStage.preTest, answered: 3)]);
      expect(pre.canVoidAndRetake, isFalse);
      final post = cell(both, PanelStage.postTest, [panelProgress('u1', PanelStage.postTest, answered: 3)]);
      expect(post.canVoidAndRetake, isTrue);
    });
  });

  test('records are parsed leniently, one by one', () {
    final legacy = PanelParticipant.fromFirestore('u1', {
      'researchId': 'R-1',
      'band': 'A2',
      'bandSource': 'researcher_assigned',
      'instrumentVersion': 'v1',
      'authorizedAttempts': {'preTest': 0, 'postTest': 0},
      'cohort': 'study',
    });
    expect([legacy.status, legacy.attempt(PanelStage.placement), legacy.unreadable, legacy.bandFromPlacement],
        [ResearchParticipantStatus.enrolled, 0, false, false]);
    final broken = PanelParticipant.fromFirestore('u2', {'researchId': 'R-2', 'status': 'weird', 'authorizedAttempts': {}});
    expect(broken.unreadable, isTrue);
    expect(PanelRow.derive(broken, null, {}).cells.values.map((c) => c.kind), everyElement(PanelCellKind.unreadable));
    expect(PanelProgress.fromFirestore('x', {'stage': 'preTest'}), isNull);
  });

  test('study windows: open-ended, closed, and the operator sequence', () {
    final now = DateTime.now();
    final study = PanelStudy.fromFirestore({
      'status': 'active',
      'operatorSeq': 4,
      'stages': {
        'preTest': {'openAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))), 'closeAt': Timestamp.fromDate(kOpenEndedStageClose)},
        'placement': {'openAt': Timestamp.fromDate(now.subtract(const Duration(hours: 2))), 'closeAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1)))},
      },
    });
    expect(study.operatorSeq, 4);
    expect(study.stageOpen(PanelStage.preTest, now), isTrue);
    expect(study.windows[PanelStage.preTest]!.openEnded, isTrue);
    expect(study.stageOpen(PanelStage.placement, now), isFalse);
    expect(study.stageOpen(PanelStage.postTest, now), isFalse);
    expect(PanelStudy.fromFirestore(null).exists, isFalse);
    expect(PanelStudy.fromFirestore(null).active, isFalse);
  });

  group('student progress mirror', () {
    test('a research attempt mirrors counts and status only — never answers', () {
      final a = ResearchAttemptRecord(
        attemptId: 'u1_preTest_1',
        studentId: 'u1',
        stage: ResearchStage.preTest,
        attemptNumber: 1,
        band: 'B1',
        instrumentVersion: 'v1',
        itemOrder: const [],
        optionOrder: const {},
        responses: const {},
        status: ResearchAttemptStatus.inProgress,
      );
      expect(ResearchProgressMirror.forResearch(a, 'TS'), {
        'studentId': 'u1',
        'stage': 'preTest',
        'attemptNumber': 1,
        'answered': 0,
        'total': 20,
        'status': 'in_progress',
        'updatedAt': 'TS',
      });
    });

    test('only research placement attempts are mirrored', () {
      PlacementAttemptRecord attempt(PlacementContext context) => PlacementAttemptRecord(
        id: 'u1_${context.name}_1',
        studentId: 'u1',
        context: context,
        attemptNumber: 1,
        instrumentVersion: 'PT-V1.1',
        itemOrder: const [],
        answers: const {'A1-01': 'A', 'A1-02': 'E'},
        status: PlacementAttemptStatus.inProgress,
      );
      expect(ResearchProgressMirror.forPlacement(attempt(PlacementContext.learning), 'TS'), isNull);
      expect(ResearchProgressMirror.forPlacement(attempt(PlacementContext.research), 'TS'), {
        'studentId': 'u1',
        'stage': 'placement',
        'attemptNumber': 1,
        'answered': 2,
        'total': 50,
        'status': 'in_progress',
        'updatedAt': 'TS',
      });
    });
  });

  test('combined data: sorted register, counts and the authorizable list', () {
    final data = ResearchPanelData.combine(
      study: activeStudy(),
      participants: [panelParticipant('b', researchId: 'R-02'), panelParticipant('a', researchId: 'R-01', pre: 1)],
      roster: const [PanelRosterEntry(uid: 'a', name: 'Ani', researchId: 'R-01')],
      progress: [panelProgress('a', PanelStage.preTest, answered: 4)],
      audit: const [],
    );
    expect(data.rows.map((r) => r.participant.researchId), ['R-01', 'R-02']);
    expect(data.rows.first.name, 'Ani');
    expect(data.rows.last.name, '');
    expect(data.count(PanelStage.preTest, PanelCellKind.inProgress), 1);
    expect(data.authorizable(PanelStage.preTest).map((r) => r.uid), ['b']);
  });
}
