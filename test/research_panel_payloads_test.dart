import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/research_panel.dart';

/// Keeps the Researcher Panel's writes and the real `firestore.rules` in
/// step: the batches built by [ResearchPanelWrites] (what
/// `ResearchPanelService` commits) must equal the checked-in fixture
/// `tools/research/test/fixtures/operator_client_payloads.json`, which the
/// emulator suite (`tools/research/test/rules/operatorRules.test.js`)
/// replays against the rules. Changing either side alone fails a test.
void main() {
  const fixturePath = 'tools/research/test/fixtures/operator_client_payloads.json';
  const ts = '__serverTimestamp__';
  final fixture = jsonDecode(File(fixturePath).readAsStringSync()) as Map<String, dynamic>;
  final batches = fixture['batches'] as Map<String, dynamic>;

  /// Fills `{{name}}` placeholders; a whole-string placeholder keeps the type.
  Object? fill(Object? value, Map<String, Object> vars) => switch (value) {
    final String s when RegExp(r'^\{\{\w+\}\}$').hasMatch(s) => vars[s.substring(2, s.length - 2)],
    final String s => s.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) => '${vars[m[1]]}'),
    final Map<String, dynamic> m => {for (final e in m.entries) fill(e.key, vars) as String: fill(e.value, vars)},
    final List<dynamic> l => [for (final v in l) fill(v, vars)],
    _ => value,
  };

  /// JSON form of a write: timestamps as `{"$timestamp": iso}`; a closeAt
  /// relative to now becomes `{"$timestampMillisFromNow": ms}` (rounded).
  Object? jsonable(Object? value, {bool relative = false}) => switch (value) {
    final Timestamp t when relative => {
      r'$timestampMillisFromNow': (t.toDate().difference(DateTime.now()).inMilliseconds / 60000).round() * 60000,
    },
    final Timestamp t => {r'$timestamp': t.toDate().toUtc().toIso8601String()},
    final Map<String, Object?> m => {for (final e in m.entries) e.key: jsonable(e.value, relative: relative)},
    final List<Object?> l => [for (final v in l) jsonable(v, relative: relative)],
    _ => value,
  };

  List<Object?> asJson(List<PanelWrite> writes, {bool relative = false}) => [
    for (final w in writes) {'op': w.isSet ? 'set' : 'update', 'path': w.path, 'data': jsonable(w.data, relative: relative)},
  ];

  List<Object?> expected(String name, Map<String, Object> vars) => fill(batches[name], vars) as List<Object?>;

  test('open-ended stage opening (closeAt = the open-ended sentinel)', () {
    expect(fixture['openEndedCloseAt'], kOpenEndedStageClose.toIso8601String());
    final writes = ResearchPanelWrites.openStage(stage: PanelStage.preTest, seq: 3, operatorUid: 'op-1', serverTimestamp: ts);
    final json = asJson(writes);
    final want = expected('openStage', {'stage': 'preTest', 'seq': 3, 'operator': 'op-1'});
    final close = ((json[0] as Map)['data'] as Map)['stages.preTest'] as Map;
    expect(close['closeAt'], {r'$timestamp': '9999-12-31T23:59:59.000Z'});
    expect(json, want);
  });

  test('timed stage opening (closeAt = now + 120 minutes, device clock)', () {
    final writes = ResearchPanelWrites.openStage(
      stage: PanelStage.placement,
      seq: 1,
      operatorUid: 'op-1',
      serverTimestamp: ts,
      closeAt: DateTime.now().add(const Duration(minutes: 120)),
    );
    expect(asJson(writes, relative: true), expected('openStageTimed', {'stage': 'placement', 'seq': 1, 'operator': 'op-1'}));
  });

  test('closing a stage', () {
    final writes = ResearchPanelWrites.closeStage(stage: PanelStage.postTest, seq: 7, operatorUid: 'op-1', serverTimestamp: ts);
    expect(asJson(writes), expected('closeStage', {'stage': 'postTest', 'seq': 7, 'operator': 'op-1'}));
  });

  test('authorizing the pretest records the placement-band acknowledgement', () {
    final writes = ResearchPanelWrites.authorize(
      uid: 'stu-1',
      stage: PanelStage.preTest,
      bandFromPlacement: true,
      operatorUid: 'op-1',
      serverTimestamp: ts,
    );
    expect(asJson(writes), expected('authorizePreTest', {'uid': 'stu-1', 'operator': 'op-1'}));
  });

  test('authorizing the posttest records the session-4 attestation', () {
    final writes = ResearchPanelWrites.authorize(
      uid: 'stu-1',
      stage: PanelStage.postTest,
      bandFromPlacement: true,
      operatorUid: 'op-1',
      serverTimestamp: ts,
    );
    expect(asJson(writes), expected('authorizePostTest', {'uid': 'stu-1', 'operator': 'op-1'}));
  });

  test('technical void + retake, and retake after an earlier void', () {
    final both = ResearchPanelWrites.retake(
      uid: 'stu-1',
      stage: PanelStage.preTest,
      n: 1,
      voidCurrent: true,
      operatorUid: 'op-1',
      serverTimestamp: ts,
    );
    expect(asJson(both), expected('voidAndRetake', {'uid': 'stu-1', 'stage': 'preTest', 'n': 1, 'next': 2, 'operator': 'op-1'}));
    final only = ResearchPanelWrites.retake(
      uid: 'stu-1',
      stage: PanelStage.postTest,
      n: 2,
      voidCurrent: false,
      operatorUid: 'op-1',
      serverTimestamp: ts,
    );
    expect(asJson(only), expected('retakeOnly', {'uid': 'stu-1', 'stage': 'postTest', 'next': 3, 'operator': 'op-1'}));
  });

  test('a void reason is always the fixed code, never free text', () {
    final writes = ResearchPanelWrites.retake(uid: 'u', stage: PanelStage.preTest, n: 1, voidCurrent: true, operatorUid: 'o', serverTimestamp: ts);
    expect(writes.first.data['voidReason'], kTechnicalInterruption);
    expect(writes.where((w) => w.path.startsWith('researchAuditLog/')).map((w) => w.data['reason']), everyElement(kTechnicalInterruption));
  });
}
