import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/learning_session.dart';
import 'package:vocably/models/research_treatment.dart';
import 'package:vocably/models/target_word_set.dart';
import 'package:vocably/services/research_treatment_service.dart';

/// Parsing of the research treatment documents (`DATA_MODEL.md` §6e) and
/// the choice of completions the dashboard records later.
void main() {
  final ts = Timestamp.fromDate(DateTime(2026, 11, 3, 8));

  test('a research set parses its research map; an ordinary set has none', () {
    final base = {
      'teacherId': 'op',
      'wordIds': ['wa'],
      'cefrLevel': 'B1',
      'startAt': ts,
      'endAt': ts,
      'targetStudentIds': ['s1'],
      'createdAt': ts,
    };
    final research = TargetWordSet.fromFirestore('rt_t1_B1_s2_o1', {
      ...base,
      'research': {'planVersion': 't1', 'instrumentVersion': 'v1', 'band': 'B1', 'session': 2, 'kind': 'regular', 'opening': 1},
    });
    expect([research.isResearch, research.research!.session, research.research!.kind], [true, 2, TreatmentSetKind.regular]);
    expect(TargetWordSet.fromFirestore('set-1', base).isResearch, isFalse);
    // A malformed map is not treated as research.
    expect(TargetWordSet.fromFirestore('x', {...base, 'research': {'session': 'two'}}).isResearch, isFalse);
  });

  test('deterministic IDs match the rules', () {
    expect(TreatmentIds.regularSet('t1', 'A2', 3, 2), 'rt_t1_A2_s3_o2');
    expect(TreatmentIds.makeupSet('uid9'), 'rtm_uid9');
    expect(TreatmentIds.audit('rtm_uid9'), 'tset_rtm_uid9');
  });

  test('plan and record documents parse; unknown keys are skipped', () {
    final plan = TreatmentPlanBand.fromFirestore({
      'planVersion': 't1',
      'instrumentVersion': 'v1',
      'band': 'C1',
      'sessions': {'1': ['a', 'b'], '2': ['c']},
    })!;
    expect(plan.sessions, {1: ['a', 'b'], 2: ['c']});
    expect(TreatmentPlanBand.fromFirestore(null), isNull);
    final record = TreatmentRecord.fromFirestore('s1', {
      'sessions': {
        '1': {'sessionId': 'ls1', 'setId': 'rt', 'kind': 'regular'},
        '3': {'sessionId': 'ls3', 'setId': 'rtm_s1', 'kind': 'makeup'},
        'x': {'sessionId': 'bad'},
      },
    });
    expect(record.done, {1, 3});
    expect(record.sessions[3]!.kind, TreatmentSetKind.makeup);
    expect(record.complete, isFalse);
  });

  LearningSession session(String id, {int? n, String phase = LearningSessionPhase.selesai, DateTime? completedAt}) =>
      LearningSession.fromFirestore(id, {
        'studentId': 's1',
        'wordIds': ['wa'],
        'sourceType': LearningSessionSourceType.targetGuru,
        'currentPhase': phase,
        'storyTitle': 't',
        'storyContent': 'c',
        'startedAt': ts,
        'completedAt': completedAt == null ? null : Timestamp.fromDate(completedAt),
        if (n != null) 'targetWordSetId': 'rt_t1_B1_s${n}_o1',
        'researchSession': ?n,
      });

  test('learning sessions read their research fields; ordinary ones have none', () {
    expect(session('a', n: 2).isResearchSession, isTrue);
    expect(session('a', n: 2).targetWordSetId, 'rt_t1_B1_s2_o1');
    expect(session('b').isResearchSession, isFalse);
  });

  test('completions to record later: completed official sessions not recorded, earliest per number', () {
    final sessions = [
      session('plain', completedAt: DateTime(2026, 11, 3, 9)),
      session('s2-late', n: 2, completedAt: DateTime(2026, 11, 5, 9)),
      session('s2-early', n: 2, completedAt: DateTime(2026, 11, 4, 9)),
      session('s1', n: 1, completedAt: DateTime(2026, 11, 3, 9)),
      session('s3-open', n: 3, phase: LearningSessionPhase.coWrite),
    ];
    expect(unrecordedCompleted(sessions, {}).map((s) => s.id), ['s1', 's2-early']);
    expect(unrecordedCompleted(sessions, {1}).map((s) => s.id), ['s2-early']);
    expect(unrecordedCompleted(sessions, {1, 2}), isEmpty);
  });
}
