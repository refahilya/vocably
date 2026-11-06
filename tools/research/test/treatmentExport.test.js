'use strict';

/**
 * Treatment-implementation export (`lib/export/treatment.js`): pure, on
 * synthetic data. Session status and evidence, make-up, completion after
 * the window, prior/parallel exposure to instrument words, and that no
 * co-write text or UID reaches the analysis files.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { buildTreatmentExport, TREATMENT_COLUMNS, periodOf } = require('../lib/export/treatment');
const { toCsv } = require('../lib/export/files');

const words = (n) => ['a', 'b', 'c', 'd', 'e'].map((x) => `w${n}${x}`);
const plan = { band: 'A2', planVersion: 't1', sessions: { 1: words(1), 2: words(2), 3: words(3), 4: words(4) } };
const T = (h) => new Date(Date.UTC(2026, 10, 10, 0, 0) + h * 3600e3).toISOString();

function set(id, n, { kind = 'regular', opening = 1, students = ['u1'], start = 0, end = 1 } = {}) {
  return { id, data: { wordIds: words(n), targetStudentIds: students, startAt: T(start), endAt: T(end), research: { planVersion: 't1', band: 'A2', session: n, kind, opening } } };
}
function session(id, n, { start, done = start + 0.5, phase = 'selesai', words: w, setId, uid = 'u1' } = {}) {
  return {
    id,
    data: {
      studentId: uid, wordIds: w || words(n), sourceType: 'targetGuru', currentPhase: phase, startedAt: T(start),
      completedAt: phase === 'selesai' ? T(done) : null,
      clozeTestResult: Object.fromEntries((w || words(n)).map((x, i) => [x, i < 3])),
      cowriteTranscript: [{ sender: 'siswa', text: 'SECRET STUDENT TEXT', usedSuggestion: true }, { sender: 'ai', text: 'bot' }, { sender: 'siswa', text: 'x', usedSuggestion: false }],
      cowriteWordsUsedCorrectly: ['w'],
      ...(n ? { targetWordSetId: setId, researchSession: n } : {}),
    },
  };
}
const entry = (sessionId, setId, kind = 'regular') => ({ sessionId, setId, kind, recordedAt: T(0) });

function build(extra = {}) {
  return buildTreatmentExport({
    planVersion: 't1',
    participants: [{ uid: 'u1', data: { researchId: 'R-1', band: 'A2', cohort: 'study', status: 'enrolled', authorizedAttempts: { preTest: 1, postTest: 1 } } }],
    plans: [plan],
    sets: [set('rt_t1_A2_s1_o1', 1, { start: 1, end: 2 }), set('rt_t1_A2_s2_o1', 2, { start: 24, end: 25, students: ['u2'] }), set('rtm_u1', 2, { kind: 'makeup', opening: 0, start: 30, end: 31 }), set('rt_t1_A2_s3_o1', 3, { start: 48, end: 49 }), set('rt_t1_A2_s4_o1', 4, { start: 72, end: 73 })],
    sessions: [
      session('ls1', 1, { start: 1.2, setId: 'rt_t1_A2_s1_o1' }),
      session('ls2', 2, { start: 30.1, setId: 'rtm_u1' }),
      session('ls3a', 3, { start: 48.1, phase: 'coWrite', setId: 'rt_t1_A2_s3_o1' }),
      session('ls3', 3, { start: 48.3, done: 49.5, setId: 'rt_t1_A2_s3_o1' }),
      session('ls4', 4, { start: 72.1, setId: 'rt_t1_A2_s4_o1' }),
      // Ordinary learning with instrument words: before the pretest, during treatment, and none.
      session('o1', null, { start: -5, words: ['w1a', 'other'] }),
      session('o2', null, { start: 40, words: ['w4b', 'w4c'] }),
      session('o3', null, { start: 41, words: ['unrelated'] }),
    ],
    records: [{ uid: 'u1', data: { sessions: { 1: entry('ls1', 'rt_t1_A2_s1_o1'), 2: entry('ls2', 'rtm_u1', 'makeup'), 3: entry('ls3', 'rt_t1_A2_s3_o1') } } }],
    attempts: [
      { id: 'u1_preTest_1', data: { status: 'completed', startedAt: T(-1), completedAt: T(-0.5) } },
      { id: 'u1_postTest_1', data: { status: 'in_progress', startedAt: T(80), completedAt: null } },
    ],
    ...extra,
  });
}

describe('treatment export', () => {
  it('one row per session with status, route, evidence counts and timing', () => {
    const { sessionRows } = build();
    assert.deepEqual(sessionRows.map((r) => [r.session, r.status, r.via]), [
      [1, 'completed', 'regular'], [2, 'completed', 'makeup'], [3, 'completed', 'regular'], [4, 'completed_unrecorded', 'regular'],
    ]);
    const s1 = sessionRows[0];
    assert.equal(s1.words, words(1).join(' '));
    assert.equal(s1.marked_present_regular, 'yes');
    assert.deepEqual([s1.cloze_correct, s1.cloze_total, s1.student_turns, s1.suggestion_turns, s1.independent_words, s1.minutes], [3, 5, 2, 1, 1, 30]);
    assert.equal(sessionRows[1].marked_present_regular, 'no', 'absent from the regular session 2');
    assert.equal(sessionRows[2].attempts, 2);
    assert.equal(sessionRows[2].completed_after_window, 'yes', 'finished 30 minutes after the set closed');
  });

  it('summary: completion criterion, make-up, late completions, and exposure', () => {
    const [s] = build().summaryRows;
    assert.equal(s.sessions_completed, 3);
    assert.equal(s.all_four_completed, 'no');
    assert.equal(s.makeup_used, 'yes');
    assert.equal(s.makeup_session, 2);
    assert.equal(s.completed_after_window_count, 1);
    assert.deepEqual([s.exposure_before_pretest_sessions, s.exposure_before_pretest_words], [1, 1]);
    assert.deepEqual([s.exposure_during_treatment_sessions, s.exposure_during_treatment_words], [1, 2]);
    const withFour = build({
      records: [{ uid: 'u1', data: { sessions: { 1: entry('ls1', 'rt_t1_A2_s1_o1'), 2: entry('ls2', 'rtm_u1', 'makeup'), 3: entry('ls3', 'rt_t1_A2_s3_o1'), 4: entry('ls4', 'rt_t1_A2_s4_o1') } } }],
    }).summaryRows[0];
    assert.equal(withFour.all_four_completed, 'yes');
    assert.equal(withFour.four_completed_before_posttest, 'yes');
  });

  it('exposure rows: ordinary sessions only, with the period', () => {
    const { exposureRows } = build();
    assert.deepEqual(exposureRows.map((r) => [r.period, r.instrument_words]), [['before_pretest', 'w1a'], ['during_treatment', 'w4b w4c']]);
    assert.equal(periodOf(T(1), null, null), 'before_pretest');
    assert.equal(periodOf(T(90), T(0), T(80)), 'after_posttest');
  });

  it('problems go to the operational file only; analysis files carry no UID or student text', () => {
    const result = build();
    assert.deepEqual(result.problems.map((p) => p.category), ['completed_unrecorded']);
    for (const [name, rows] of [['treatment_sessions.csv', result.sessionRows], ['treatment_attempts.csv', result.attemptRows], ['treatment_exposure.csv', result.exposureRows], ['treatment_summary.csv', result.summaryRows]]) {
      const csv = toCsv(TREATMENT_COLUMNS[name], rows);
      assert.ok(!csv.includes('SECRET STUDENT TEXT'), `${name}: no co-write text`);
      assert.ok(!/\bu1\b/.test(csv), `${name}: no UID`);
    }
  });

  it('cohort filter and official sessions of non-participants', () => {
    assert.equal(build({ cohort: 'pilot' }).summaryRows.length, 0);
    const stray = build({ sessions: [session('x', 1, { start: 1.2, setId: 'rt_t1_A2_s1_o1', uid: 'ghost' })] });
    assert.ok(stray.problems.some((p) => p.category === 'official_session_without_participant'));
  });
});
