import 'package:cloud_firestore/cloud_firestore.dart';

import 'placement_attempt.dart';
import 'research_attempt.dart';
import 'research_participant.dart';
import 'research_study.dart';

/// The three research stages the Researcher Panel controls
/// (`DATA_MODEL.md` §6d). [id] is the stage key used in Firestore.
enum PanelStage {
  placement('placement', 'Placement Test', 50),
  preTest('preTest', 'Pre-Test', 20),
  postTest('postTest', 'Post-Test', 20);

  const PanelStage(this.id, this.label, this.items);

  final String id;
  final String label;

  /// Items per attempt (the progress mirror's `total`).
  final int items;

  static PanelStage? fromId(Object? id) {
    for (final stage in values) {
      if (stage.id == id) return stage;
    }
    return null;
  }
}

/// "Open until closed": the same far-future idea as `kNoEndDate`, and the
/// value the research tooling writes for an open-ended window.
final DateTime kOpenEndedStageClose = DateTime.utc(9999, 12, 31, 23, 59, 59);

/// The only reason code the panel ever writes for a void or retake. Never
/// free text: the attempt document is readable by the student.
const String kTechnicalInterruption = 'technical_interruption';

class PanelWindow {
  const PanelWindow({required this.openAt, required this.closeAt});

  final DateTime openAt;
  final DateTime closeAt;

  bool isOpenAt(DateTime now) => !now.isBefore(openAt) && now.isBefore(closeAt);

  /// Opened without a planned closing time.
  bool get openEnded => closeAt.year >= 9999;
}

/// `researchStudy/current` as the panel needs it. The rules decide with the
/// server clock; the panel's open/closed view uses the device clock.
class PanelStudy {
  const PanelStudy({
    required this.exists,
    required this.status,
    required this.operatorSeq,
    required this.windows,
  });

  /// `false` when the tooling has not created the study document yet.
  final bool exists;
  final ResearchStudyStatus status;

  /// Number of panel window changes so far (`DATA_MODEL.md` §6d).
  final int operatorSeq;
  final Map<PanelStage, PanelWindow> windows;

  bool get active => exists && status == ResearchStudyStatus.active;

  bool stageOpen(PanelStage stage, DateTime now) =>
      active && (windows[stage]?.isOpenAt(now) ?? false);

  factory PanelStudy.fromFirestore(Map<String, dynamic>? data) {
    final study = ResearchStudy.fromFirestore(data);
    final windows = <PanelStage, PanelWindow>{};
    for (final entry in study.windows.entries) {
      final stage = PanelStage.fromId(entry.key);
      if (stage != null) {
        windows[stage] = PanelWindow(
          openAt: entry.value.openAt,
          closeAt: entry.value.closeAt,
        );
      }
    }
    final seq = data?['operatorSeq'];
    return PanelStudy(
      exists: data != null,
      status: study.status,
      operatorSeq: seq is int ? seq : 0,
      windows: windows,
    );
  }
}

/// One `researchParticipants/{uid}` record, read by the operator. Parsing
/// is lenient per record: a record the panel cannot read is shown as
/// [PanelParticipant.unreadable] instead of hiding the whole list.
class PanelParticipant {
  const PanelParticipant({
    required this.uid,
    required this.researchId,
    required this.cohort,
    required this.status,
    required this.band,
    required this.bandSource,
    required this.exclusionReason,
    required this.reviewPending,
    required this.authorized,
    this.unreadable = false,
  });

  final String uid;
  final String researchId;
  final String cohort;

  /// `null` when the stored status is unknown (the record is unreadable).
  final ResearchParticipantStatus? status;
  final String? band;
  final String? bandSource;
  final String? exclusionReason;
  final bool reviewPending;

  /// Authorized attempt number per stage (0 = not authorized).
  final Map<PanelStage, int> authorized;
  final bool unreadable;

  int attempt(PanelStage stage) => authorized[stage] ?? 0;

  bool get canTakeResearchStages =>
      !unreadable &&
      status == ResearchParticipantStatus.enrolled &&
      band != null &&
      !reviewPending;

  bool get bandFromPlacement => bandSource == 'placement_test';

  static const _statusByName = {
    'awaiting_placement': ResearchParticipantStatus.awaitingPlacement,
    'enrolled': ResearchParticipantStatus.enrolled,
    'excluded': ResearchParticipantStatus.excluded,
    'awaiting_manual_band': ResearchParticipantStatus.awaitingManualBand,
    'conditional': ResearchParticipantStatus.conditional,
  };

  factory PanelParticipant.fromFirestore(String uid, Map<String, dynamic> data) {
    final rawStatus = data['status'];
    // Legacy researcher-assigned records have no status and count as enrolled.
    final status = rawStatus == null ? ResearchParticipantStatus.enrolled : _statusByName[rawStatus];
    final attempts = data['authorizedAttempts'];
    final band = data['band'];
    final researchId = data['researchId'];
    var unreadable = status == null || attempts is! Map || researchId is! String;
    int count(String key) {
      final value = attempts is Map ? attempts[key] : null;
      if (value == null) return 0;
      if (value is! int || value < 0) {
        unreadable = true;
        return 0;
      }
      return value;
    }

    final authorized = {for (final stage in PanelStage.values) stage: count(stage.id)};
    return PanelParticipant(
      uid: uid,
      researchId: researchId is String ? researchId : uid,
      cohort: data['cohort'] is String ? data['cohort'] as String : '',
      status: status,
      band: band is String ? band : null,
      bandSource: data['bandSource'] is String ? data['bandSource'] as String : null,
      exclusionReason: data['exclusionReason'] is String ? data['exclusionReason'] as String : null,
      reviewPending: data['reviewStatus'] == 'pending',
      authorized: authorized,
      unreadable: unreadable,
    );
  }
}

/// `researchRoster/{uid}`: the name the panel shows next to the research ID.
class PanelRosterEntry {
  const PanelRosterEntry({required this.uid, required this.name, required this.researchId});

  final String uid;
  final String name;
  final String researchId;

  factory PanelRosterEntry.fromFirestore(String uid, Map<String, dynamic> data) => PanelRosterEntry(
    uid: uid,
    name: data['name'] is String ? data['name'] as String : '',
    researchId: data['researchId'] is String ? data['researchId'] as String : '',
  );
}

/// `researchProgress/{attemptId}`: counts and status of one attempt — never
/// the answers (`DATA_MODEL.md` §6d).
class PanelProgress {
  const PanelProgress({
    required this.attemptId,
    required this.studentId,
    required this.stage,
    required this.attemptNumber,
    required this.answered,
    required this.total,
    required this.status,
  });

  final String attemptId;
  final String studentId;
  final PanelStage stage;
  final int attemptNumber;
  final int answered;
  final int total;

  /// `in_progress`, `completed`, `submitted`, `scored` or `voided`.
  final String status;

  /// `null` when the document is not a valid mirror.
  static PanelProgress? fromFirestore(String id, Map<String, dynamic> data) {
    final stage = PanelStage.fromId(data['stage']);
    final studentId = data['studentId'];
    final n = data['attemptNumber'];
    final answered = data['answered'];
    final total = data['total'];
    final status = data['status'];
    if (stage == null || studentId is! String || n is! int || answered is! int || total is! int || status is! String) {
      return null;
    }
    return PanelProgress(
      attemptId: id,
      studentId: studentId,
      stage: stage,
      attemptNumber: n,
      answered: answered,
      total: total,
      status: status,
    );
  }

  /// The attempt document ID a progress mirror belongs to.
  static String attemptIdFor(String uid, PanelStage stage, int n) =>
      stage == PanelStage.placement ? '${uid}_research_$n' : '${uid}_${stage.id}_$n';
}

/// One entry of `researchAuditLog` (written with every panel action).
class PanelAuditEntry {
  const PanelAuditEntry({
    required this.id,
    required this.action,
    required this.stage,
    required this.targetUid,
    required this.attemptNumber,
    required this.at,
  });

  final String id;
  final String action;
  final PanelStage? stage;
  final String? targetUid;
  final int? attemptNumber;
  final DateTime? at;

  factory PanelAuditEntry.fromFirestore(String id, Map<String, dynamic> data) => PanelAuditEntry(
    id: id,
    action: data['action'] is String ? data['action'] as String : '',
    stage: PanelStage.fromId(data['stage']),
    targetUid: data['targetUid'] is String ? data['targetUid'] as String : null,
    attemptNumber: data['attemptNumber'] is int ? data['attemptNumber'] as int : null,
    at: data['at'] is Timestamp ? (data['at'] as Timestamp).toDate() : null,
  );
}

/// What one participant's cell for one stage says, and which action the
/// panel offers there. The rules re-check every action.
enum PanelCellKind {
  /// Placement: band-less, the research Placement Test not started.
  placementNotStarted,
  placementInProgress,

  /// Submitted, waiting for the app to score it.
  placementSubmitted,

  /// Placement: band assigned (from the Placement Test, or legacy).
  banded,

  /// Placement result C1: not part of the study.
  excluded,

  /// Needs the researcher's tooling: pending review, voided research
  /// placement, manual band or conditional status.
  needsResearcher,

  /// Pre/Post: no usable band yet (still awaiting the Placement Test).
  waitingForBand,

  /// Pre/Post: excluded or otherwise not eligible.
  notEligible,

  /// Pre/Post: attempt not authorized; [PanelCell.canAuthorize] says
  /// whether the panel can authorize it now.
  notAuthorized,

  /// Post-Test: the pretest is not completed yet.
  waitingForPreTest,
  notStarted,
  inProgress,
  completed,

  /// The authorized attempt was voided; a retake may be authorized.
  voided,

  /// The record could not be read.
  unreadable,
}

class PanelCell {
  const PanelCell(
    this.kind, {
    this.answered = 0,
    this.total = 0,
    this.attemptNumber = 0,
    this.band,
    this.canAuthorize = false,
    this.canVoidAndRetake = false,
    this.canRetake = false,
  });

  final PanelCellKind kind;
  final int answered;
  final int total;
  final int attemptNumber;
  final String? band;
  final bool canAuthorize;

  /// Technical interruption: void the unfinished attempt n and authorize
  /// attempt n + 1, in one batch.
  final bool canVoidAndRetake;

  /// Attempt n is already voided: authorize attempt n + 1.
  final bool canRetake;

  bool get hasAction => canAuthorize || canVoidAndRetake || canRetake;
}

/// One register row: participant, roster name and the three stage cells.
class PanelRow {
  PanelRow({required this.participant, required this.name, required this.cells});

  final PanelParticipant participant;

  /// Empty when no roster entry exists.
  final String name;
  final Map<PanelStage, PanelCell> cells;

  String get uid => participant.uid;

  static PanelRow derive(
    PanelParticipant p,
    PanelRosterEntry? roster,
    Map<String, PanelProgress> progressById,
  ) {
    PanelProgress? progressOf(PanelStage stage, int n) {
      if (n < 1) return null;
      final mirror = progressById[PanelProgress.attemptIdFor(p.uid, stage, n)];
      return mirror != null && mirror.studentId == p.uid && mirror.attemptNumber == n ? mirror : null;
    }

    PanelCell placement() {
      if (p.unreadable) return const PanelCell(PanelCellKind.unreadable);
      if (p.reviewPending) return const PanelCell(PanelCellKind.needsResearcher);
      switch (p.status!) {
        case ResearchParticipantStatus.enrolled:
          return PanelCell(PanelCellKind.banded, band: p.band);
        case ResearchParticipantStatus.excluded:
          return const PanelCell(PanelCellKind.excluded);
        case ResearchParticipantStatus.awaitingManualBand || ResearchParticipantStatus.conditional:
          return PanelCell(PanelCellKind.needsResearcher, band: p.band);
        case ResearchParticipantStatus.awaitingPlacement:
          break;
      }
      final n = p.attempt(PanelStage.placement);
      final mirror = progressOf(PanelStage.placement, n);
      return switch (mirror?.status) {
        null => PanelCell(PanelCellKind.placementNotStarted, attemptNumber: n, total: PanelStage.placement.items),
        'in_progress' => PanelCell(
          PanelCellKind.placementInProgress,
          answered: mirror!.answered,
          total: mirror.total,
          attemptNumber: n,
        ),
        'submitted' || 'scored' => PanelCell(PanelCellKind.placementSubmitted, attemptNumber: n),
        _ => const PanelCell(PanelCellKind.needsResearcher),
      };
    }

    PanelCell research(PanelStage stage) {
      if (p.unreadable) return const PanelCell(PanelCellKind.unreadable);
      if (!p.canTakeResearchStages) {
        return PanelCell(
          p.status == ResearchParticipantStatus.awaitingPlacement && !p.reviewPending
              ? PanelCellKind.waitingForBand
              : PanelCellKind.notEligible,
        );
      }
      final n = p.attempt(stage);
      final preN = p.attempt(PanelStage.preTest);
      final preDone = progressOf(PanelStage.preTest, preN)?.status == 'completed';
      if (n < 1) {
        if (stage == PanelStage.postTest && !preDone) {
          return const PanelCell(PanelCellKind.waitingForPreTest);
        }
        return const PanelCell(PanelCellKind.notAuthorized, canAuthorize: true);
      }
      // The rules refuse a pretest void or retake once the posttest is authorized.
      final retakeAllowed = stage == PanelStage.postTest || p.attempt(PanelStage.postTest) == 0;
      final mirror = progressOf(stage, n);
      return switch (mirror?.status) {
        null => PanelCell(PanelCellKind.notStarted, attemptNumber: n, total: stage.items),
        'in_progress' => PanelCell(
          PanelCellKind.inProgress,
          answered: mirror!.answered,
          total: mirror.total,
          attemptNumber: n,
          canVoidAndRetake: retakeAllowed,
        ),
        'completed' => PanelCell(PanelCellKind.completed, answered: mirror!.answered, total: mirror.total, attemptNumber: n),
        'voided' => PanelCell(PanelCellKind.voided, attemptNumber: n, canRetake: retakeAllowed),
        _ => const PanelCell(PanelCellKind.unreadable),
      };
    }

    return PanelRow(
      participant: p,
      name: roster?.name ?? '',
      cells: {
        PanelStage.placement: placement(),
        PanelStage.preTest: research(PanelStage.preTest),
        PanelStage.postTest: research(PanelStage.postTest),
      },
    );
  }
}

/// Everything the panel shows, from the operator's live reads.
class ResearchPanelData {
  ResearchPanelData({required this.study, required this.rows, required this.audit});

  final PanelStudy study;

  /// Sorted by research ID.
  final List<PanelRow> rows;

  /// Newest first.
  final List<PanelAuditEntry> audit;

  factory ResearchPanelData.combine({
    required PanelStudy study,
    required List<PanelParticipant> participants,
    required List<PanelRosterEntry> roster,
    required List<PanelProgress> progress,
    required List<PanelAuditEntry> audit,
  }) {
    final rosterByUid = {for (final r in roster) r.uid: r};
    final progressById = {for (final m in progress) m.attemptId: m};
    final rows = [
      for (final p in participants) PanelRow.derive(p, rosterByUid[p.uid], progressById),
    ]..sort((a, b) => a.participant.researchId.compareTo(b.participant.researchId));
    return ResearchPanelData(study: study, rows: rows, audit: audit);
  }

  /// Participants whose [stage] cell is [kind].
  int count(PanelStage stage, PanelCellKind kind) => rows.where((r) => r.cells[stage]!.kind == kind).length;

  /// Rows the panel can authorize for [stage] right now.
  List<PanelRow> authorizable(PanelStage stage) => rows.where((r) => r.cells[stage]!.canAuthorize).toList();
}

/// One Firestore write of a panel batch: `set` (create) or `update`.
class PanelWrite {
  const PanelWrite.set(this.path, this.data) : isSet = true;
  const PanelWrite.update(this.path, this.data) : isSet = false;

  final String path;
  final Map<String, Object?> data;
  final bool isSet;
}

/// The exact writes of every panel action (`DATA_MODEL.md` §6d), mirrored by
/// `tools/research/test/fixtures/operator_client_payloads.json`. Each batch
/// changes one thing and creates its audit entry, whose ID the rules derive
/// from the change.
abstract final class ResearchPanelWrites {
  static Map<String, Object?> _audit({
    required String action,
    required PanelStage stage,
    required String operatorUid,
    required Object serverTimestamp,
    String? targetUid,
    int? attemptNumber,
    int? seq,
    bool session4Confirmed = false,
    bool placementPolicyAcknowledged = false,
    String? reason,
  }) => {
    'action': action,
    'stage': stage.id,
    'targetUid': targetUid,
    'attemptNumber': attemptNumber,
    'seq': seq,
    'operatorUid': operatorUid,
    'at': serverTimestamp,
    'session4Confirmed': session4Confirmed,
    'placementPolicyAcknowledged': placementPolicyAcknowledged,
    'reason': reason,
  };

  /// Opens [stage] now, until [closeAt] (`null` = until closed).
  static List<PanelWrite> openStage({
    required PanelStage stage,
    required int seq,
    required String operatorUid,
    required Object serverTimestamp,
    DateTime? closeAt,
  }) => [
    PanelWrite.update('researchStudy/current', {
      'stages.${stage.id}': {
        'openAt': serverTimestamp,
        'closeAt': Timestamp.fromDate(closeAt ?? kOpenEndedStageClose),
      },
      'operatorSeq': seq,
      'updatedAt': serverTimestamp,
    }),
    PanelWrite.set(
      'researchAuditLog/study_$seq',
      _audit(action: 'open_stage', stage: stage, seq: seq, operatorUid: operatorUid, serverTimestamp: serverTimestamp),
    ),
  ];

  static List<PanelWrite> closeStage({
    required PanelStage stage,
    required int seq,
    required String operatorUid,
    required Object serverTimestamp,
  }) => [
    PanelWrite.update('researchStudy/current', {
      'stages.${stage.id}.closeAt': serverTimestamp,
      'operatorSeq': seq,
      'updatedAt': serverTimestamp,
    }),
    PanelWrite.set(
      'researchAuditLog/study_$seq',
      _audit(action: 'close_stage', stage: stage, seq: seq, operatorUid: operatorUid, serverTimestamp: serverTimestamp),
    ),
  ];

  /// First authorization of the pretest or posttest for [uid]. The
  /// placement-band acknowledgement is recorded whenever the band came from
  /// the Placement Test; the posttest records the session-4 attestation.
  static List<PanelWrite> authorize({
    required String uid,
    required PanelStage stage,
    required bool bandFromPlacement,
    required String operatorUid,
    required Object serverTimestamp,
  }) {
    assert(stage != PanelStage.placement, 'placement attempt 1 is authorized at enrolment');
    return [
      PanelWrite.update('researchParticipants/$uid', {
        'authorizedAttempts.${stage.id}': 1,
        'updatedAt': serverTimestamp,
      }),
      PanelWrite.set(
        'researchAuditLog/authorize_${stage.id}_${uid}_1',
        _audit(
          action: 'authorize',
          stage: stage,
          targetUid: uid,
          attemptNumber: 1,
          operatorUid: operatorUid,
          serverTimestamp: serverTimestamp,
          session4Confirmed: stage == PanelStage.postTest,
          placementPolicyAcknowledged: bandFromPlacement,
        ),
      ),
    ];
  }

  /// Technical interruption of attempt [n]: void it (when [voidCurrent];
  /// every answer is kept) and authorize attempt n + 1.
  static List<PanelWrite> retake({
    required String uid,
    required PanelStage stage,
    required int n,
    required bool voidCurrent,
    required String operatorUid,
    required Object serverTimestamp,
  }) {
    assert(stage != PanelStage.placement, 'placement voids stay in the research tooling');
    return [
      if (voidCurrent) ...[
        PanelWrite.update('researchAssessmentResults/${uid}_${stage.id}_$n', {
          'status': 'voided',
          'voidReason': kTechnicalInterruption,
          'voidedAt': serverTimestamp,
        }),
        PanelWrite.set(
          'researchAuditLog/void_${uid}_${stage.id}_$n',
          _audit(
            action: 'void',
            stage: stage,
            targetUid: uid,
            attemptNumber: n,
            operatorUid: operatorUid,
            serverTimestamp: serverTimestamp,
            reason: kTechnicalInterruption,
          ),
        ),
      ],
      PanelWrite.update('researchParticipants/$uid', {
        'authorizedAttempts.${stage.id}': n + 1,
        'updatedAt': serverTimestamp,
      }),
      PanelWrite.set(
        'researchAuditLog/retake_${stage.id}_${uid}_${n + 1}',
        _audit(
          action: 'retake',
          stage: stage,
          targetUid: uid,
          attemptNumber: n + 1,
          operatorUid: operatorUid,
          serverTimestamp: serverTimestamp,
          reason: kTechnicalInterruption,
        ),
      ),
    ];
  }
}

/// The student's own progress mirror (`researchProgress/{attemptId}`),
/// written after each saved write; the rules accept it only when it equals
/// the stored attempt.
abstract final class ResearchProgressMirror {
  static Map<String, Object?> forResearch(ResearchAttemptRecord a, Object serverTimestamp) => {
    'studentId': a.studentId,
    'stage': a.stage.id,
    'attemptNumber': a.attemptNumber,
    'answered': a.responses.length,
    'total': PanelStage.preTest.items,
    'status': a.status.id,
    'updatedAt': serverTimestamp,
  };

  /// Research placement attempts only (`null` for a learning attempt).
  static Map<String, Object?>? forPlacement(PlacementAttemptRecord a, Object serverTimestamp) =>
      a.context != PlacementContext.research
      ? null
      : {
          'studentId': a.studentId,
          'stage': PanelStage.placement.id,
          'attemptNumber': a.attemptNumber,
          'answered': a.answers.length,
          'total': PanelStage.placement.items,
          'status': a.status.value,
          'updatedAt': serverTimestamp,
        };
}
