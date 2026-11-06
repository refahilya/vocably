import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/learning_session.dart';
import 'package:vocably/models/research_panel.dart';
import 'package:vocably/models/research_treatment.dart';

/// Keeps the research treatment writes and the real `firestore.rules` in
/// step: the operator's session sets, the student's research learning
/// session and the completion record built here must equal
/// `tools/research/test/fixtures/treatment_client_payloads.json`, which the
/// emulator suite (`tools/research/test/rules/treatmentRules.test.js`)
/// replays against the rules. Changing either side alone fails a test.
void main() {
  const fixturePath = 'tools/research/test/fixtures/treatment_client_payloads.json';
  const ts = '__serverTimestamp__';
  final fixture = jsonDecode(File(fixturePath).readAsStringSync()) as Map<String, dynamic>;
  final batches = fixture['batches'] as Map<String, dynamic>;

  /// Fills `{{name}}` placeholders; a whole-string placeholder keeps the type
  /// (map keys always stay strings).
  Object? fill(Object? value, Map<String, Object?> vars) => switch (value) {
    final String s when RegExp(r'^\{\{\w+\}\}$').hasMatch(s) => vars[s.substring(2, s.length - 2)],
    final String s => s.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) => '${vars[m[1]]}'),
    final Map<String, dynamic> m => {for (final e in m.entries) '${fill(e.key, vars)}': fill(e.value, vars)},
    final List<dynamic> l => [for (final v in l) fill(v, vars)],
    _ => value,
  };

  Object? jsonable(Object? value) => switch (value) {
    final FieldValue _ => ts,
    final Timestamp t => {
      r'$timestampMillisFromNow': (t.toDate().difference(DateTime.now()).inMilliseconds / 60000).round() * 60000,
    },
    final Map<String, Object?> m => {for (final e in m.entries) e.key: jsonable(e.value)},
    final List<Object?> l => [for (final v in l) jsonable(v)],
    _ => value,
  };

  List<Object?> asJson(List<PanelWrite> writes) => [
    for (final w in writes) {'op': w.isSet ? 'set' : 'update', 'path': w.path, 'data': jsonable(w.data)},
  ];

  List<Object?> expected(String name, Map<String, Object?> vars) => fill(batches[name], vars) as List<Object?>;

  const words = ['wa', 'wb', 'wc', 'wd', 'we'];

  test('opening a regular session: the set (plan words, students present, 60 minutes) + its audit entry', () {
    const info = TreatmentSetInfo(
      planVersion: 't1',
      instrumentVersion: 'v1',
      band: 'B1',
      session: 2,
      kind: TreatmentSetKind.regular,
      opening: 1,
    );
    final writes = ResearchTreatmentWrites.openSession(
      info: info,
      words: words,
      studentIds: const ['s1', 's2'],
      operatorUid: 'op-1',
      serverTimestamp: ts,
      endAt: DateTime.now().add(const Duration(minutes: 60)),
    );
    expect(writes.first.path, 'targetWordSets/rt_t1_B1_s2_o1');
    expect(
      asJson(writes),
      expected('openSession', {
        'setId': 'rt_t1_B1_s2_o1',
        'operator': 'op-1',
        'words': words,
        'band': 'B1',
        'endMs': 3600000,
        'students': ['s1', 's2'],
        'planVersion': 't1',
        'instrumentVersion': 'v1',
        'session': 2,
        'kind': 'regular',
        'opening': 1,
        'action': 'open_treatment',
        'targetUid': null,
        'studentCount': 2,
      }),
    );
  });

  test('opening a make-up: one student, deterministic ID rtm_{uid}, opening 0', () {
    const info = TreatmentSetInfo(
      planVersion: 't1',
      instrumentVersion: 'v1',
      band: 'A2',
      session: 3,
      kind: TreatmentSetKind.makeup,
      opening: 0,
    );
    final writes = ResearchTreatmentWrites.openSession(
      info: info,
      words: words,
      studentIds: const ['s9'],
      operatorUid: 'op-1',
      serverTimestamp: ts,
      endAt: DateTime.now().add(const Duration(minutes: 90)),
    );
    expect(
      asJson(writes),
      expected('openSession', {
        'setId': 'rtm_s9',
        'operator': 'op-1',
        'words': words,
        'band': 'A2',
        'endMs': 5400000,
        'students': ['s9'],
        'planVersion': 't1',
        'instrumentVersion': 'v1',
        'session': 3,
        'kind': 'makeup',
        'opening': 0,
        'action': 'open_makeup',
        'targetUid': 's9',
        'studentCount': 1,
      }),
    );
  });

  test('the research learning session carries the set ID and session number', () {
    final data = LearningSession.newSessionData(
      studentId: 'stu-1',
      wordIds: words,
      sourceType: LearningSessionSourceType.targetGuru,
      storyTitle: 'Judul',
      storyContent: '[[wa|wa]]',
      storyTranslation: null,
      research: const ResearchSessionRef(setId: 'rt_t1_A2_s1_o1', session: 1, kind: TreatmentSetKind.regular, planVersion: 't1'),
    );
    final want = (expected('researchSession', {
      'uid': 'stu-1',
      'words': words,
      'title': 'Judul',
      'story': '[[wa|wa]]',
      'translation': null,
      'setId': 'rt_t1_A2_s1_o1',
      'session': 1,
    }).single as Map)['data'];
    expect(jsonable(data), want);
  });

  test('an ordinary learning session carries neither research field', () {
    final data = LearningSession.newSessionData(
      studentId: 'stu-1',
      wordIds: words,
      sourceType: LearningSessionSourceType.keranjangPelajari,
      storyTitle: 'Judul',
      storyContent: '[[wa|wa]]',
      storyTranslation: null,
    );
    expect(data.containsKey('targetWordSetId'), isFalse);
    expect(data.containsKey('researchSession'), isFalse);
  });

  test('completion record: first session creates the record, later sessions add one key', () {
    const ref = ResearchSessionRef(setId: 'rt_t1_A2_s2_o1', session: 2, kind: TreatmentSetKind.regular, planVersion: 't1');
    final vars = {'uid': 'stu-1', 'planVersion': 't1', 'session': 2, 'sessionId': 'ls-9', 'setId': 'rt_t1_A2_s2_o1', 'kind': 'regular'};
    expect(
      asJson([ResearchTreatmentWrites.recordCompletion(uid: 'stu-1', exists: false, ref: ref, sessionId: 'ls-9', serverTimestamp: ts)]),
      expected('recordCreate', vars),
    );
    expect(
      asJson([ResearchTreatmentWrites.recordCompletion(uid: 'stu-1', exists: true, ref: ref, sessionId: 'ls-9', serverTimestamp: ts)]),
      expected('recordUpdate', vars),
    );
  });
}
