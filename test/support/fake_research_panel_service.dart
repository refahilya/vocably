import 'dart:async';

import 'package:vocably/models/research_panel.dart';
import 'package:vocably/models/research_participant.dart';
import 'package:vocably/models/research_study.dart';
import 'package:vocably/models/research_treatment.dart';
import 'package:vocably/services/research_assessment_service.dart';
import 'package:vocably/services/research_panel_service.dart';

/// In-memory Researcher Panel backend. Streams re-emit after every change,
/// like Firestore listeners; actions apply the change the rules would
/// accept (the rules themselves are tested against the emulator in
/// `tools/research/test/rules/operatorRules.test.js`).
class FakeResearchPanelService extends ResearchPanelService {
  FakeResearchPanelService({
    this.operators = const {'researcher-1'},
    PanelStudy? study,
    List<PanelParticipant>? participants,
    List<PanelRosterEntry>? roster,
    List<PanelProgress>? progress,
    List<TreatmentPlanBand>? plans,
    List<PanelTreatmentSet>? treatmentSets,
    List<TreatmentRecord>? records,
  }) : study = study ?? activeStudy(),
       participants = participants ?? [],
       roster = roster ?? [],
       progress = progress ?? [],
       plans = plans ?? [],
       treatmentSets = treatmentSets ?? [],
       records = records ?? [];

  Set<String> operators;
  PanelStudy study;
  List<PanelParticipant> participants;
  List<PanelRosterEntry> roster;
  List<PanelProgress> progress;
  List<TreatmentPlanBand> plans;
  List<PanelTreatmentSet> treatmentSets;
  List<TreatmentRecord> records;
  final audit = <PanelAuditEntry>[];

  /// Every action, e.g. `open:preTest:60`, `authorize:uid:postTest`, `retake:uid:preTest:void`.
  final calls = <String>[];

  /// When set, the next action throws this failure.
  ResearchFailureKind? failNext;

  final _changes = StreamController<void>.broadcast();

  void changed() => _changes.add(null);

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<bool> watchOperator(String uid) => _live(() => operators.contains(uid));

  @override
  Stream<PanelStudy> watchStudy() => _live(() => study);

  @override
  Stream<List<PanelParticipant>> watchParticipants() => _live(() => List.of(participants));

  @override
  Stream<List<PanelRosterEntry>> watchRoster() => _live(() => List.of(roster));

  @override
  Stream<List<PanelProgress>> watchProgress() => _live(() => List.of(progress));

  @override
  Stream<List<PanelAuditEntry>> watchAudit({int limit = 12}) => _live(() => audit.reversed.take(limit).toList());

  @override
  Stream<List<TreatmentPlanBand>> watchTreatmentPlans() => _live(() => List.of(plans));

  @override
  Stream<List<PanelTreatmentSet>> watchTreatmentSets() => _live(() => List.of(treatmentSets));

  @override
  Stream<List<TreatmentRecord>> watchTreatmentRecords() => _live(() => List.of(records));

  /// `treat:<band>:<session>:<opening>:<uids>:<minutes>`.
  @override
  Future<void> openTreatmentSession({
    required String operatorUid,
    required TreatmentSetInfo info,
    required List<String> words,
    required List<String> studentIds,
    required Duration duration,
  }) async {
    _maybeFail();
    calls.add('treat:${info.band}:${info.session}:${info.kind == TreatmentSetKind.makeup ? 'makeup' : info.opening}:${studentIds.join(',')}:${duration.inMinutes}');
    final now = DateTime.now();
    treatmentSets = [
      ...treatmentSets,
      PanelTreatmentSet(
        id: ResearchTreatmentWrites.setIdFor(info, studentIds),
        info: info,
        wordIds: words,
        studentIds: studentIds,
        startAt: now.subtract(const Duration(seconds: 1)),
        endAt: now.add(duration),
      ),
    ];
    audit.add(
      PanelAuditEntry(
        id: '${audit.length}',
        action: info.kind == TreatmentSetKind.makeup ? 'open_makeup' : 'open_treatment',
        stage: null,
        targetUid: info.kind == TreatmentSetKind.makeup ? studentIds.single : null,
        attemptNumber: null,
        at: DateTime(2026, 11, 2, 8, audit.length),
        session: info.session,
        band: info.band,
        studentCount: studentIds.length,
      ),
    );
    changed();
  }

  void _maybeFail() {
    final kind = failNext;
    if (kind != null) {
      failNext = null;
      throw ResearchServiceException(kind, 'fake failure');
    }
  }

  void _log(String action, PanelStage stage, {String? uid, int? n}) {
    audit.add(
      PanelAuditEntry(id: '${audit.length}', action: action, stage: stage, targetUid: uid, attemptNumber: n, at: DateTime(2026, 11, 2, 8, audit.length)),
    );
  }

  @override
  Future<void> openStage({required String operatorUid, required PanelStage stage, Duration? duration}) async {
    _maybeFail();
    calls.add('open:${stage.id}:${duration?.inMinutes ?? 'open-ended'}');
    final now = DateTime.now();
    study = PanelStudy(
      exists: true,
      status: study.status,
      operatorSeq: study.operatorSeq + 1,
      windows: {...study.windows, stage: PanelWindow(openAt: now.subtract(const Duration(seconds: 1)), closeAt: duration == null ? kOpenEndedStageClose : now.add(duration))},
    );
    _log('open_stage', stage);
    changed();
  }

  @override
  Future<void> closeStage({required String operatorUid, required PanelStage stage}) async {
    _maybeFail();
    calls.add('close:${stage.id}');
    final w = study.windows[stage]!;
    study = PanelStudy(
      exists: true,
      status: study.status,
      operatorSeq: study.operatorSeq + 1,
      windows: {...study.windows, stage: PanelWindow(openAt: w.openAt, closeAt: DateTime.now().subtract(const Duration(seconds: 1)))},
    );
    _log('close_stage', stage);
    changed();
  }

  void _setAttempt(String uid, PanelStage stage, int n) {
    participants = [
      for (final p in participants)
        p.uid == uid
            ? PanelParticipant(
                uid: p.uid,
                researchId: p.researchId,
                cohort: p.cohort,
                status: p.status,
                band: p.band,
                bandSource: p.bandSource,
                exclusionReason: p.exclusionReason,
                reviewPending: p.reviewPending,
                authorized: {...p.authorized, stage: n},
              )
            : p,
    ];
  }

  @override
  Future<void> authorize({required String operatorUid, required PanelRow row, required PanelStage stage}) async {
    _maybeFail();
    calls.add('authorize:${row.uid}:${stage.id}');
    _setAttempt(row.uid, stage, 1);
    _log('authorize', stage, uid: row.uid, n: 1);
    changed();
  }

  @override
  Future<void> retake({
    required String operatorUid,
    required PanelRow row,
    required PanelStage stage,
    required bool voidCurrent,
  }) async {
    _maybeFail();
    calls.add('retake:${row.uid}:${stage.id}:${voidCurrent ? 'void' : 'only'}');
    final n = row.participant.attempt(stage);
    if (voidCurrent) _log('void', stage, uid: row.uid, n: n);
    _setAttempt(row.uid, stage, n + 1);
    _log('retake', stage, uid: row.uid, n: n + 1);
    changed();
  }
}

/// An active study; [open] stages have a window that is open now. The
/// treatment plan `t1` is active unless [treatmentPlanVersion] says otherwise.
PanelStudy activeStudy({
  Set<PanelStage> open = const {},
  ResearchStudyStatus status = ResearchStudyStatus.active,
  String? treatmentPlanVersion = 't1',
}) {
  final now = DateTime.now();
  return PanelStudy(
    exists: true,
    status: status,
    operatorSeq: 0,
    windows: {
      for (final s in open) s: PanelWindow(openAt: now.subtract(const Duration(hours: 1)), closeAt: kOpenEndedStageClose),
    },
    treatmentPlanVersion: treatmentPlanVersion,
  );
}

/// Synthetic plan words for [band] session [n].
List<String> planWords(String band, int n) => [for (final x in 'abcde'.split('')) 'w${band.toLowerCase()}s$n$x'];

/// The locked plan `t1` for [band] (synthetic words).
TreatmentPlanBand panelPlan(String band) => TreatmentPlanBand(
  planVersion: 't1',
  instrumentVersion: 'v1',
  band: band,
  sessions: {for (var n = 1; n <= 4; n++) n: planWords(band, n)},
);

/// A regular session set of [band] (or a make-up for [students].single).
PanelTreatmentSet panelSet(
  String band,
  int session, {
  int opening = 1,
  bool makeup = false,
  List<String> students = const [],
  DateTime? startAt,
  DateTime? endAt,
}) {
  final info = TreatmentSetInfo(
    planVersion: 't1',
    instrumentVersion: 'v1',
    band: band,
    session: session,
    kind: makeup ? TreatmentSetKind.makeup : TreatmentSetKind.regular,
    opening: makeup ? 0 : opening,
  );
  final now = DateTime.now();
  return PanelTreatmentSet(
    id: ResearchTreatmentWrites.setIdFor(info, students.isEmpty ? const ['x'] : students),
    info: info,
    wordIds: planWords(band, session),
    studentIds: students,
    startAt: startAt ?? now.subtract(const Duration(minutes: 30)),
    endAt: endAt ?? now.add(const Duration(minutes: 30)),
  );
}

/// [uid]'s completion record with [sessions] recorded.
TreatmentRecord panelRecord(String uid, Set<int> sessions) => TreatmentRecord(
  uid: uid,
  sessions: {
    for (final n in sessions) n: TreatmentRecordEntry(sessionId: 'ls$n', setId: 'rt_t1_B1_s${n}_o1', kind: TreatmentSetKind.regular),
  },
);

/// A participant record as the operator reads it.
PanelParticipant panelParticipant(
  String uid, {
  String? researchId,
  ResearchParticipantStatus status = ResearchParticipantStatus.enrolled,
  String? band = 'B1',
  String? bandSource = 'placement_test',
  int placement = 1,
  int pre = 0,
  int post = 0,
  bool reviewPending = false,
}) => PanelParticipant(
  uid: uid,
  researchId: researchId ?? 'R-$uid',
  cohort: 'study',
  status: status,
  band: status == ResearchParticipantStatus.awaitingPlacement ? null : band,
  bandSource: status == ResearchParticipantStatus.awaitingPlacement ? null : bandSource,
  exclusionReason: null,
  reviewPending: reviewPending,
  authorized: {PanelStage.placement: placement, PanelStage.preTest: pre, PanelStage.postTest: post},
);

PanelProgress panelProgress(String uid, PanelStage stage, {int n = 1, int answered = 0, String status = 'in_progress'}) => PanelProgress(
  attemptId: PanelProgress.attemptIdFor(uid, stage, n),
  studentId: uid,
  stage: stage,
  attemptNumber: n,
  answered: answered,
  total: stage.items,
  status: status,
);
