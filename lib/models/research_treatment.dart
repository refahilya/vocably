import 'package:cloud_firestore/cloud_firestore.dart';

import 'research_panel.dart' show PanelWrite;

/// Research treatment (`DATA_MODEL.md` §6e): per band, the 20
/// pretest/posttest words in [kTreatmentSessions] sessions of
/// [kTreatmentWordsPerSession], randomized once by the research tooling and
/// locked (`researchTreatmentPlan/{planVersion}_{band}`).
const int kTreatmentSessions = 4;
const int kTreatmentWordsPerSession = 5;

/// Default make-up deadline when `researchStudy/current.treatment` has none
/// (the rules use the same default).
const int kDefaultMakeupDeadlineDays = 2;

/// A re-opening of a session is accepted only this long after its first
/// opening (the rules enforce the same limit).
const Duration kTreatmentReopenLimit = Duration(hours: 12);

enum TreatmentSetKind {
  regular('regular'),
  makeup('makeup');

  const TreatmentSetKind(this.id);

  final String id;

  static TreatmentSetKind? fromId(Object? id) {
    for (final k in values) {
      if (k.id == id) return k;
    }
    return null;
  }
}

/// Deterministic document IDs the rules derive and check.
abstract final class TreatmentIds {
  static String regularSet(String planVersion, String band, int session, int opening) =>
      'rt_${planVersion}_${band}_s${session}_o$opening';

  /// One make-up per student, ever.
  static String makeupSet(String uid) => 'rtm_$uid';

  static String audit(String setId) => 'tset_$setId';
}

/// The `research` map of an official session set (`targetWordSets`).
class TreatmentSetInfo {
  const TreatmentSetInfo({
    required this.planVersion,
    required this.instrumentVersion,
    required this.band,
    required this.session,
    required this.kind,
    required this.opening,
  });

  final String planVersion;
  final String instrumentVersion;
  final String band;

  /// 1..[kTreatmentSessions].
  final int session;
  final TreatmentSetKind kind;

  /// Regular: 1 for the first opening, 2.. for a re-opening. Make-up: 0.
  final int opening;

  /// `null` when [data] is not a well-formed `research` map.
  static TreatmentSetInfo? fromMap(Object? data) {
    if (data is! Map) return null;
    final kind = TreatmentSetKind.fromId(data['kind']);
    final session = data['session'];
    final opening = data['opening'];
    final planVersion = data['planVersion'];
    final instrumentVersion = data['instrumentVersion'];
    final band = data['band'];
    if (kind == null ||
        session is! int ||
        opening is! int ||
        planVersion is! String ||
        instrumentVersion is! String ||
        band is! String) {
      return null;
    }
    return TreatmentSetInfo(
      planVersion: planVersion,
      instrumentVersion: instrumentVersion,
      band: band,
      session: session,
      kind: kind,
      opening: opening,
    );
  }

  Map<String, Object?> toMap() => {
    'planVersion': planVersion,
    'instrumentVersion': instrumentVersion,
    'band': band,
    'session': session,
    'kind': kind.id,
    'opening': opening,
  };
}

/// The official session a learning flow belongs to (`learningSessions`
/// fields `targetWordSetId` + `researchSession`).
class ResearchSessionRef {
  const ResearchSessionRef({required this.setId, required this.session, required this.kind, required this.planVersion});

  final String setId;
  final int session;
  final TreatmentSetKind kind;
  final String planVersion;
}

/// One band of the locked plan, as the operator reads it.
class TreatmentPlanBand {
  const TreatmentPlanBand({
    required this.planVersion,
    required this.instrumentVersion,
    required this.band,
    required this.sessions,
  });

  final String planVersion;
  final String instrumentVersion;
  final String band;

  /// Session number → its five words, in plan order.
  final Map<int, List<String>> sessions;

  static TreatmentPlanBand? fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['sessions'];
    final planVersion = data['planVersion'];
    final instrumentVersion = data['instrumentVersion'];
    final band = data['band'];
    if (raw is! Map || planVersion is! String || instrumentVersion is! String || band is! String) return null;
    final sessions = <int, List<String>>{};
    for (final entry in raw.entries) {
      final n = int.tryParse('${entry.key}');
      final words = entry.value;
      if (n == null || words is! List) return null;
      sessions[n] = [for (final w in words) '$w'];
    }
    return TreatmentPlanBand(
      planVersion: planVersion,
      instrumentVersion: instrumentVersion,
      band: band,
      sessions: sessions,
    );
  }
}

/// One recorded session in `researchTreatment/{uid}.sessions`.
class TreatmentRecordEntry {
  const TreatmentRecordEntry({required this.sessionId, required this.setId, required this.kind});

  final String sessionId;
  final String setId;
  final TreatmentSetKind? kind;
}

/// `researchTreatment/{uid}`: the official sessions this student completed.
class TreatmentRecord {
  const TreatmentRecord({required this.uid, required this.sessions});

  final String uid;
  final Map<int, TreatmentRecordEntry> sessions;

  static const empty = TreatmentRecord(uid: '', sessions: {});

  Set<int> get done => sessions.keys.toSet();
  bool get complete => done.length >= kTreatmentSessions;

  factory TreatmentRecord.fromFirestore(String uid, Map<String, dynamic>? data) {
    final raw = data?['sessions'];
    final sessions = <int, TreatmentRecordEntry>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final n = int.tryParse('${entry.key}');
        final e = entry.value;
        if (n == null || e is! Map) continue;
        sessions[n] = TreatmentRecordEntry(
          sessionId: '${e['sessionId'] ?? ''}',
          setId: '${e['setId'] ?? ''}',
          kind: TreatmentSetKind.fromId(e['kind']),
        );
      }
    }
    return TreatmentRecord(uid: uid, sessions: sessions);
  }
}

/// The exact writes of the research treatment (`DATA_MODEL.md` §6e),
/// mirrored by `tools/research/test/fixtures/treatment_client_payloads.json`
/// (checked by `test/research_treatment_payloads_test.dart`, replayed
/// against the rules by `tools/research/test/rules/treatmentRules.test.js`).
abstract final class ResearchTreatmentWrites {
  /// The set ID [info] must have (the rules derive the same).
  static String setIdFor(TreatmentSetInfo info, List<String> studentIds) => info.kind == TreatmentSetKind.makeup
      ? TreatmentIds.makeupSet(studentIds.single)
      : TreatmentIds.regularSet(info.planVersion, info.band, info.session, info.opening);

  /// Opens an official session now, until [endAt], for the students marked
  /// present ([studentIds]; for a make-up exactly one student), with the
  /// plan's [words] for that session, and its audit entry (supervision
  /// attested).
  static List<PanelWrite> openSession({
    required TreatmentSetInfo info,
    required List<String> words,
    required List<String> studentIds,
    required String operatorUid,
    required Object serverTimestamp,
    required DateTime endAt,
  }) {
    assert(info.kind == TreatmentSetKind.regular || studentIds.length == 1, 'a make-up is for one student');
    final setId = setIdFor(info, studentIds);
    return [
      PanelWrite.set('targetWordSets/$setId', {
        'teacherId': operatorUid,
        'wordIds': words,
        'cefrLevel': info.band,
        'startAt': serverTimestamp,
        'endAt': Timestamp.fromDate(endAt),
        'targetStudentIds': studentIds,
        'createdAt': serverTimestamp,
        'research': info.toMap(),
      }),
      PanelWrite.set('researchAuditLog/${TreatmentIds.audit(setId)}', {
        'action': info.kind == TreatmentSetKind.makeup ? 'open_makeup' : 'open_treatment',
        'setId': setId,
        'band': info.band,
        'session': info.session,
        'kind': info.kind.id,
        'targetUid': info.kind == TreatmentSetKind.makeup ? studentIds.single : null,
        'studentCount': studentIds.length,
        'supervisionConfirmed': true,
        'operatorUid': operatorUid,
        'at': serverTimestamp,
      }),
    ];
  }

  /// The student's completion record for official session [ref], completed
  /// as learning session [sessionId]. [exists] = the record document
  /// already exists (then one session key is added).
  static PanelWrite recordCompletion({
    required String uid,
    required bool exists,
    required ResearchSessionRef ref,
    required String sessionId,
    required Object serverTimestamp,
  }) {
    final entry = {
      'sessionId': sessionId,
      'setId': ref.setId,
      'kind': ref.kind.id,
      'recordedAt': serverTimestamp,
    };
    return exists
        ? PanelWrite.update('researchTreatment/$uid', {
            'sessions.${ref.session}': entry,
            'lastRecorded': ref.session,
            'updatedAt': serverTimestamp,
          })
        : PanelWrite.set('researchTreatment/$uid', {
            'studentId': uid,
            'planVersion': ref.planVersion,
            'sessions': {'${ref.session}': entry},
            'lastRecorded': ref.session,
            'updatedAt': serverTimestamp,
          });
  }
}
