'use strict';

/**
 * Firestore security-rules tests for the research treatment
 * (`DATA_MODEL.md` §6e): the locked plan, the operator opening official
 * sessions (regular, re-opening, the one make-up and its deadline), the
 * student starting an official session (window, attendance, eligibility,
 * order), the completion record, and the posttest gate (four sessions).
 * Ordinary guru target sets and ordinary learning sessions must keep
 * working exactly as before.
 *
 * The write shapes come from `test/fixtures/treatment_client_payloads.json`,
 * which `test/research_treatment_payloads_test.dart` checks against the
 * app's builders. Words are synthetic. Runs only inside `npm run test:rules`.
 */

const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const projectId = process.env.GCLOUD_PROJECT || '';
const RUN = /^(127\.0\.0\.1|localhost):\d+$/.test(emulatorHost) && projectId.startsWith('demo-');

const REPO_ROOT = path.join(__dirname, '..', '..', '..', '..');
const payloads = require('../fixtures/treatment_client_payloads.json');
const operatorPayloads = require('../fixtures/operator_client_payloads.json');
const TS = payloads.serverTimestampMarker;

describe('research treatment rules (emulator)', { skip: !RUN && 'not inside the Firestore emulator (npm run test:rules)' }, () => {
  let rut;
  let fsdk;
  let env;

  const OP = 'opResearcher1';
  const GURU = 'guruBiasa001';
  const PLAN = 't1';
  const HOUR = 60 * 60 * 1000;
  const DAY = 24 * HOUR;

  /** Synthetic plan words: band A2 session 2 → ['wa2s2a', …]. */
  const words = (band, n) => ['a', 'b', 'c', 'd', 'e'].map((x) => `w${band.toLowerCase()}s${n}${x}`);

  const db = (uid) => (uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore());
  const trusted = (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
  const tsAgo = (ms) => fsdk.Timestamp.fromMillis(Date.now() - ms);
  const tsLater = (ms) => fsdk.Timestamp.fromMillis(Date.now() + ms);
  const regularId = (band, n, k = 1) => `rt_${PLAN}_${band}_s${n}_o${k}`;
  const makeupId = (uid) => `rtm_${uid}`;

  function materialize(v) {
    if (v === TS) return fsdk.serverTimestamp();
    if (Array.isArray(v)) return v.map(materialize);
    if (v && typeof v === 'object') {
      if ('$timestampMillisFromNow' in v) return tsLater(v.$timestampMillisFromNow);
      return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, materialize(x)]));
    }
    return v;
  }

  function fill(value, vars) {
    if (typeof value === 'string' && /^\{\{\w+\}\}$/.test(value)) return vars[value.slice(2, -2)];
    if (typeof value === 'string') return value.replace(/\{\{(\w+)\}\}/g, (_, k) => String(vars[k]));
    if (Array.isArray(value)) return value.map((x) => fill(x, vars));
    if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, x]) => [String(fill(k, vars)), fill(x, vars)]));
    return value;
  }

  /** Commits one fixture batch as [uid]; [mutate] may edit or drop a write. */
  function commit(uid, source, name, vars, mutate = (w) => w) {
    const database = db(uid);
    const batch = fsdk.writeBatch(database);
    for (const raw of source.batches[name]) {
      const w = mutate(fill(raw, vars));
      if (!w) continue;
      const [col, id] = w.path.split('/');
      const ref = fsdk.doc(database, col, id);
      if (w.op === 'set') batch.set(ref, materialize(w.data));
      else batch.update(ref, materialize(w.data));
    }
    return batch.commit();
  }

  /** The operator opens session [session] of [band] for [students] (fixture batch). */
  function openSession({ uid = OP, band = 'A2', session = 1, opening = 1, kind = 'regular', students = ['stuA2one'], endMs = HOUR, wordList, mutate } = {}) {
    const setId = kind === 'makeup' ? makeupId(students[0]) : regularId(band, session, opening);
    return commit(uid, payloads, 'openSession', {
      setId, operator: uid, words: wordList || words(band, session), band, endMs, students,
      planVersion: PLAN, instrumentVersion: 'v1', session, kind, opening: kind === 'makeup' ? 0 : opening,
      action: kind === 'makeup' ? 'open_makeup' : 'open_treatment',
      targetUid: kind === 'makeup' ? students[0] : null, studentCount: students.length,
    }, mutate);
  }

  /** The student's research learning session, created as the app creates it at the first story. */
  function startSession(uid, { setId, session, wordList, mutate = (d) => d } = {}) {
    const [raw] = payloads.batches.researchSession;
    const w = fill(raw, { uid, words: wordList, title: 'Cerita uji', story: wordList.map((x) => `[[${x}|${x}]]`).join(' '), translation: null, setId, session });
    return fsdk.addDoc(fsdk.collection(db(uid), 'learningSessions'), materialize(mutate(w.data)));
  }

  function record(uid, name, vars, mutate) {
    return commit(uid, payloads, name, { uid, planVersion: PLAN, kind: 'regular', ...vars }, mutate);
  }

  async function seedUser(uid, role = 'siswa') {
    await trusted((t) => fsdk.setDoc(fsdk.doc(t, 'users', uid), { uid, email: `${uid}@example.test`, name: uid, role, createdAt: fsdk.Timestamp.now() }));
  }

  async function seedStudy({ status = 'active', planVersion = PLAN, makeupDeadlineDays = 2 } = {}) {
    const open = { openAt: tsAgo(DAY), closeAt: tsLater(DAY) };
    await trusted((t) =>
      fsdk.setDoc(fsdk.doc(t, 'researchStudy', 'current'), {
        status, closedAt: null, updatedAt: fsdk.Timestamp.now(),
        stages: { placement: open, preTest: open, postTest: open },
        treatment: { planVersion, makeupDeadlineDays },
      })
    );
  }

  async function seedPlan() {
    await trusted(async (t) => {
      for (const band of ['A2', 'B1']) {
        const sessions = Object.fromEntries([1, 2, 3, 4].map((n) => [String(n), words(band, n)]));
        await fsdk.setDoc(fsdk.doc(t, 'researchTreatmentPlan', `${PLAN}_${band}`), {
          planVersion: PLAN, instrumentVersion: 'v1', band, bankSha256: 'x', planSha256: 'y', sessions, itemIds: sessions,
        });
      }
    });
  }

  /** Banded participant with a completed (or missing) pretest. */
  async function seedParticipant(uid, { band = 'A2', pre = 1, post = 0, preStatus = 'completed', status = 'enrolled' } = {}) {
    await seedUser(uid);
    await trusted(async (t) => {
      await fsdk.setDoc(fsdk.doc(t, 'researchParticipants', uid), {
        researchId: `R-${uid}`, band, bandSource: 'placement_test', status, exclusionReason: null,
        placementAttemptId: `${uid}_research_1`, reviewStatus: null, instrumentVersion: 'v1',
        authorizedAttempts: { placement: 1, preTest: pre, postTest: post }, cohort: 'study',
        createdAt: fsdk.Timestamp.now(), updatedAt: fsdk.Timestamp.now(),
      });
      if (pre >= 1) {
        await fsdk.setDoc(fsdk.doc(t, 'researchAssessmentResults', `${uid}_preTest_${pre}`), {
          studentId: uid, stage: 'preTest', attemptNumber: pre, band, status: preStatus,
        });
      }
    });
  }

  /** A set written by trusted setup (e.g. an older opening, a closed window). */
  async function seedSet(id, { band = 'A2', session = 1, opening = 1, kind = 'regular', students = ['stuA2one'], startAt = tsAgo(HOUR), endAt = tsLater(HOUR) } = {}) {
    await trusted((t) =>
      fsdk.setDoc(fsdk.doc(t, 'targetWordSets', id), {
        teacherId: OP, wordIds: words(band, session), cefrLevel: band, startAt, endAt, targetStudentIds: students,
        createdAt: startAt, research: { planVersion: PLAN, instrumentVersion: 'v1', band, session, kind, opening },
      })
    );
  }

  /** A completed research learning session (trusted), the evidence a record needs. */
  async function seedCompleted(uid, { id, setId, session, band = 'A2', phase = 'selesai', clozeCount = 5, transcript = 2, owner = uid } = {}) {
    const w = words(band, session);
    await trusted((t) =>
      fsdk.setDoc(fsdk.doc(t, 'learningSessions', id), {
        studentId: owner, wordIds: w, sourceType: 'targetGuru', currentPhase: phase, storyTitle: 't', storyContent: 's', storyTranslation: null,
        clozeTestResult: Object.fromEntries(w.slice(0, clozeCount).map((x) => [x, true])),
        cowriteTranscript: Array.from({ length: transcript }, (_, i) => ({ sender: i % 2 ? 'ai' : 'siswa', text: 'x', feedback: null, usedSuggestion: false })),
        cowriteWordsUsedCorrectly: [], startedAt: tsAgo(HOUR), completedAt: phase === 'selesai' ? tsAgo(1000) : null,
        targetWordSetId: setId, researchSession: session,
      })
    );
  }

  /** Records [sessions] as completed for [uid] (trusted). */
  async function seedRecord(uid, sessions) {
    await trusted((t) =>
      fsdk.setDoc(fsdk.doc(t, 'researchTreatment', uid), {
        studentId: uid, planVersion: PLAN, lastRecorded: sessions[sessions.length - 1] || 1, updatedAt: fsdk.Timestamp.now(),
        sessions: Object.fromEntries(sessions.map((n) => [String(n), { sessionId: `ls${n}`, setId: regularId('A2', n), kind: 'regular', recordedAt: fsdk.Timestamp.now() }])),
      })
    );
  }

  const getData = async (col, id) => {
    let data;
    await trusted(async (t) => {
      data = (await fsdk.getDoc(fsdk.doc(t, col, id))).data();
    });
    return data;
  };

  before(async () => {
    rut = require('@firebase/rules-unit-testing');
    fsdk = require('firebase/firestore');
    env = await rut.initializeTestEnvironment({ projectId, firestore: { rules: fs.readFileSync(path.join(REPO_ROOT, 'firestore.rules'), 'utf8') } });
  });
  after(async () => {
    await env.cleanup();
  });
  beforeEach(async () => {
    await env.clearFirestore();
    await seedUser(OP, 'guru');
    await trusted((t) => fsdk.setDoc(fsdk.doc(t, 'researchOperators', OP), { email: 'op@example.test', active: true, grantedAt: fsdk.Timestamp.now(), revokedAt: null }));
    await seedUser(GURU, 'guru');
    await seedStudy();
    await seedPlan();
    // The posttest authorization checks the band's bank document exists.
    await trusted((t) => fsdk.setDoc(fsdk.doc(t, 'researchInstrument', 'v1_A2'), { optionIds: {}, optionTexts: {} }));
    await seedParticipant('stuA2one');
    await seedParticipant('stuA2two');
    await seedParticipant('stuB1one', { band: 'B1' });
  });

  describe('plan and records: access', () => {
    it('only the operator reads the plan; nobody writes it', async () => {
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db(OP), 'researchTreatmentPlan', `${PLAN}_A2`)));
      await rut.assertSucceeds(fsdk.getDocs(fsdk.collection(db(OP), 'researchTreatmentPlan')));
      for (const uid of [GURU, 'stuA2one', null]) {
        await rut.assertFails(fsdk.getDoc(fsdk.doc(db(uid), 'researchTreatmentPlan', `${PLAN}_A2`)));
      }
      for (const uid of [OP, GURU, 'stuA2one']) {
        await rut.assertFails(fsdk.setDoc(fsdk.doc(db(uid), 'researchTreatmentPlan', `${PLAN}_A2`), { sessions: {} }));
      }
    });

    it('a student reads only their own record; the operator lists them; nobody deletes', async () => {
      await seedRecord('stuA2one', [1]);
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db('stuA2one'), 'researchTreatment', 'stuA2one')));
      await rut.assertFails(fsdk.getDoc(fsdk.doc(db('stuA2two'), 'researchTreatment', 'stuA2one')));
      await rut.assertFails(fsdk.getDocs(fsdk.collection(db('stuA2one'), 'researchTreatment')));
      await rut.assertFails(fsdk.getDocs(fsdk.collection(db(GURU), 'researchTreatment')));
      await rut.assertSucceeds(fsdk.getDocs(fsdk.collection(db(OP), 'researchTreatment')));
      await rut.assertFails(fsdk.deleteDoc(fsdk.doc(db('stuA2one'), 'researchTreatment', 'stuA2one')));
    });
  });

  describe('operator opens official sessions', () => {
    it('session 1 for the students present, with its audit entry', async () => {
      await rut.assertSucceeds(openSession({ students: ['stuA2one', 'stuA2two'] }));
      const set = await getData('targetWordSets', regularId('A2', 1));
      assert.deepEqual(set.wordIds, words('A2', 1));
      assert.deepEqual(set.targetStudentIds, ['stuA2one', 'stuA2two']);
      const log = await getData('researchAuditLog', `tset_${regularId('A2', 1)}`);
      assert.equal(log.supervisionConfirmed, true);
      assert.equal(log.studentCount, 2);
      // Students can read it (the ordinary target-word query).
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db('stuA2one'), 'targetWordSets', regularId('A2', 1))));
    });

    it('in plan order, with the plan words, for one band, time-boxed, never for everyone', async () => {
      await rut.assertFails(openSession({ session: 2 }), 'session 2 before session 1');
      await rut.assertFails(openSession({ wordList: words('A2', 2) }), 'words of another session');
      await rut.assertFails(openSession({ wordList: [...words('A2', 1)].reverse() }), 'plan order');
      await rut.assertFails(openSession({ wordList: words('A2', 1).slice(0, 4) }), 'four words');
      await rut.assertFails(openSession({ endMs: 5 * HOUR }), 'longer than 4 hours');
      await rut.assertFails(openSession({ students: ['__all__'] }), 'every student');
      await rut.assertFails(openSession({ mutate: (w) => (w.path.startsWith('targetWordSets') ? { ...w, data: { ...w.data, cefrLevel: 'B1' } } : w) }));
      await rut.assertFails(openSession({ mutate: (w) => (w.path.startsWith('targetWordSets') ? { ...w, data: { ...w.data, startAt: { $timestampMillisFromNow: -HOUR } } } : w) }), 'starts now');
      await rut.assertFails(openSession({ mutate: (w) => (w.path.startsWith('targetWordSets') ? { ...w, path: `targetWordSets/${regularId('A2', 1, 2)}` } : w) }), 'ID must match the opening');
      await rut.assertSucceeds(openSession());
      await rut.assertSucceeds(openSession({ session: 2 }));
    });

    it('the audit entry is required, bound to the set, and attests supervision', async () => {
      await rut.assertFails(openSession({ mutate: (w) => (w.path.startsWith('researchAuditLog') ? null : w) }));
      await rut.assertFails(openSession({ mutate: (w) => (w.path.startsWith('researchAuditLog') ? { ...w, data: { ...w.data, supervisionConfirmed: false } } : w) }));
      await rut.assertFails(openSession({ mutate: (w) => (w.path.startsWith('researchAuditLog') ? { ...w, data: { ...w.data, studentCount: 5 } } : w) }));
      await rut.assertFails(openSession({ mutate: (w) => (w.path.startsWith('researchAuditLog') ? { ...w, data: { ...w.data, session: 2 } } : w) }));
      // An entry alone, without its set, is refused too.
      await rut.assertFails(openSession({ mutate: (w) => (w.path.startsWith('targetWordSets') ? null : w) }));
    });

    it('needs an active study with this plan; ordinary guru accounts cannot open sessions', async () => {
      await rut.assertFails(openSession({ uid: GURU }));
      await seedStudy({ planVersion: 't2' });
      await rut.assertFails(openSession());
      await seedStudy({ status: 'closed' });
      await rut.assertFails(openSession());
    });

    it('a re-opening only within 12 hours of the first opening, in sequence', async () => {
      await rut.assertSucceeds(openSession());
      await rut.assertFails(openSession({ opening: 3 }), 'opening 3 before 2');
      await rut.assertSucceeds(openSession({ opening: 2, students: ['stuA2two'] }));
      await env.clearFirestore();
      await seedUser(OP, 'guru');
      await trusted((t) => fsdk.setDoc(fsdk.doc(t, 'researchOperators', OP), { email: 'op@example.test', active: true, grantedAt: fsdk.Timestamp.now(), revokedAt: null }));
      await seedStudy();
      await seedPlan();
      await seedSet(regularId('A2', 1), { startAt: tsAgo(13 * HOUR), endAt: tsAgo(12 * HOUR) });
      await rut.assertFails(openSession({ opening: 2 }), 'more than 12 hours later');
    });

    it('ordinary guru target sets still work, but never with research IDs or a research map', async () => {
      const plain = { teacherId: GURU, wordIds: ['apple'], cefrLevel: 'A1', startAt: fsdk.Timestamp.now(), endAt: tsLater(DAY), targetStudentIds: ['__all__'], createdAt: fsdk.serverTimestamp() };
      await rut.assertSucceeds(fsdk.addDoc(fsdk.collection(db(GURU), 'targetWordSets'), plain));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db(GURU), 'targetWordSets', regularId('A2', 1)), plain));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db(GURU), 'targetWordSets', makeupId('stuA2one')), plain));
      await rut.assertFails(fsdk.addDoc(fsdk.collection(db(GURU), 'targetWordSets'), { ...plain, research: { planVersion: PLAN } }));
      await rut.assertFails(fsdk.addDoc(fsdk.collection(db('stuA2one'), 'targetWordSets'), { ...plain, teacherId: 'stuA2one' }));
      // Sets are never updated or deleted, research or not.
      await rut.assertSucceeds(openSession());
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(db(OP), 'targetWordSets', regularId('A2', 1)), { endAt: tsLater(DAY) }));
      await rut.assertFails(fsdk.deleteDoc(fsdk.doc(db(OP), 'targetWordSets', regularId('A2', 1))));
    });
  });

  describe('make-up', () => {
    beforeEach(async () => {
      // Session 1 of A2 was held earlier today and is closed.
      await seedSet(regularId('A2', 1), { startAt: tsAgo(3 * HOUR), endAt: tsAgo(2 * HOUR), students: ['stuA2two'] });
    });

    it('one make-up per student, for an opened session, for that student only', async () => {
      await rut.assertSucceeds(openSession({ kind: 'makeup', session: 1, students: ['stuA2one'] }));
      const log = await getData('researchAuditLog', `tset_${makeupId('stuA2one')}`);
      assert.equal(log.targetUid, 'stuA2one');
      // Never a second one, for any session.
      await rut.assertFails(openSession({ kind: 'makeup', session: 1, students: ['stuA2one'] }));
      await seedSet(regularId('A2', 2), { session: 2, startAt: tsAgo(HOUR), endAt: tsAgo(1000) });
      await rut.assertFails(openSession({ kind: 'makeup', session: 2, students: ['stuA2one'] }));
    });

    it('refused for a session never opened, two students, another band, or a session already recorded', async () => {
      await rut.assertFails(openSession({ kind: 'makeup', session: 2, students: ['stuA2one'] }));
      await rut.assertFails(openSession({ kind: 'makeup', session: 1, students: ['stuA2one', 'stuA2two'] }));
      await rut.assertFails(openSession({ kind: 'makeup', session: 1, band: 'A2', students: ['stuB1one'] }));
      await seedRecord('stuA2two', [1]);
      await rut.assertFails(openSession({ kind: 'makeup', session: 1, students: ['stuA2two'] }));
    });

    it('must close before the deadline (days after the first opening closed, from the study)', async () => {
      await seedSet(regularId('A2', 1), { startAt: tsAgo(3 * DAY), endAt: tsAgo(2 * DAY + HOUR / 2) });
      await rut.assertFails(openSession({ kind: 'makeup', session: 1, students: ['stuA2one'] }), 'past the 2-day deadline');
      await seedStudy({ makeupDeadlineDays: 3 });
      await rut.assertSucceeds(openSession({ kind: 'makeup', session: 1, students: ['stuA2one'] }));
    });
  });

  describe('student starts an official session', () => {
    beforeEach(async () => {
      await rut.assertSucceeds(openSession({ students: ['stuA2one'] }));
    });
    const s1 = () => ({ setId: regularId('A2', 1), session: 1, wordList: words('A2', 1) });

    it('a student marked present, eligible, while the session is open', async () => {
      await rut.assertSucceeds(startSession('stuA2one', s1()));
      // Starting again (a new attempt; there is no resume) is allowed too while open.
      await rut.assertSucceeds(startSession('stuA2one', s1()));
    });

    it('refused when not marked present, outside the window, or with other words or numbers', async () => {
      await rut.assertFails(startSession('stuA2two', s1()), 'not marked present');
      await rut.assertFails(startSession('stuA2one', { ...s1(), wordList: words('A2', 2) }));
      await rut.assertFails(startSession('stuA2one', { ...s1(), session: 2 }));
      await rut.assertFails(startSession('stuA2one', { ...s1(), mutate: (d) => ({ ...d, sourceType: 'keranjangPelajari' }) }));
      await rut.assertFails(startSession('stuA2one', { ...s1(), mutate: (d) => { const { researchSession, ...rest } = d; return rest; } }));
      await seedSet(regularId('A2', 1), { students: ['stuA2one'], startAt: tsAgo(2 * HOUR), endAt: tsAgo(1000) });
      await rut.assertFails(startSession('stuA2one', s1()), 'window closed');
    });

    it('refused when not eligible: pretest not completed, posttest authorized, other band, excluded, not a participant', async () => {
      await seedParticipant('stuA2one', { preStatus: 'in_progress' });
      await rut.assertFails(startSession('stuA2one', s1()));
      await seedParticipant('stuA2one', { post: 1 });
      await rut.assertFails(startSession('stuA2one', s1()));
      await seedParticipant('stuA2one', { band: 'B1' });
      await rut.assertFails(startSession('stuA2one', s1()));
      await seedParticipant('stuA2one', { status: 'excluded' });
      await rut.assertFails(startSession('stuA2one', s1()));
      await seedSet(regularId('A2', 1), { students: ['nonParticipant'] });
      await seedUser('nonParticipant');
      await rut.assertFails(startSession('nonParticipant', s1()));
    });

    it('refused once the session is recorded', async () => {
      await seedRecord('stuA2one', [1]);
      await rut.assertFails(startSession('stuA2one', s1()));
    });

    it('in order: at most one missed session while the make-up is unused, none beyond the make-up', async () => {
      const at = (n) => ({ setId: regularId('A2', n), session: n, wordList: words('A2', n) });
      for (const n of [2, 3, 4]) await seedSet(regularId('A2', n), { session: n, students: ['stuA2one'] });
      await rut.assertSucceeds(startSession('stuA2one', at(2)), 'session 1 missed: allowed (make-up pending)');
      await rut.assertFails(startSession('stuA2one', at(3)), 'sessions 1 and 2 missed');
      await seedRecord('stuA2one', [1]);
      await rut.assertSucceeds(startSession('stuA2one', at(3)), 'only session 2 missed');
      await rut.assertFails(startSession('stuA2one', at(4)), 'sessions 2 and 3 missed');
      // Once the make-up is used for session 2, every other earlier session must be done.
      await seedSet(makeupId('stuA2one'), { session: 2, kind: 'makeup', opening: 0, students: ['stuA2one'] });
      await rut.assertSucceeds(startSession('stuA2one', at(3)));
      await rut.assertFails(startSession('stuA2one', at(4)), 'session 3 also missing');
      await seedRecord('stuA2one', [1, 3]);
      await rut.assertSucceeds(startSession('stuA2one', at(4)), 'only the make-up session is outstanding');
    });

    it('the make-up session itself starts out of order, for its student only', async () => {
      await seedSet(regularId('A2', 2), { session: 2, students: ['stuA2one'] });
      await seedRecord('stuA2one', [2]);
      await seedSet(makeupId('stuA2one'), { session: 1, kind: 'makeup', opening: 0, students: ['stuA2one'] });
      await rut.assertSucceeds(startSession('stuA2one', { setId: makeupId('stuA2one'), session: 1, wordList: words('A2', 1) }));
      await rut.assertFails(startSession('stuA2two', { setId: makeupId('stuA2one'), session: 1, wordList: words('A2', 1) }));
    });

    it('ordinary sessions are unchanged, and research fields can never be added or changed later', async () => {
      const ordinary = (d) => { const { targetWordSetId, researchSession, ...rest } = d; return rest; };
      const plain = await startSession('stuA2two', { ...s1(), mutate: ordinary });
      await rut.assertFails(fsdk.updateDoc(plain, { researchSession: 1, targetWordSetId: regularId('A2', 1) }));
      const research = await startSession('stuA2one', s1());
      await rut.assertFails(fsdk.updateDoc(research, { researchSession: 2 }));
      await rut.assertFails(fsdk.updateDoc(research, { targetWordSetId: 'other' }));
      // The ordinary phase updates still work on a research session.
      await rut.assertSucceeds(fsdk.updateDoc(research, { currentPhase: 'clozeTest' }));
    });
  });

  describe('completion record', () => {
    const vars = (n, id) => ({ session: n, sessionId: id, setId: regularId('A2', n) });

    beforeEach(async () => {
      await seedSet(regularId('A2', 1), { students: ['stuA2one'] });
      await seedSet(regularId('A2', 2), { session: 2, students: ['stuA2one'] });
      await seedCompleted('stuA2one', { id: 'ls1', setId: regularId('A2', 1), session: 1 });
      await seedCompleted('stuA2one', { id: 'ls2', setId: regularId('A2', 2), session: 2 });
    });

    it('one completed official session per write', async () => {
      await rut.assertSucceeds(record('stuA2one', 'recordCreate', vars(1, 'ls1')));
      await rut.assertSucceeds(record('stuA2one', 'recordUpdate', vars(2, 'ls2')));
      const r = await getData('researchTreatment', 'stuA2one');
      assert.deepEqual(Object.keys(r.sessions).sort(), ['1', '2']);
      assert.equal(r.lastRecorded, 2);
    });

    it('refused without complete evidence', async () => {
      await seedCompleted('stuA2one', { id: 'lsOpen', setId: regularId('A2', 1), session: 1, phase: 'coWrite' });
      await rut.assertFails(record('stuA2one', 'recordCreate', vars(1, 'lsOpen')), 'not completed');
      await seedCompleted('stuA2one', { id: 'lsCloze', setId: regularId('A2', 1), session: 1, clozeCount: 4 });
      await rut.assertFails(record('stuA2one', 'recordCreate', vars(1, 'lsCloze')), 'cloze for every word');
      await seedCompleted('stuA2one', { id: 'lsChat', setId: regularId('A2', 1), session: 1, transcript: 0 });
      await rut.assertFails(record('stuA2one', 'recordCreate', vars(1, 'lsChat')), 'co-write transcript');
      await seedCompleted('stuA2one', { id: 'lsOther', setId: regularId('A2', 1), session: 1, owner: 'stuA2two' });
      await rut.assertFails(record('stuA2one', 'recordCreate', vars(1, 'lsOther')), "someone else's session");
      await rut.assertFails(record('stuA2one', 'recordCreate', vars(2, 'ls1')), 'session number differs');
      await rut.assertFails(record('stuA2one', 'recordCreate', { ...vars(1, 'ls1'), kind: 'makeup' }), 'kind differs');
      await rut.assertFails(record('stuA2two', 'recordCreate', { ...vars(1, 'ls1'), uid: 'stuA2one' }), "another student's record");
      // An ordinary learning session is never evidence.
      await trusted((t) => fsdk.setDoc(fsdk.doc(t, 'learningSessions', 'lsPlain'), { studentId: 'stuA2one', wordIds: words('A2', 1), currentPhase: 'selesai', completedAt: fsdk.Timestamp.now(), clozeTestResult: {}, cowriteTranscript: [] }));
      await rut.assertFails(record('stuA2one', 'recordCreate', vars(1, 'lsPlain')));
    });

    it('recorded sessions never change or disappear', async () => {
      await rut.assertSucceeds(record('stuA2one', 'recordCreate', vars(1, 'ls1')));
      await rut.assertFails(record('stuA2one', 'recordUpdate', vars(1, 'ls1')), 'same session again');
      const ref = fsdk.doc(db('stuA2one'), 'researchTreatment', 'stuA2one');
      await rut.assertFails(fsdk.updateDoc(ref, { 'sessions.1.sessionId': 'ls2', updatedAt: fsdk.serverTimestamp() }));
      await rut.assertFails(fsdk.updateDoc(ref, { sessions: {}, lastRecorded: 1, updatedAt: fsdk.serverTimestamp() }));
      await rut.assertFails(record('stuA2one', 'recordUpdate', vars(2, 'ls2'), (w) => ({ ...w, data: { ...w.data, studentId: 'x' } })));
    });
  });

  describe('end to end: open → start → complete → record (client writes only)', () => {
    it('follows the app path and the record lands', async () => {
      await rut.assertSucceeds(openSession({ students: ['stuA2one'] }));
      const w = words('A2', 1);
      const ref = await startSession('stuA2one', { setId: regularId('A2', 1), session: 1, wordList: w });
      await rut.assertSucceeds(fsdk.updateDoc(ref, { currentPhase: 'clozeTest' }));
      await rut.assertSucceeds(fsdk.updateDoc(ref, { clozeTestResult: Object.fromEntries(w.map((x, i) => [x, i % 2 === 0])), currentPhase: 'coWrite' }));
      const transcript = [{ sender: 'siswa', text: 'x', feedback: null, usedSuggestion: false }, { sender: 'ai', text: 'y', feedback: null, usedSuggestion: false }];
      await rut.assertSucceeds(fsdk.updateDoc(ref, { cowriteTranscript: transcript }));
      await rut.assertSucceeds(fsdk.updateDoc(ref, { cowriteTranscript: transcript, cowriteWordsUsedCorrectly: [w[0]], currentPhase: 'selesai', completedAt: fsdk.serverTimestamp() }));
      await rut.assertSucceeds(record('stuA2one', 'recordCreate', vars1(ref.id)));
    });
    const vars1 = (id) => ({ session: 1, sessionId: id, setId: regularId('A2', 1) });
  });

  describe('posttest gate', () => {
    const authorizePost = (uid) =>
      commit(OP, operatorPayloads, 'authorizePostTest', { uid, operator: OP });

    it('the operator authorizes the posttest only with all four sessions recorded', async () => {
      await rut.assertFails(authorizePost('stuA2one'), 'no record');
      await seedRecord('stuA2one', [1, 2, 3]);
      await rut.assertFails(authorizePost('stuA2one'), 'three sessions');
      await seedRecord('stuA2one', [1, 2, 3, 4]);
      await rut.assertSucceeds(authorizePost('stuA2one'));
    });
  });
});
