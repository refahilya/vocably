'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { validateKey, buildExport } = require('../lib/export/scoring');
const { exportFiles } = require('../lib/export/files');
const { bank, bankSha256, syntheticKey, attempt, participant, itemsOf, wrongOption } = require('./researchFixtures');

const key = syntheticKey();
const run = (participants, attempts, opts = {}) => buildExport({ bank, key, participants, attempts, ...opts });
const pair = (result, rid) => result.pairedRows.find((r) => r.research_id === rid);
const exclusionsOf = (result, rid) => result.exclusions.filter((e) => e.research_id === rid);

test('validateKey accepts the matching (synthetic) key', () => {
  assert.deepEqual(validateKey(key, bank, bankSha256), []);
});

test('validateKey rejects version, bank-hash, item, band and text mismatches without revealing key values', () => {
  const entries = key.entries.map((e) => ({ ...e }));
  entries[0].correctOptionText = 'changed';
  entries[1].band = 'C1';
  entries[2].correctOptionId = 'dont_know';
  const broken = { ...key, instrumentVersion: 'v2', bankSha256: '0'.repeat(64), entries: entries.slice(0, 79) };
  const problems = validateKey(broken, bank, bankSha256);
  assert.ok(problems.some((p) => /instrumentVersion/.test(p)));
  assert.ok(problems.some((p) => /bankSha256/.test(p)));
  assert.ok(problems.some((p) => /A2-01: key option text/.test(p)));
  assert.ok(problems.some((p) => /A2-02: key band/.test(p)));
  assert.ok(problems.some((p) => /A2-03: key points to the "tidak tahu"/.test(p)));
  assert.ok(problems.some((p) => /C1-20: no key entry/.test(p)));
  for (const p of problems) {
    for (const item of bank.items) for (const o of item.options) assert.ok(!p.includes(o.text) || o.text.length < 4, 'no option text in messages');
  }
  assert.deepEqual(validateKey({}, bank, bankSha256), ['the key file has no entries list']);
});

test('scores a complete pair: B counts, gain, percentages and N-gain', () => {
  const r = run(
    [participant({ uid: 'u1', researchId: 'S1', band: 'B1' })],
    [attempt({ uid: 'u1', band: 'B1', correct: 6, dontKnow: 3 }), attempt({ uid: 'u1', band: 'B1', stage: 'postTest', correct: 13, dontKnow: 1, startedAt: '2026-10-24T01:00:00.000Z' })]
  );
  assert.deepEqual(pair(r, 'S1'), {
    research_id: 'S1', band: 'B1', cohort: 'study', pre_score: 6, post_score: 13, gain: 7, pre_percent: 30, post_percent: 65,
    n_gain: '0.5000', n_gain_note: '', pre_dont_know: 3, post_dont_know: 1,
  });
  const preRow = r.attemptRows.find((a) => a.stage === 'preTest');
  assert.equal(preRow.count_B, 6);
  assert.equal(preRow.count_T, 3);
  assert.equal(preRow.count_S, 11);
  assert.equal(preRow.count_K, 0);
  assert.equal(r.itemRows.filter((i) => i.stage === 'preTest').length, 20);
  assert.equal(r.itemRows.filter((i) => i.code === 'B' && i.stage === 'preTest').length, 6);
  assert.ok(r.itemRows.every((i) => i.score === (i.code === 'B' ? 1 : 0)));
});

test('a negative gain is kept, and N-gain may be negative', () => {
  const r = run(
    [participant({ uid: 'u3', researchId: 'S3', band: 'B2' })],
    [attempt({ uid: 'u3', band: 'B2', correct: 10 }), attempt({ uid: 'u3', band: 'B2', stage: 'postTest', correct: 9, startedAt: '2026-10-24T01:00:00.000Z' })]
  );
  assert.equal(pair(r, 'S3').gain, -1);
  assert.equal(pair(r, 'S3').n_gain, '-0.1000');
});

test('N-gain is not computed (blank, with a note) when pre = 20 — never 0 or infinity', () => {
  const r = run(
    [participant({ uid: 'u4', researchId: 'S4' })],
    [attempt({ uid: 'u4', correct: 20 }), attempt({ uid: 'u4', stage: 'postTest', correct: 20, startedAt: '2026-10-24T01:00:00.000Z' })]
  );
  assert.equal(pair(r, 'S4').n_gain, '');
  assert.equal(pair(r, 'S4').n_gain_note, 'not computed: pre = 20');
  assert.equal(pair(r, 'S4').gain, 0);
  assert.equal(r.summary.nGainNotComputed, 1);
});

test('an incomplete or missing stage excludes the pair, with the reason', () => {
  const r = run(
    [participant({ uid: 'u5', researchId: 'S5' }), participant({ uid: 'u6', researchId: 'S6', post: 0 })],
    [
      attempt({ uid: 'u5', correct: 5 }),
      attempt({ uid: 'u5', stage: 'postTest', status: 'in_progress', answered: 12, correct: 4, startedAt: '2026-10-24T01:00:00.000Z' }),
      attempt({ uid: 'u6', correct: 7 }),
    ]
  );
  assert.equal(r.pairedRows.length, 0);
  const postRow = r.attemptRows.find((a) => a.research_id === 'S5' && a.stage === 'postTest');
  assert.equal(postRow.included_in_scoring, 'no');
  assert.equal(postRow.exclusion_reason, 'incomplete');
  assert.equal(postRow.score, '', 'no score for an excluded attempt');
  assert.equal(postRow.count_K, 8);
  assert.deepEqual(exclusionsOf(r, 'S5').map((e) => [e.stage, e.reason]), [['postTest', 'incomplete'], ['pair', 'excluded_from_paired_analysis']]);
  assert.deepEqual(exclusionsOf(r, 'S6').map((e) => [e.stage, e.reason]), [['postTest', 'no_attempt'], ['pair', 'excluded_from_paired_analysis']]);
  assert.match(exclusionsOf(r, 'S6')[1].detail, /no valid completed posttest/);
  assert.equal(r.itemRows.filter((i) => i.research_id === 'S5' && i.stage === 'postTest').length, 0);
});

test('a retake after a void scores the authorized attempt and lists the voided one', () => {
  const r = run(
    [participant({ uid: 'u7', researchId: 'S7', pre: 2 })],
    [
      attempt({ uid: 'u7', n: 1, status: 'voided', answered: 4, extra: { voidReason: 'listrik padam', voidedAt: '2026-10-20T01:30:00.000Z' } }),
      attempt({ uid: 'u7', n: 2, correct: 8, startedAt: '2026-10-21T01:00:00.000Z' }),
      attempt({ uid: 'u7', stage: 'postTest', correct: 12, startedAt: '2026-10-24T01:00:00.000Z' }),
    ]
  );
  assert.equal(pair(r, 'S7').pre_score, 8);
  const voided = r.attemptRows.find((a) => a.attempt_number === 1);
  assert.equal(voided.exclusion_reason, 'voided');
  assert.equal(voided.score, '');
  assert.deepEqual(r.voidRows.map((v) => [v.research_id, v.uid, v.attempt_number, v.void_reason]), [['S7', 'u7', 1, 'listrik padam']]);
});

test('never chooses between conflicting attempts', () => {
  const r = run(
    [participant({ uid: 'u8', researchId: 'S8', pre: 2 })],
    [attempt({ uid: 'u8', n: 1, status: 'in_progress', answered: 5 }), attempt({ uid: 'u8', n: 2, correct: 9 }), attempt({ uid: 'u8', stage: 'postTest', correct: 9, startedAt: '2026-10-24T01:00:00.000Z' })]
  );
  assert.equal(r.pairedRows.length, 0);
  assert.equal(exclusionsOf(r, 'S8')[0].reason, 'conflicting_attempts');
  assert.ok(r.attemptRows.filter((a) => a.stage === 'preTest').every((a) => a.included_in_scoring === 'no'));
});

test('invalid authorization states are excluded', () => {
  const r = run(
    [participant({ uid: 'u9', researchId: 'S9', pre: 1 }), participant({ uid: 'u10', researchId: 'S10', pre: 2 })],
    [
      attempt({ uid: 'u9', n: 1, status: 'voided' }),
      attempt({ uid: 'u9', n: 2, correct: 3 }),
      attempt({ uid: 'u10', n: 1, correct: 3 }),
    ]
  );
  assert.equal(exclusionsOf(r, 'S9')[0].reason, 'invalid_authorization_state');
  assert.equal(exclusionsOf(r, 'S10')[0].reason, 'attempt_not_currently_authorized');
});

test('structurally invalid records are excluded, never repaired', () => {
  const a2 = itemsOf('A2');
  const base = () => attempt({ uid: 'x', correct: 2 });
  const cases = {
    wrongText: (d) => { const id = d.itemOrder[0]; d.responses[id] = { ...d.responses[id], optionText: 'Teks lain' }; },
    wrongPosition: (d) => { const id = d.itemOrder[5]; d.responses[id] = { ...d.responses[id], displayPosition: d.responses[id].displayPosition % 4 + 1 }; },
    foreignOption: (d) => { const id = d.itemOrder[3]; const other = wrongOption(itemsOf('B1')[0]); d.responses[id] = { ...d.responses[id], optionId: other.id }; },
    unexpectedItem: (d) => { d.responses['B1-01'] = d.responses[d.itemOrder[0]]; },
    badDontKnow: (d) => { d.responses[d.itemOrder[19]] = { optionId: 'dont_know', optionText: 'tidak tahu', displayPosition: 5 }; },
    missingAnswer: (d) => { delete d.responses[d.itemOrder[19]]; },
    bandMismatch: (d) => { d.band = 'B1'; },
    versionMismatch: (d) => { d.instrumentVersion = 'v2'; },
    shortItemOrder: (d) => { d.itemOrder = d.itemOrder.slice(1); },
    badOptionOrder: (d) => { d.optionOrder[d.itemOrder[0]] = [a2[0].options[0].id]; },
  };
  for (const [name, mutate] of Object.entries(cases)) {
    const a = base();
    mutate(a.data);
    const r = run([participant({ uid: 'x', researchId: 'SX', post: 0 })], [a]);
    assert.equal(exclusionsOf(r, 'SX')[0].reason, 'invalid_record', name);
    assert.equal(r.attemptRows[0].included_in_scoring, 'no', name);
  }
});

test('a posttest started before the pretest was completed is excluded from pairing', () => {
  const r = run(
    [participant({ uid: 'u11', researchId: 'S11' })],
    [attempt({ uid: 'u11', correct: 4, startedAt: '2026-10-22T01:00:00.000Z' }), attempt({ uid: 'u11', stage: 'postTest', correct: 9, startedAt: '2026-10-22T01:30:00.000Z' })]
  );
  assert.equal(r.pairedRows.length, 0);
  assert.equal(exclusionsOf(r, 'S11')[0].reason, 'posttest_before_pretest');
});

test('duplicate research IDs, orphan attempts and mismatched IDs become operational problems', () => {
  const r = run(
    [participant({ uid: 'u12', researchId: 'DUP' }), participant({ uid: 'u13', researchId: 'DUP' })],
    [attempt({ uid: 'ghost' }), { id: 'u12_preTest_1', data: { ...attempt({ uid: 'u13' }).data } }]
  );
  assert.equal(r.summary.participants, 0);
  const categories = r.problems.map((p) => p.category).sort();
  assert.deepEqual(categories, ['attempt_id_mismatch', 'duplicate_or_missing_research_id', 'duplicate_or_missing_research_id', 'orphan_attempt']);
});

test('a participant on another instrument version is left out with a problem, not mis-scored', () => {
  const p = participant({ uid: 'u16', researchId: 'S16' });
  p.data.instrumentVersion = 'v2';
  const r = run([p], [attempt({ uid: 'u16', extra: { instrumentVersion: 'v2' } })]);
  assert.equal(r.summary.participants, 0);
  assert.deepEqual(r.problems.map((x) => x.category), ['instrument_version_mismatch']);
  assert.equal(r.attemptRows.length, 0);
});

test('the cohort filter keeps only that cohort', () => {
  const r = run(
    [participant({ uid: 'u14', researchId: 'S14' }), participant({ uid: 'u15', researchId: 'P15', cohort: 'pilot' })],
    [attempt({ uid: 'u14' }), attempt({ uid: 'u15' })],
    { cohort: 'pilot' }
  );
  assert.deepEqual(r.identifiers.map((i) => i.research_id), ['P15']);
});

test('analysis files carry research IDs only; UIDs appear only in operational files', () => {
  const r = run(
    [participant({ uid: 'secretUid123', researchId: 'S20' })],
    [attempt({ uid: 'secretUid123', correct: 3 }), attempt({ uid: 'secretUid123', stage: 'postTest', correct: 5, startedAt: '2026-10-24T01:00:00.000Z' })]
  );
  const files = exportFiles(r);
  for (const [name, text] of Object.entries(files)) {
    if (name.startsWith('analysis_')) assert.ok(!text.includes('secretUid123'), name);
  }
  assert.ok(files['operational_identifiers.csv'].includes('S20,secretUid123'));
  assert.equal(files['analysis_paired.csv'].split('\r\n')[0], 'research_id,band,cohort,pre_score,post_score,gain,pre_percent,post_percent,n_gain,n_gain_note,pre_dont_know,post_dont_know');
});
