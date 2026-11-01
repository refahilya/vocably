'use strict';

/**
 * Firestore security-rules tests for the Placement Test (PT-V1.1) and the
 * study lifecycle: pending-band participants, research vs learning
 * attempts, in-rules K2 scoring, the participant band write, stage windows
 * and closure.
 *
 * Runs ONLY inside `firebase emulators:exec` started by
 * `bin/run_rules_tests.js` (demo project, local emulator); skipped
 * otherwise. The key used here is SYNTHETIC (letter by item number), never
 * the real key, which these tests never read.
 */

const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const projectId = process.env.GCLOUD_PROJECT || '';
const RUN = /^(127\.0\.0\.1|localhost):\d+$/.test(emulatorHost) && projectId.startsWith('demo-');

const { decide } = require('../../lib/placement/scoring');
const { PLACEMENT_BANDS } = require('../../lib/placement/constants');

const REPO_ROOT = path.join(__dirname, '..', '..', '..', '..');
const bank = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'assets', 'placement', 'placement_bank_pt_v1_1.json'), 'utf8'));
const VERSION = bank.instrumentVersion;
const LETTERS = ['A', 'B', 'C', 'D'];
const syntheticKeyOf = (item) => LETTERS[item.number % 4];
const wrongOf = (item) => LETTERS[(item.number + 1) % 4];
const itemsOf = (band) => bank.items.filter((i) => i.band === band);
const DAY = 24 * 60 * 60 * 1000;

describe('placement Firestore rules (emulator)', { skip: !RUN && 'not inside the Firestore emulator (npm run test:rules)' }, () => {
  let rut;
  let fsdk;
  let env;

  const db = (uid) => (uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore());
  const trusted = (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
  const ago = (ms) => fsdk.Timestamp.fromMillis(Date.now() - ms);
  const later = (ms) => fsdk.Timestamp.fromMillis(Date.now() + ms);

  /** Band order fixed, items reversed within each band (a stand-in for the shuffle). */
  const itemOrder = () => PLACEMENT_BANDS.flatMap((b) => itemsOf(b).map((i) => i.id).reverse());

  /** Answers giving exactly band scores [s] under the synthetic key (rest wrong or E). */
  function answersFor(s) {
    const answers = {};
    PLACEMENT_BANDS.forEach((band, b) => {
      itemsOf(band).forEach((item, i) => {
        answers[item.id] = i < s[b] ? syntheticKeyOf(item) : i % 2 ? 'E' : wrongOf(item);
      });
    });
    return answers;
  }

  async function seedBase({ learningOpen = false, study = 'active', placementOpen = true, preTestOpen = true } = {}) {
    await trusted(async (t) => {
      const bandItems = Object.fromEntries(PLACEMENT_BANDS.map((b) => [b, itemsOf(b).map((i) => i.id)]));
      const key = Object.fromEntries(PLACEMENT_BANDS.map((b) => [b, Object.fromEntries(itemsOf(b).map((i) => [i.id, syntheticKeyOf(i)]))]));
      await fsdk.setDoc(fsdk.doc(t, 'placementInstrument', VERSION), { instrumentVersion: VERSION, bankSha256: 'x', bandItems });
      await fsdk.setDoc(fsdk.doc(t, 'placementKey', VERSION), { instrumentVersion: VERSION, bankSha256: 'x', key });
      await fsdk.setDoc(fsdk.doc(t, 'placementConfig', 'current'), { instrumentVersion: VERSION, bankSha256: 'x', scoringPolicy: 'K2', learningOpen });
      const win = (open) => (open ? { openAt: ago(DAY), closeAt: later(DAY) } : { openAt: ago(2 * DAY), closeAt: ago(DAY) });
      await fsdk.setDoc(fsdk.doc(t, 'researchStudy', 'current'), {
        status: study,
        closedAt: null,
        stages: { placement: win(placementOpen), preTest: win(preTestOpen), postTest: win(false) },
      });
    });
  }

  async function seedUser(uid) {
    await trusted((t) =>
      fsdk.setDoc(fsdk.doc(t, 'users', uid), {
        uid, email: `${uid}@example.test`, name: uid, role: 'siswa', createdAt: fsdk.Timestamp.now(),
        cefrLevel: null, placementTestCompleted: false, placementTestPrompted: true,
      })
    );
  }

  /** A participant enrolled WITHOUT a band, awaiting the placement test. */
  async function seedPending(uid, extra = {}) {
    await seedUser(uid);
    await trusted((t) =>
      fsdk.setDoc(fsdk.doc(t, 'researchParticipants', uid), {
        researchId: `R-${uid}`, band: null, bandSource: null, status: 'awaiting_placement', exclusionReason: null,
        placementAttemptId: null, reviewStatus: null, instrumentVersion: 'v1',
        authorizedAttempts: { placement: 1, preTest: 0, postTest: 0 }, cohort: 'test',
        createdAt: fsdk.Timestamp.now(), updatedAt: fsdk.Timestamp.now(), ...extra,
      })
    );
  }

  function newAttempt(uid, { context = 'research', n = 1, ...overrides } = {}) {
    return {
      studentId: uid, context, attemptNumber: n, instrumentVersion: VERSION, itemOrder: itemOrder(),
      answers: {}, lastAnsweredItemId: null, tabSwitchCount: 0, status: 'in_progress',
      startedAt: fsdk.serverTimestamp(), updatedAt: fsdk.serverTimestamp(), ...overrides,
    };
  }

  const aid = (uid, context = 'research', n = 1) => `${uid}_${context}_${n}`;
  const attemptRef = (database, id) => fsdk.doc(database, 'placementAttempts', id);

  const saveAnswer = (database, id, itemId, letter) =>
    fsdk.updateDoc(attemptRef(database, id), new fsdk.FieldPath('answers', itemId), letter, 'lastAnsweredItemId', itemId, 'updatedAt', fsdk.serverTimestamp());

  const submit = (database, id) =>
    fsdk.updateDoc(attemptRef(database, id), { status: 'submitted', submittedAt: fsdk.serverTimestamp(), updatedAt: fsdk.serverTimestamp() });

  /** A submitted attempt written by trusted setup (answers for band scores [s]). */
  async function seedSubmitted(uid, s, { context = 'research', n = 1, extra = {} } = {}) {
    const doc = {
      ...newAttempt(uid, { context, n }), answers: answersFor(s), lastAnsweredItemId: itemOrder()[49],
      status: 'submitted', startedAt: ago(3600e3), updatedAt: ago(1000), submittedAt: ago(1000), ...extra,
    };
    await trusted((t) => fsdk.setDoc(attemptRef(t, aid(uid, context, n)), doc));
    return aid(uid, context, n);
  }

  function resultOf(s) {
    const d = decide(s);
    return { resultLevel: d.resultLevel, belowA1Threshold: d.belowA1Threshold, pretestTargetBand: d.pretestTargetBand };
  }

  /** The client's scoring batch: attempt result + users level (+ participant band for research). */
  function scoreBatch(uid, id, result, { context = 'research', participant, user } = {}) {
    const database = db(uid);
    const batch = fsdk.writeBatch(database);
    batch.update(attemptRef(database, id), {
      status: 'scored', ...result, scoringPolicy: 'K2', scoredAt: fsdk.serverTimestamp(), updatedAt: fsdk.serverTimestamp(),
    });
    if (user !== false) {
      batch.update(fsdk.doc(database, 'users', uid), {
        resultLevel: result.resultLevel, resultAttemptId: id, placementTestCompleted: true, ...(user || {}),
      });
    }
    if (context === 'research' && participant !== false) {
      const band = result.pretestTargetBand;
      batch.update(fsdk.doc(database, 'researchParticipants', uid), {
        band,
        bandSource: band ? 'placement_test' : null,
        status: band ? 'enrolled' : 'excluded',
        exclusionReason: band ? null : 'placement_c1',
        placementAttemptId: id,
        updatedAt: fsdk.serverTimestamp(),
        ...(participant || {}),
      });
    }
    return batch.commit();
  }

  const readTrusted = async (col, id) => {
    let data;
    await trusted(async (t) => { data = (await fsdk.getDoc(fsdk.doc(t, col, id))).data(); });
    return data;
  };

  before(async () => {
    rut = require('@firebase/rules-unit-testing');
    fsdk = require('firebase/firestore');
    const [host, port] = emulatorHost.split(':');
    env = await rut.initializeTestEnvironment({
      projectId,
      firestore: { rules: fs.readFileSync(path.join(REPO_ROOT, 'firestore.rules'), 'utf8'), host, port: Number(port) },
    });
  });
  after(async () => { if (env) await env.cleanup(); });
  beforeEach(async () => { await env.clearFirestore(); });

  // ---------------------------------------------------------------------
  describe('configuration and trusted documents', () => {
    it('signed-in users can read the config and study, never the key, instrument or reviews', async () => {
      await seedBase();
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db('u1'), 'placementConfig', 'current')));
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db('u1'), 'researchStudy', 'current')));
      await rut.assertFails(fsdk.getDoc(fsdk.doc(db(), 'placementConfig', 'current')));
      for (const [col, id] of [['placementKey', VERSION], ['placementInstrument', VERSION], ['researchReviews', 'x']]) {
        await rut.assertFails(fsdk.getDoc(fsdk.doc(db('u1'), col, id)));
        await rut.assertFails(fsdk.setDoc(fsdk.doc(db('u1'), col, id), { x: 1 }));
      }
      await rut.assertFails(fsdk.getDocs(fsdk.collection(db('u1'), 'placementKey')));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('u1'), 'placementConfig', 'current'), { learningOpen: true }));
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(db('u1'), 'researchStudy', 'current'), { status: 'closed' }));
    });
  });

  // ---------------------------------------------------------------------
  describe('pending-band participant', () => {
    it('is not a usable research record: no pretest, no posttest, no self-assigned band', async () => {
      await seedBase();
      await seedPending('p1', { authorizedAttempts: { placement: 1, preTest: 1, postTest: 1 } });
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('p1'), 'researchAssessmentResults', 'p1_preTest_1'), { studentId: 'p1', stage: 'preTest' }));
      const ref = fsdk.doc(db('p1'), 'researchParticipants', 'p1');
      await rut.assertFails(fsdk.updateDoc(ref, { band: 'B1', bandSource: 'placement_test', status: 'enrolled', updatedAt: fsdk.serverTimestamp() }));
      await rut.assertFails(fsdk.updateDoc(ref, { 'authorizedAttempts.placement': 2 }));
      await rut.assertFails(fsdk.updateDoc(ref, { reviewStatus: null, status: 'excluded' }));
    });

    it('a non-participant cannot create a research attempt, and an ordinary user cannot create a participant', async () => {
      await seedBase();
      await seedUser('u1');
      await rut.assertFails(fsdk.setDoc(attemptRef(db('u1'), aid('u1')), newAttempt('u1')));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('u1'), 'researchParticipants', 'u1'), { status: 'awaiting_placement', band: null }));
    });
  });

  // ---------------------------------------------------------------------
  describe('research attempt: create, answer, submit', () => {
    it('creates the authorized attempt with a per-band shuffled order', async () => {
      await seedBase();
      await seedPending('p1');
      await rut.assertSucceeds(fsdk.setDoc(attemptRef(db('p1'), aid('p1')), newAttempt('p1')));
    });

    it('rejects a wrong order, number, ID, version, pre-filled answers or client timestamps', async () => {
      await seedBase();
      await seedPending('p1');
      const crossBand = itemOrder();
      [crossBand[9], crossBand[10]] = [crossBand[10], crossBand[9]];
      const short = itemOrder().slice(0, 49);
      const dup = itemOrder();
      dup[1] = dup[0];
      const bad = [
        newAttempt('p1', { itemOrder: crossBand }),
        newAttempt('p1', { itemOrder: short }),
        newAttempt('p1', { itemOrder: dup }),
        newAttempt('p1', { instrumentVersion: 'PT-V1.0' }),
        newAttempt('p1', { answers: { [itemOrder()[0]]: 'A' } }),
        newAttempt('p1', { status: 'submitted' }),
        newAttempt('p1', { startedAt: fsdk.Timestamp.now() }),
        newAttempt('p1', { tabSwitchCount: 3 }),
        newAttempt('p1', { resultLevel: 'C1' }),
        newAttempt('p1', { studentId: 'other' }),
      ];
      for (const doc of bad) await rut.assertFails(fsdk.setDoc(attemptRef(db('p1'), aid('p1')), doc));
      await rut.assertFails(fsdk.setDoc(attemptRef(db('p1'), aid('p1', 'research', 2)), newAttempt('p1', { n: 2 })));
      await rut.assertFails(fsdk.setDoc(attemptRef(db('p1'), 'p1_research'), newAttempt('p1')));
    });

    it('is refused while the placement window is closed, the study is not active, or a review is pending', async () => {
      await seedBase({ placementOpen: false });
      await seedPending('p1');
      await rut.assertFails(fsdk.setDoc(attemptRef(db('p1'), aid('p1')), newAttempt('p1')));
      await seedBase({ study: 'setup' });
      await rut.assertFails(fsdk.setDoc(attemptRef(db('p1'), aid('p1')), newAttempt('p1')));
      await seedBase();
      await seedPending('p2', { reviewStatus: 'pending' });
      await rut.assertFails(fsdk.setDoc(attemptRef(db('p2'), aid('p2')), newAttempt('p2')));
    });

    it('answers can be saved and changed (A–E) one item at a time; invalid writes are refused', async () => {
      await seedBase();
      await seedPending('p1');
      const id = aid('p1');
      await rut.assertSucceeds(fsdk.setDoc(attemptRef(db('p1'), id), newAttempt('p1')));
      const [first, second] = itemOrder();
      await rut.assertSucceeds(saveAnswer(db('p1'), id, first, 'B'));
      await rut.assertSucceeds(saveAnswer(db('p1'), id, first, 'E'));
      await rut.assertFails(saveAnswer(db('p1'), id, first, 'F'));
      await rut.assertFails(saveAnswer(db('p1'), id, 'pt-zz-99', 'A'));
      await rut.assertFails(
        fsdk.updateDoc(attemptRef(db('p1'), id), new fsdk.FieldPath('answers', first), 'A', new fsdk.FieldPath('answers', second), 'A', 'lastAnsweredItemId', first, 'updatedAt', fsdk.serverTimestamp())
      );
      await rut.assertFails(fsdk.updateDoc(attemptRef(db('p1'), id), new fsdk.FieldPath('answers', second), 'A', 'lastAnsweredItemId', first, 'updatedAt', fsdk.serverTimestamp()));
      await rut.assertFails(fsdk.updateDoc(attemptRef(db('p1'), id), new fsdk.FieldPath('answers', first), 'A', 'lastAnsweredItemId', first, 'updatedAt', fsdk.Timestamp.now()));
      await rut.assertFails(fsdk.updateDoc(attemptRef(db('p1'), id), new fsdk.FieldPath('answers', first), 'A', 'lastAnsweredItemId', first, 'updatedAt', fsdk.serverTimestamp(), 'itemOrder', []));
      await rut.assertFails(saveAnswer(db('p2'), id, first, 'A'));
      const stored = await readTrusted('placementAttempts', id);
      assert.deepEqual(stored.answers, { [first]: 'E' });
    });

    it('the lifecycle counter only goes up by one and never triggers anything', async () => {
      await seedBase();
      await seedPending('p1');
      const id = aid('p1');
      await rut.assertSucceeds(fsdk.setDoc(attemptRef(db('p1'), id), newAttempt('p1')));
      await rut.assertSucceeds(fsdk.updateDoc(attemptRef(db('p1'), id), { tabSwitchCount: 1, updatedAt: fsdk.serverTimestamp() }));
      await rut.assertFails(fsdk.updateDoc(attemptRef(db('p1'), id), { tabSwitchCount: 5, updatedAt: fsdk.serverTimestamp() }));
      await rut.assertFails(fsdk.updateDoc(attemptRef(db('p1'), id), { tabSwitchCount: 0, updatedAt: fsdk.serverTimestamp() }));
      assert.equal((await readTrusted('placementAttempts', id)).status, 'in_progress');
    });

    it('submits only with all 50 answers; the answers are then frozen', async () => {
      await seedBase();
      await seedPending('p1');
      const id = aid('p1');
      await rut.assertSucceeds(fsdk.setDoc(attemptRef(db('p1'), id), newAttempt('p1')));
      const order = itemOrder();
      for (const itemId of order.slice(0, 49)) await rut.assertSucceeds(saveAnswer(db('p1'), id, itemId, 'E'));
      await rut.assertFails(submit(db('p1'), id));
      await rut.assertSucceeds(saveAnswer(db('p1'), id, order[49], 'A'));
      await rut.assertFails(fsdk.updateDoc(attemptRef(db('p1'), id), { status: 'submitted', submittedAt: fsdk.Timestamp.now(), updatedAt: fsdk.serverTimestamp() }));
      await rut.assertSucceeds(submit(db('p1'), id));
      await rut.assertFails(saveAnswer(db('p1'), id, order[0], 'A'));
      await rut.assertFails(submit(db('p1'), id));
      await rut.assertFails(fsdk.updateDoc(attemptRef(db('p1'), id), { status: 'in_progress', updatedAt: fsdk.serverTimestamp() }));
      await rut.assertFails(fsdk.deleteDoc(attemptRef(db('p1'), id)));
    });

    it('closing the window freezes an unfinished attempt (answers kept) and rejects a late submission', async () => {
      await seedBase();
      await seedPending('p1');
      const id = aid('p1');
      await rut.assertSucceeds(fsdk.setDoc(attemptRef(db('p1'), id), newAttempt('p1')));
      const order = itemOrder();
      for (const itemId of order) await rut.assertSucceeds(saveAnswer(db('p1'), id, itemId, 'E'));
      await seedBase({ placementOpen: false });
      await rut.assertFails(submit(db('p1'), id));
      await rut.assertFails(saveAnswer(db('p1'), id, order[0], 'A'));
      const stored = await readTrusted('placementAttempts', id);
      assert.equal(stored.status, 'in_progress');
      assert.equal(Object.keys(stored.answers).length, 50);
      await seedBase();
      await rut.assertSucceeds(submit(db('p1'), id));
    });

    it('a closed study freezes an in-progress attempt (recorded incomplete)', async () => {
      await seedBase();
      await seedPending('p1');
      const id = aid('p1');
      await rut.assertSucceeds(fsdk.setDoc(attemptRef(db('p1'), id), newAttempt('p1')));
      await rut.assertSucceeds(saveAnswer(db('p1'), id, itemOrder()[0], 'A'));
      await seedBase({ study: 'closed' });
      await rut.assertFails(saveAnswer(db('p1'), id, itemOrder()[1], 'A'));
      assert.equal((await readTrusted('placementAttempts', id)).status, 'in_progress');
    });
  });

  // ---------------------------------------------------------------------
  describe('scoring (K2 recomputed by the rules)', () => {
    it('accepts exactly the K2 result and assigns the band in the same batch', async () => {
      await seedBase();
      await seedPending('p1');
      const s = [10, 9, 7, 2, 1];
      const id = await seedSubmitted('p1', s);
      await rut.assertSucceeds(scoreBatch('p1', id, resultOf(s)));
      const p = await readTrusted('researchParticipants', 'p1');
      assert.deepEqual([p.band, p.bandSource, p.status, p.placementAttemptId], ['B2', 'placement_test', 'enrolled', id]);
      const u = await readTrusted('users', 'p1');
      assert.deepEqual([u.resultLevel, u.resultAttemptId, u.placementTestCompleted], ['B1', id, true]);
      const a = await readTrusted('placementAttempts', id);
      assert.equal(a.status, 'scored');
      for (const field of ['bandScores', 'flags', 'score', 'totalScore']) assert.ok(!(field in a));
    });

    it('matches the tooling K2 decision on boundary and random profiles (and rejects every other result)', async () => {
      await seedBase();
      const profiles = [
        [7, 6, 6, 6, 7], [7, 6, 7, 6, 7], [6, 6, 7, 0, 0], [10, 10, 6, 6, 7], [10, 10, 6, 7, 7], [7, 6, 7, 0, 0],
        [6, 7, 7, 7, 7], [10, 6, 6, 7, 2], [0, 0, 0, 0, 0], [10, 10, 10, 10, 10], [7, 7, 7, 7, 6], [6, 0, 0, 0, 0],
      ];
      let seed = 7;
      const rnd = () => (seed = (seed * 1103515245 + 12345) % 2147483648) % 11;
      for (let i = 0; i < 18; i++) profiles.push([rnd(), rnd(), rnd(), rnd(), rnd()]);
      const candidates = [
        { resultLevel: 'A1', belowA1Threshold: true, pretestTargetBand: 'A2' },
        ...PLACEMENT_BANDS.map((lvl, k) => ({ resultLevel: lvl, belowA1Threshold: false, pretestTargetBand: PLACEMENT_BANDS[k + 1] || null })),
      ];
      let n = 0;
      for (const s of profiles) {
        const uid = `k${n++}`;
        await seedPending(uid);
        const id = await seedSubmitted(uid, s);
        const expected = resultOf(s);
        for (const c of candidates) {
          if (JSON.stringify(c) !== JSON.stringify(expected)) await rut.assertFails(scoreBatch(uid, id, c));
        }
        await rut.assertSucceeds(scoreBatch(uid, id, expected));
      }
    });

    it('a C1 result excludes the participant (no band); A1* gives band A2', async () => {
      await seedBase();
      await seedPending('c1');
      const id = await seedSubmitted('c1', [10, 10, 10, 10, 9]);
      await rut.assertSucceeds(scoreBatch('c1', id, resultOf([10, 10, 10, 10, 9])));
      const p = await readTrusted('researchParticipants', 'c1');
      assert.deepEqual([p.band, p.status, p.exclusionReason], [null, 'excluded', 'placement_c1']);
      await seedPending('low');
      const id2 = await seedSubmitted('low', [5, 3, 0, 0, 0]);
      await rut.assertSucceeds(scoreBatch('low', id2, resultOf([5, 3, 0, 0, 0])));
      assert.equal((await readTrusted('researchParticipants', 'low')).band, 'A2');
    });

    it('refuses a result without the users write, without the band write, or with a forged band/level', async () => {
      await seedBase();
      await seedPending('p1');
      const s = [10, 10, 10, 2, 0];
      const id = await seedSubmitted('p1', s);
      const r = resultOf(s);
      await rut.assertFails(scoreBatch('p1', id, r, { user: false }));
      await rut.assertFails(scoreBatch('p1', id, r, { participant: false }));
      await rut.assertFails(scoreBatch('p1', id, r, { participant: { band: 'C1' } }));
      await rut.assertFails(scoreBatch('p1', id, r, { participant: { bandSource: 'researcher_assigned' } }));
      await rut.assertFails(scoreBatch('p1', id, r, { user: { resultLevel: 'C1' } }));
      await rut.assertFails(scoreBatch('p1', id, r, { participant: { reviewStatus: 'not_confirmed' } }));
      await rut.assertSucceeds(scoreBatch('p1', id, r));
    });

    it('scores only once; a second or replayed result is refused', async () => {
      await seedBase();
      await seedPending('p1');
      await seedPending('p2');
      const s = [8, 8, 8, 8, 8];
      const id = await seedSubmitted('p1', s);
      await rut.assertSucceeds(scoreBatch('p1', id, resultOf(s)));
      await rut.assertFails(scoreBatch('p1', id, resultOf(s)));
      // p2 cannot borrow p1's scored attempt for its own band or level.
      const database = db('p2');
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(database, 'users', 'p2'), { resultLevel: 'C1', resultAttemptId: id, placementTestCompleted: true }));
      await rut.assertFails(
        fsdk.updateDoc(fsdk.doc(database, 'researchParticipants', 'p2'), { band: 'C1', bandSource: 'placement_test', status: 'enrolled', exclusionReason: null, placementAttemptId: id, updatedAt: fsdk.serverTimestamp() })
      );
    });

    it('cannot score an in-progress attempt or another student’s attempt', async () => {
      await seedBase();
      await seedPending('p1');
      await seedPending('p2');
      const s = [7, 7, 0, 0, 0];
      const id = await seedSubmitted('p1', s, { extra: { status: 'in_progress', submittedAt: null } });
      await rut.assertFails(scoreBatch('p1', id, resultOf(s)));
      const id2 = await seedSubmitted('p2', s);
      await rut.assertFails(scoreBatch('p1', id2, resultOf(s)));
    });

    it('a submission accepted before closure is still scored after the window and the study close', async () => {
      await seedBase({ placementOpen: false, study: 'closed' });
      await seedPending('p1');
      const s = [9, 9, 6, 1, 0];
      const id = await seedSubmitted('p1', s);
      await rut.assertSucceeds(scoreBatch('p1', id, resultOf(s)));
    });

    it('a pending review blocks the band write (the attempt stays submitted)', async () => {
      await seedBase();
      await seedPending('p1', { reviewStatus: 'pending' });
      const s = [9, 9, 9, 9, 1];
      const id = await seedSubmitted('p1', s);
      await rut.assertFails(scoreBatch('p1', id, resultOf(s)));
      assert.equal((await readTrusted('placementAttempts', id)).status, 'submitted');
    });

    it('scored attempts are readable only by their owner; list queries only for own attempts', async () => {
      await seedBase();
      await seedPending('p1');
      const id = await seedSubmitted('p1', [7, 0, 0, 0, 0]);
      await rut.assertSucceeds(fsdk.getDoc(attemptRef(db('p1'), id)));
      await rut.assertFails(fsdk.getDoc(attemptRef(db('p2'), id)));
      await rut.assertSucceeds(fsdk.getDocs(fsdk.query(fsdk.collection(db('p1'), 'placementAttempts'), fsdk.where('studentId', '==', 'p1'))));
      await rut.assertFails(fsdk.getDocs(fsdk.query(fsdk.collection(db('p2'), 'placementAttempts'), fsdk.where('studentId', '==', 'p1'))));
      await rut.assertFails(fsdk.getDocs(fsdk.collection(db('p1'), 'placementAttempts')));
    });
  });

  // ---------------------------------------------------------------------
  describe('users level fields', () => {
    it('resultLevel and placementTestCompleted cannot be set directly; name and prompt flag still can', async () => {
      await seedBase();
      await seedUser('u1');
      const ref = fsdk.doc(db('u1'), 'users', 'u1');
      await rut.assertFails(fsdk.updateDoc(ref, { resultLevel: 'C1' }));
      await rut.assertFails(fsdk.updateDoc(ref, { placementTestCompleted: true }));
      await rut.assertFails(fsdk.updateDoc(ref, { resultLevel: 'C1', resultAttemptId: 'u1_learning_1', placementTestCompleted: true }));
      await rut.assertSucceeds(fsdk.updateDoc(ref, { name: 'baru', placementTestPrompted: true }));
    });
  });

  // ---------------------------------------------------------------------
  describe('learning-only placement', () => {
    it('is closed until the researcher opens it, then open to non-participants', async () => {
      await seedBase();
      await seedUser('u1');
      await rut.assertFails(fsdk.setDoc(attemptRef(db('u1'), aid('u1', 'learning')), newAttempt('u1', { context: 'learning' })));
      await seedBase({ learningOpen: true });
      await rut.assertSucceeds(fsdk.setDoc(attemptRef(db('u1'), aid('u1', 'learning')), newAttempt('u1', { context: 'learning' })));
    });

    it('updates users.resultLevel only — never a research record', async () => {
      await seedBase({ learningOpen: true });
      await seedUser('u1');
      const s = [8, 8, 2, 0, 0];
      const id = await seedSubmitted('u1', s, { context: 'learning' });
      await rut.assertSucceeds(scoreBatch('u1', id, resultOf(s), { context: 'learning' }));
      assert.equal((await readTrusted('users', 'u1')).resultLevel, 'A2');
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('u1'), 'researchParticipants', 'u1'), { band: 'B1' }));
    });

    it('is refused for participants awaiting placement or enrolled during the study, allowed when excluded or after closure', async () => {
      await seedBase({ learningOpen: true });
      await seedPending('p1');
      await rut.assertFails(fsdk.setDoc(attemptRef(db('p1'), aid('p1', 'learning')), newAttempt('p1', { context: 'learning' })));
      await seedPending('p2', { status: 'enrolled', band: 'B1', bandSource: 'placement_test' });
      await rut.assertFails(fsdk.setDoc(attemptRef(db('p2'), aid('p2', 'learning')), newAttempt('p2', { context: 'learning' })));
      await seedPending('p3', { status: 'excluded', exclusionReason: 'placement_c1' });
      await rut.assertSucceeds(fsdk.setDoc(attemptRef(db('p3'), aid('p3', 'learning')), newAttempt('p3', { context: 'learning' })));
      await seedBase({ learningOpen: true, study: 'closed' });
      await rut.assertSucceeds(fsdk.setDoc(attemptRef(db('p2'), aid('p2', 'learning')), newAttempt('p2', { context: 'learning' })));
    });

    it('a learning result never changes the frozen research band or eligibility', async () => {
      await seedBase({ learningOpen: true, study: 'closed' });
      await seedPending('p1', { status: 'enrolled', band: 'B1', bandSource: 'placement_test', placementAttemptId: 'p1_research_1' });
      const s = [10, 10, 10, 10, 10];
      const id = await seedSubmitted('p1', s, { context: 'learning' });
      await rut.assertFails(scoreBatch('p1', id, resultOf(s), { context: 'research' }));
      await rut.assertSucceeds(scoreBatch('p1', id, resultOf(s), { context: 'learning' }));
      const p = await readTrusted('researchParticipants', 'p1');
      assert.deepEqual([p.band, p.status, p.placementAttemptId], ['B1', 'enrolled', 'p1_research_1']);
      assert.equal((await readTrusted('users', 'p1')).resultLevel, 'C1');
    });

    it('a new learning attempt needs the previous one scored more than a day ago', async () => {
      await seedBase({ learningOpen: true });
      await seedUser('u1');
      await seedSubmitted('u1', [7, 0, 0, 0, 0], { context: 'learning', extra: { status: 'scored', scoredAt: ago(3600e3), resultLevel: 'A1', belowA1Threshold: false, pretestTargetBand: 'A2', scoringPolicy: 'K2' } });
      await rut.assertFails(fsdk.setDoc(attemptRef(db('u1'), aid('u1', 'learning', 2)), newAttempt('u1', { context: 'learning', n: 2 })));
      await rut.assertFails(fsdk.setDoc(attemptRef(db('u1'), aid('u1', 'learning', 3)), newAttempt('u1', { context: 'learning', n: 3 })));
      await trusted((t) => fsdk.updateDoc(attemptRef(t, aid('u1', 'learning')), { scoredAt: ago(2 * DAY) }));
      await rut.assertSucceeds(fsdk.setDoc(attemptRef(db('u1'), aid('u1', 'learning', 2)), newAttempt('u1', { context: 'learning', n: 2 })));
    });
  });

});
