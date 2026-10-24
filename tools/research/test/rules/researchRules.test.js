'use strict';

/**
 * Firestore security-rules tests for the research pretest/posttest
 * collections (`researchParticipants`, `researchAssessmentResults`).
 *
 * Runs ONLY inside `firebase emulators:exec` started by
 * `bin/run_rules_tests.js` (demo project, local emulator). Outside that,
 * the whole suite is skipped — it can never reach production.
 *
 * All participants are synthetic (`stu-a2`, …) and every answer is
 * fabricated (always a fixed display position), never derived from the
 * answer key, which these tests never read.
 */

const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const projectId = process.env.GCLOUD_PROJECT || '';
const RUN =
  /^(127\.0\.0\.1|localhost):\d+$/.test(emulatorHost) && projectId.startsWith('demo-');

const { buildInstrumentDocs } = require('../../lib/instrumentDocs');

const REPO_ROOT = path.join(__dirname, '..', '..', '..', '..');
const bankJson = fs.readFileSync(path.join(REPO_ROOT, 'assets', 'research', 'instrument_v1.json'), 'utf8');
const bank = JSON.parse(bankJson);
const DONT_KNOW = { id: 'dont_know', text: 'Saya tidak tahu kata ini' };

describe('research Firestore rules (emulator)', { skip: !RUN && 'not inside the Firestore emulator (npm run test:rules)' }, () => {
  // Required lazily so the plain `npm test` run never loads the SDKs.
  let rut;
  let fsdk;
  let env;

  const ATTEMPTS = 'researchAssessmentResults';
  const PARTICIPANTS = 'researchParticipants';

  const itemsOf = (band) => bank.items.filter((item) => item.band === band);
  const itemById = (id) => bank.items.find((item) => item.id === id);

  /** Deterministic "shuffle" for tests: reversed items, options rotated by one. */
  function attemptPlan(band) {
    const items = itemsOf(band).slice().reverse();
    const itemOrder = items.map((item) => item.id);
    const optionOrder = Object.fromEntries(
      items.map((item) => {
        const ids = item.options.map((o) => o.id);
        return [item.id, [...ids.slice(1), ids[0]]];
      })
    );
    return { itemOrder, optionOrder };
  }

  function newAttempt(uid, { stage = 'preTest', n = 1, band = 'A2', ...overrides } = {}) {
    const plan = attemptPlan(band);
    return {
      studentId: uid,
      stage,
      attemptNumber: n,
      band,
      instrumentVersion: 'v1',
      itemOrder: plan.itemOrder,
      optionOrder: plan.optionOrder,
      responses: {},
      lastAnsweredItemId: null,
      status: 'in_progress',
      startedAt: fsdk.serverTimestamp(),
      updatedAt: fsdk.serverTimestamp(),
      completedAt: null,
      ...overrides,
    };
  }

  const attemptId = (uid, stage = 'preTest', n = 1) => `${uid}_${stage}_${n}`;

  function db(uid) {
    return uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
  }

  /** Trusted fixture write (rules disabled) — the stand-in for researcher Admin tooling. */
  async function trusted(fn) {
    await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
  }

  async function seedParticipant(uid, { band = 'A2', preTest = 1, postTest = 0 } = {}) {
    await trusted((tdb) =>
      fsdk.setDoc(fsdk.doc(tdb, PARTICIPANTS, uid), {
        researchId: `R-${uid}`,
        band,
        bandSource: 'researcher_assigned',
        instrumentVersion: 'v1',
        authorizedAttempts: { preTest, postTest },
        cohort: 'test',
        createdAt: fsdk.Timestamp.now(),
        updatedAt: fsdk.Timestamp.now(),
      })
    );
  }

  /** The answer a student would save for display position [pos] (1–4, or 5 = "tidak tahu"). */
  function answerFor(attempt, itemId, pos) {
    if (pos === 5) {
      return { optionId: DONT_KNOW.id, optionText: DONT_KNOW.text, displayPosition: 5, answeredAt: fsdk.serverTimestamp() };
    }
    const optionId = attempt.optionOrder[itemId][pos - 1];
    const text = itemById(itemId).options.find((o) => o.id === optionId).text;
    return { optionId, optionText: text, displayPosition: pos, answeredAt: fsdk.serverTimestamp() };
  }

  function saveAnswer(database, id, itemId, value, { lastAnsweredItemId = itemId, updatedAt } = {}) {
    return fsdk.updateDoc(
      fsdk.doc(database, ATTEMPTS, id),
      new fsdk.FieldPath('responses', itemId),
      value,
      'lastAnsweredItemId',
      lastAnsweredItemId,
      'updatedAt',
      updatedAt === undefined ? fsdk.serverTimestamp() : updatedAt
    );
  }

  /** Creates a valid attempt as the student and saves the first [count] answers (position 1). */
  async function startedAttempt(uid, count, opts = {}) {
    const attempt = newAttempt(uid, opts);
    const id = attemptId(uid, attempt.stage, attempt.attemptNumber);
    await rut.assertSucceeds(fsdk.setDoc(fsdk.doc(db(uid), ATTEMPTS, id), attempt));
    for (const itemId of attempt.itemOrder.slice(0, count)) {
      await rut.assertSucceeds(saveAnswer(db(uid), id, itemId, answerFor(attempt, itemId, 1)));
    }
    return { attempt, id };
  }

  function complete(database, id, { completedAt } = {}) {
    return fsdk.updateDoc(fsdk.doc(database, ATTEMPTS, id), {
      status: 'completed',
      completedAt: completedAt === undefined ? fsdk.serverTimestamp() : completedAt,
      updatedAt: fsdk.serverTimestamp(),
    });
  }

  async function readTrusted(collectionName, id) {
    let data;
    await trusted(async (tdb) => {
      data = (await fsdk.getDoc(fsdk.doc(tdb, collectionName, id))).data();
    });
    return data;
  }

  before(async () => {
    rut = require('@firebase/rules-unit-testing');
    fsdk = require('firebase/firestore');
    const [host, port] = emulatorHost.split(':');
    env = await rut.initializeTestEnvironment({
      projectId,
      firestore: { rules: fs.readFileSync(path.join(REPO_ROOT, 'firestore.rules'), 'utf8'), host, port: Number(port) },
    });
  });

  after(async () => {
    if (env) await env.cleanup();
  });

  /** Trusted, public bank data the rules validate against (no answer key). */
  async function seedInstrument() {
    await trusted(async (tdb) => {
      for (const { id, data } of buildInstrumentDocs(bank, bankJson)) {
        await fsdk.setDoc(fsdk.doc(tdb, 'researchInstrument', id), data);
      }
    });
  }

  beforeEach(async () => {
    await env.clearFirestore();
    await seedInstrument();
  });

  // ---------------------------------------------------------------------
  describe('instrument bank documents', () => {
    it('clients can neither read nor write them', async () => {
      await rut.assertFails(fsdk.getDoc(fsdk.doc(db('stu-a2'), 'researchInstrument', 'v1_A2')));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('stu-a2'), 'researchInstrument', 'v1_A2'), { optionIds: {} }));
      await rut.assertFails(fsdk.getDoc(fsdk.doc(db(null), 'researchInstrument', 'v1_A2')));
    });

    it('attempt creation fails closed when the band’s bank document is missing', async () => {
      await seedParticipant('stu-a2');
      await trusted((tdb) => fsdk.deleteDoc(fsdk.doc(tdb, 'researchInstrument', 'v1_A2')));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2')), newAttempt('stu-a2')));
    });
  });

  // ---------------------------------------------------------------------
  describe('participant records', () => {
    it('unauthenticated read and write are denied', async () => {
      await seedParticipant('stu-a2');
      await rut.assertFails(fsdk.getDoc(fsdk.doc(db(null), PARTICIPANTS, 'stu-a2')));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db(null), PARTICIPANTS, 'anon'), { band: 'A2' }));
    });

    it('a student can read only their own record', async () => {
      await seedParticipant('stu-a2');
      await seedParticipant('stu-b1', { band: 'B1' });
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db('stu-a2'), PARTICIPANTS, 'stu-a2')));
      await rut.assertFails(fsdk.getDoc(fsdk.doc(db('stu-a2'), PARTICIPANTS, 'stu-b1')));
    });

    it('participant records cannot be listed', async () => {
      await seedParticipant('stu-a2');
      await rut.assertFails(fsdk.getDocs(fsdk.collection(db('stu-a2'), PARTICIPANTS)));
    });

    it('a student cannot create their own participant record', async () => {
      await rut.assertFails(
        fsdk.setDoc(fsdk.doc(db('stu-x'), PARTICIPANTS, 'stu-x'), {
          researchId: 'R-x', band: 'B2', bandSource: 'researcher_assigned', instrumentVersion: 'v1',
          authorizedAttempts: { preTest: 1, postTest: 1 }, cohort: 'study',
        })
      );
    });

    it('a student cannot change their research band', async () => {
      await seedParticipant('stu-a2');
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(db('stu-a2'), PARTICIPANTS, 'stu-a2'), { band: 'B1' }));
    });

    it('a student cannot grant themselves pretest, posttest or retake authorization', async () => {
      await seedParticipant('stu-a2', { preTest: 0, postTest: 0 });
      const ref = fsdk.doc(db('stu-a2'), PARTICIPANTS, 'stu-a2');
      await rut.assertFails(fsdk.updateDoc(ref, { 'authorizedAttempts.preTest': 1 }));
      await rut.assertFails(fsdk.updateDoc(ref, { 'authorizedAttempts.postTest': 1 }));
      await rut.assertFails(fsdk.updateDoc(ref, { authorizedAttempts: { preTest: 2, postTest: 1 } }));
    });

    it('a student cannot delete their participant record', async () => {
      await seedParticipant('stu-a2');
      await rut.assertFails(fsdk.deleteDoc(fsdk.doc(db('stu-a2'), PARTICIPANTS, 'stu-a2')));
    });

    it('trusted fixture setup creates authorized records without weakening client rules', async () => {
      await seedParticipant('stu-a2', { band: 'A2', preTest: 1 });
      const record = await readTrusted(PARTICIPANTS, 'stu-a2');
      assert.equal(record.band, 'A2');
      assert.deepEqual(record.authorizedAttempts, { preTest: 1, postTest: 0 });
      // The identical write by the student is still denied.
      await rut.assertFails(
        fsdk.setDoc(fsdk.doc(db('stu-a2'), PARTICIPANTS, 'stu-a2'), { ...record, updatedAt: fsdk.Timestamp.now() })
      );
    });

    it('users.cefrLevel never influences the research band or eligibility', async () => {
      await trusted((tdb) =>
        fsdk.setDoc(fsdk.doc(tdb, 'users', 'stu-a2'), {
          uid: 'stu-a2', email: 'stu-a2@example.test', name: 'Synthetic', role: 'siswa',
          createdAt: fsdk.Timestamp.now(), cefrLevel: 'C1', placementTestCompleted: false, placementTestPrompted: true,
        })
      );
      await seedParticipant('stu-a2', { band: 'A2' });
      // The student may still change their ordinary display level…
      await rut.assertSucceeds(fsdk.updateDoc(fsdk.doc(db('stu-a2'), 'users', 'stu-a2'), { cefrLevel: 'B2' }));
      // …but neither the old nor the new cefrLevel can be used as the band.
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2')), newAttempt('stu-a2', { band: 'C1' })));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2')), newAttempt('stu-a2', { band: 'B2' })));
      await rut.assertSucceeds(fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2')), newAttempt('stu-a2', { band: 'A2' })));
    });
  });

  // ---------------------------------------------------------------------
  describe('attempt access', () => {
    it('a student can read their own attempt, and check for a not-yet-created authorized one', async () => {
      await seedParticipant('stu-a2', { preTest: 1, postTest: 1 });
      const { id } = await startedAttempt('stu-a2', 0);
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, id)));
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2', 'postTest', 1))));
    });

    it("a student cannot read another participant's attempt (existing or not)", async () => {
      await seedParticipant('stu-a2');
      await seedParticipant('stu-b1', { band: 'B1' });
      const { id } = await startedAttempt('stu-b1', 1, { band: 'B1' });
      await rut.assertFails(fsdk.getDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, id)));
      await rut.assertFails(fsdk.getDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-b1', 'postTest', 1))));
    });

    it('unauthenticated reads and list queries are denied', async () => {
      await seedParticipant('stu-a2');
      const { id } = await startedAttempt('stu-a2', 0);
      await rut.assertFails(fsdk.getDoc(fsdk.doc(db(null), ATTEMPTS, id)));
      await rut.assertFails(
        fsdk.getDocs(fsdk.query(fsdk.collection(db('stu-a2'), ATTEMPTS), fsdk.where('studentId', '==', 'stu-a2')))
      );
    });

    it('an unauthenticated client cannot create an attempt', async () => {
      await seedParticipant('stu-a2');
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db(null), ATTEMPTS, attemptId('stu-a2')), newAttempt('stu-a2')));
    });

    it('a student cannot create an attempt for another participant', async () => {
      await seedParticipant('stu-a2');
      await seedParticipant('stu-a2b');
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2b')), newAttempt('stu-a2b')));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2')), newAttempt('stu-a2b')));
    });

    it('a student without a participant record cannot create an attempt', async () => {
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('stu-none'), ATTEMPTS, attemptId('stu-none')), newAttempt('stu-none')));
    });
  });

  // ---------------------------------------------------------------------
  describe('attempt creation', () => {
    const create = (uid, data, id = attemptId(uid, data.stage, data.attemptNumber)) =>
      fsdk.setDoc(fsdk.doc(db(uid), ATTEMPTS, id), data);

    it('a valid authorized pretest attempt can be created', async () => {
      await seedParticipant('stu-a2');
      await rut.assertSucceeds(create('stu-a2', newAttempt('stu-a2')));
    });

    it('an unassigned band is rejected, even with that band’s own items', async () => {
      await seedParticipant('stu-a2', { band: 'A2' });
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { band: 'B1' })));
    });

    it('unexpected band values are rejected', async () => {
      await seedParticipant('stu-a2', { band: 'A2' });
      const plan = attemptPlan('A2');
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { band: 'C2', ...plan })));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { band: 'a2', ...plan })));
    });

    it('an unauthorized stage is rejected (posttest not opened)', async () => {
      await seedParticipant('stu-a2', { preTest: 1, postTest: 0 });
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { stage: 'postTest' })));
    });

    it('a pretest that is not authorized (0) is rejected', async () => {
      await seedParticipant('stu-a2', { preTest: 0 });
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { n: 0 }), attemptId('stu-a2', 'preTest', 0)));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2')));
    });

    it('invalid stage values are rejected', async () => {
      await seedParticipant('stu-a2');
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { stage: 'midTest' }), 'stu-a2_midTest_1'));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { stage: 'pretest' }), 'stu-a2_pretest_1'));
    });

    it('an attempt number that is not the authorized one is rejected', async () => {
      await seedParticipant('stu-a2', { preTest: 1 });
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { n: 2 })));
    });

    it('a document ID that does not match studentId/stage/attemptNumber is rejected', async () => {
      await seedParticipant('stu-a2');
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2'), 'stu-a2_preTest_9'));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2'), 'stu-a2_postTest_1'));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2'), 'random-id'));
    });

    it('answer-key, correctness or score fields are rejected', async () => {
      await seedParticipant('stu-a2');
      for (const extra of [{ score: 0 }, { answerKey: {} }, { isCorrect: false }, { correctOptionIds: [] }]) {
        await rut.assertFails(create('stu-a2', newAttempt('stu-a2', extra)));
      }
    });

    it('unknown or missing fields are rejected', async () => {
      await seedParticipant('stu-a2');
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { note: 'hi' })));
      const missing = newAttempt('stu-a2');
      delete missing.completedAt;
      await rut.assertFails(create('stu-a2', missing));
      const missingOrder = newAttempt('stu-a2');
      delete missingOrder.optionOrder;
      await rut.assertFails(create('stu-a2', missingOrder));
    });

    it('wrong data types are rejected', async () => {
      await seedParticipant('stu-a2');
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { attemptNumber: '1' }), attemptId('stu-a2')));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { itemOrder: 'A2-01' })));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { responses: [] })));
    });

    it('a client-chosen start or update timestamp is rejected', async () => {
      await seedParticipant('stu-a2');
      const past = fsdk.Timestamp.fromDate(new Date('2020-01-01T00:00:00Z'));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { startedAt: past })));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { updatedAt: past })));
    });

    it('an attempt cannot start completed, voided or with pre-filled answers', async () => {
      await seedParticipant('stu-a2');
      const attempt = newAttempt('stu-a2');
      const firstItem = attempt.itemOrder[0];
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { status: 'completed' })));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { status: 'voided' })));
      await rut.assertFails(
        create('stu-a2', newAttempt('stu-a2', { responses: { [firstItem]: answerFor(attempt, firstItem, 1) } }))
      );
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { lastAnsweredItemId: firstItem })));
    });

    it('the question order must be exactly the band’s 20 items', async () => {
      await seedParticipant('stu-a2');
      const plan = attemptPlan('A2');
      const b1 = itemsOf('B1')[0].id;
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { itemOrder: plan.itemOrder.slice(0, 19) })));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { itemOrder: [...plan.itemOrder.slice(0, 19), plan.itemOrder[0]] })));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { itemOrder: [...plan.itemOrder.slice(0, 19), b1] })));
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { itemOrder: [...plan.itemOrder, b1] })));
    });

    it('displayed option orders must be permutations of each item’s bank options', async () => {
      await seedParticipant('stu-a2');
      const plan = attemptPlan('A2');
      const target = plan.itemOrder[7];
      const withOrder = (list) => newAttempt('stu-a2', { optionOrder: { ...plan.optionOrder, [target]: list } });
      const own = plan.optionOrder[target];
      const otherItemOption = plan.optionOrder[plan.itemOrder[8]][0];
      await rut.assertFails(create('stu-a2', withOrder([...own.slice(0, 3), 'opt_000000000000'])));
      await rut.assertFails(create('stu-a2', withOrder([...own.slice(0, 3), otherItemOption])));
      await rut.assertFails(create('stu-a2', withOrder([...own.slice(0, 3), 'dont_know'])));
      await rut.assertFails(create('stu-a2', withOrder(own.slice(0, 3))));
      await rut.assertFails(create('stu-a2', withOrder([own[0], own[0], own[1], own[2]])));
      await rut.assertSucceeds(create('stu-a2', withOrder([own[3], own[2], own[1], own[0]])));
    });

    it('an option order missing an item or containing an extra key is rejected', async () => {
      await seedParticipant('stu-a2');
      const plan = attemptPlan('A2');
      const missing = { ...plan.optionOrder };
      delete missing[plan.itemOrder[0]];
      await rut.assertFails(create('stu-a2', newAttempt('stu-a2', { optionOrder: missing })));
      await rut.assertFails(
        create('stu-a2', newAttempt('stu-a2', { optionOrder: { ...plan.optionOrder, 'B1-01': itemsOf('B1')[0].options.map((o) => o.id) } }))
      );
    });

    it('an existing attempt cannot be overwritten by creating it again', async () => {
      await seedParticipant('stu-a2');
      const { id } = await startedAttempt('stu-a2', 2);
      const plan = attemptPlan('A2');
      await rut.assertFails(
        fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, id), newAttempt('stu-a2', { itemOrder: plan.itemOrder.slice().reverse() }))
      );
      const stored = await readTrusted(ATTEMPTS, id);
      assert.equal(Object.keys(stored.responses).length, 2);
    });
  });

  // ---------------------------------------------------------------------
  describe('posttest authorization', () => {
    async function completedPretest(uid) {
      const { id } = await startedAttempt(uid, 20);
      await rut.assertSucceeds(complete(db(uid), id));
    }

    it('is denied while the pretest is not completed, even when authorized', async () => {
      await seedParticipant('stu-a2', { preTest: 1, postTest: 1 });
      await startedAttempt('stu-a2', 5);
      await rut.assertFails(
        fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2', 'postTest', 1)), newAttempt('stu-a2', { stage: 'postTest' }))
      );
    });

    it('is denied after a completed pretest until the researcher authorizes it', async () => {
      await seedParticipant('stu-a2', { preTest: 1, postTest: 0 });
      await completedPretest('stu-a2');
      await rut.assertFails(
        fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2', 'postTest', 1)), newAttempt('stu-a2', { stage: 'postTest' }))
      );
    });

    it('is allowed after a completed pretest plus explicit trusted authorization', async () => {
      await seedParticipant('stu-a2', { preTest: 1, postTest: 0 });
      await completedPretest('stu-a2');
      await trusted((tdb) => fsdk.updateDoc(fsdk.doc(tdb, PARTICIPANTS, 'stu-a2'), { 'authorizedAttempts.postTest': 1 }));
      await rut.assertSucceeds(
        fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2', 'postTest', 1)), newAttempt('stu-a2', { stage: 'postTest' }))
      );
    });

    it('cannot be enabled by writing a client-side field on the attempt or participant', async () => {
      await seedParticipant('stu-a2', { preTest: 1, postTest: 0 });
      await completedPretest('stu-a2');
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(db('stu-a2'), PARTICIPANTS, 'stu-a2'), { 'authorizedAttempts.postTest': 1 }));
      await rut.assertFails(
        fsdk.setDoc(
          fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2', 'postTest', 1)),
          newAttempt('stu-a2', { stage: 'postTest', postTestAuthorized: true })
        )
      );
    });
  });

  // ---------------------------------------------------------------------
  describe('saving answers', () => {
    it('a valid answer to an unanswered item is saved', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 0);
      await rut.assertSucceeds(saveAnswer(db('stu-a2'), id, attempt.itemOrder[0], answerFor(attempt, attempt.itemOrder[0], 3)));
    });

    it('"Saya tidak tahu kata ini" is saved as dont_know at position 5, not as a bank option', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 0);
      const item = attempt.itemOrder[0];
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, { ...answerFor(attempt, item, 5), displayPosition: 4 }));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, { ...answerFor(attempt, item, 5), optionText: 'Tidak tahu' }));
      await rut.assertSucceeds(saveAnswer(db('stu-a2'), id, item, answerFor(attempt, item, 5)));
      const stored = await readTrusted(ATTEMPTS, id);
      assert.equal(stored.responses[item].optionId, 'dont_know');
      assert.ok(!attempt.optionOrder[item].includes('dont_know'));
    });

    it('a submitted answer cannot be modified (forward-only)', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 1);
      const item = attempt.itemOrder[0];
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, answerFor(attempt, item, 2)));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, answerFor(attempt, item, 1)));
      await rut.assertFails(
        fsdk.updateDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, id), { [`responses`]: {}, updatedAt: fsdk.serverTimestamp() })
      );
    });

    it('an item that is not part of the attempt is rejected', async () => {
      await seedParticipant('stu-a2');
      const { id } = await startedAttempt('stu-a2', 0);
      const foreign = itemsOf('B1')[0];
      await rut.assertFails(
        saveAnswer(db('stu-a2'), id, foreign.id, {
          optionId: foreign.options[0].id, optionText: foreign.options[0].text, displayPosition: 1, answeredAt: fsdk.serverTimestamp(),
        })
      );
    });

    it('two answers in one write are rejected', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 0);
      const [a, b] = attempt.itemOrder;
      await rut.assertFails(
        fsdk.updateDoc(
          fsdk.doc(db('stu-a2'), ATTEMPTS, id),
          new fsdk.FieldPath('responses', a), answerFor(attempt, a, 1),
          new fsdk.FieldPath('responses', b), answerFor(attempt, b, 1),
          'lastAnsweredItemId', b,
          'updatedAt', fsdk.serverTimestamp()
        )
      );
    });

    it('lastAnsweredItemId must name the item actually written', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 0);
      const [a, b] = attempt.itemOrder;
      await rut.assertFails(saveAnswer(db('stu-a2'), id, a, answerFor(attempt, a, 1), { lastAnsweredItemId: b }));
    });

    it('fabricated or foreign option IDs are rejected', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 0);
      const [item, other] = attempt.itemOrder;
      const base = answerFor(attempt, item, 1);
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, { ...base, optionId: 'opt_000000000000' }));
      const foreign = answerFor(attempt, other, 1);
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, { ...base, optionId: foreign.optionId, optionText: foreign.optionText }));
    });

    it('option text and display position must match the displayed option', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 0);
      const item = attempt.itemOrder[0];
      const base = answerFor(attempt, item, 2);
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, { ...base, optionText: 'Teks lain' }));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, { ...base, displayPosition: 3 }));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, { ...base, displayPosition: 5 }));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, { ...base, displayPosition: '2' }));
    });

    it('invalid response structures are rejected', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 0);
      const item = attempt.itemOrder[0];
      const base = answerFor(attempt, item, 1);
      const { optionText, ...noText } = base;
      assert.ok(optionText);
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, noText));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, { ...base, isCorrect: true }));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, { ...base, code: 'B' }));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, 'opt_x'));
    });

    it('client-chosen answer or update timestamps are rejected', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 0);
      const item = attempt.itemOrder[0];
      const past = fsdk.Timestamp.fromDate(new Date('2020-01-01T00:00:00Z'));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, { ...answerFor(attempt, item, 1), answeredAt: past }));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, item, answerFor(attempt, item, 1), { updatedAt: past }));
    });

    it('immutable fields cannot be changed after creation', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 1);
      const ref = fsdk.doc(db('stu-a2'), ATTEMPTS, id);
      const ts = fsdk.serverTimestamp();
      for (const change of [
        { studentId: 'stu-other' },
        { stage: 'postTest' },
        { attemptNumber: 2 },
        { band: 'B1' },
        { instrumentVersion: 'v2' },
        { itemOrder: attempt.itemOrder.slice().reverse() },
        { optionOrder: attemptPlan('A2').optionOrder },
        { startedAt: ts },
        { score: 5 },
      ]) {
        await rut.assertFails(fsdk.updateDoc(ref, { ...change, updatedAt: ts }));
      }
    });

    it('a student cannot write to another participant’s attempt', async () => {
      await seedParticipant('stu-a2');
      await seedParticipant('stu-a2b');
      const { attempt, id } = await startedAttempt('stu-a2b', 0);
      await rut.assertFails(saveAnswer(db('stu-a2'), id, attempt.itemOrder[0], answerFor(attempt, attempt.itemOrder[0], 1)));
    });
  });

  // ---------------------------------------------------------------------
  describe('completion', () => {
    it('cannot complete before all 20 answers are saved', async () => {
      await seedParticipant('stu-a2');
      const { id } = await startedAttempt('stu-a2', 19);
      await rut.assertFails(complete(db('stu-a2'), id));
    });

    it('completes once all 20 answers are saved', async () => {
      await seedParticipant('stu-a2');
      const { id } = await startedAttempt('stu-a2', 20);
      await rut.assertSucceeds(complete(db('stu-a2'), id));
    });

    it('a client-chosen completion timestamp is rejected', async () => {
      await seedParticipant('stu-a2');
      const { id } = await startedAttempt('stu-a2', 20);
      await rut.assertFails(complete(db('stu-a2'), id, { completedAt: fsdk.Timestamp.fromDate(new Date('2020-01-01T00:00:00Z')) }));
    });

    it('a completed attempt cannot be completed again, reopened, answered or overwritten', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 20);
      await rut.assertSucceeds(complete(db('stu-a2'), id));
      const ref = fsdk.doc(db('stu-a2'), ATTEMPTS, id);
      await rut.assertFails(complete(db('stu-a2'), id));
      await rut.assertFails(fsdk.updateDoc(ref, { status: 'in_progress', completedAt: null, updatedAt: fsdk.serverTimestamp() }));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, attempt.itemOrder[0], answerFor(attempt, attempt.itemOrder[0], 2)));
      await rut.assertFails(fsdk.setDoc(ref, newAttempt('stu-a2')));
      await rut.assertFails(fsdk.deleteDoc(ref));
    });

    it('a student cannot void an attempt or invent another status', async () => {
      await seedParticipant('stu-a2');
      const { id } = await startedAttempt('stu-a2', 3);
      const ref = fsdk.doc(db('stu-a2'), ATTEMPTS, id);
      for (const status of ['voided', 'abandoned', 'in_progress']) {
        await rut.assertFails(fsdk.updateDoc(ref, { status, updatedAt: fsdk.serverTimestamp() }));
      }
    });
  });

  // ---------------------------------------------------------------------
  describe('retakes after a technical interruption', () => {
    it('a retake requires explicit trusted authorization and preserves the old attempt', async () => {
      await seedParticipant('stu-a2', { preTest: 1 });
      const { attempt, id } = await startedAttempt('stu-a2', 6);
      const before = await readTrusted(ATTEMPTS, id);

      // Not yet authorized: attempt 2 is denied.
      await rut.assertFails(
        fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2', 'preTest', 2)), newAttempt('stu-a2', { n: 2 }))
      );

      // Researcher tooling (trusted) voids attempt 1 and authorizes attempt 2.
      await trusted(async (tdb) => {
        await fsdk.updateDoc(fsdk.doc(tdb, ATTEMPTS, id), {
          status: 'voided', voidReason: 'synthetic technical interruption', voidedAt: fsdk.Timestamp.now(),
        });
        await fsdk.updateDoc(fsdk.doc(tdb, PARTICIPANTS, 'stu-a2'), { 'authorizedAttempts.preTest': 2 });
      });

      await rut.assertSucceeds(
        fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2', 'preTest', 2)), newAttempt('stu-a2', { n: 2 }))
      );
      // The voided attempt cannot be touched by the student and keeps its answers.
      await rut.assertFails(saveAnswer(db('stu-a2'), id, attempt.itemOrder[6], answerFor(attempt, attempt.itemOrder[6], 1)));
      await rut.assertFails(complete(db('stu-a2'), id));
      const afterVoid = await readTrusted(ATTEMPTS, id);
      assert.deepEqual(Object.keys(afterVoid.responses).sort(), Object.keys(before.responses).sort());
      assert.equal(afterVoid.status, 'voided');
      // The student can still read their old attempt.
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, id)));
    });

    it('a superseded attempt is frozen even if it was not voided', async () => {
      await seedParticipant('stu-a2', { preTest: 1 });
      const { attempt, id } = await startedAttempt('stu-a2', 2);
      await trusted((tdb) => fsdk.updateDoc(fsdk.doc(tdb, PARTICIPANTS, 'stu-a2'), { 'authorizedAttempts.preTest': 2 }));
      await rut.assertFails(saveAnswer(db('stu-a2'), id, attempt.itemOrder[2], answerFor(attempt, attempt.itemOrder[2], 1)));
    });

    it('an incomplete attempt keeps its saved answers and stays in progress', async () => {
      await seedParticipant('stu-a2');
      const { id } = await startedAttempt('stu-a2', 4);
      const stored = await readTrusted(ATTEMPTS, id);
      assert.equal(stored.status, 'in_progress');
      assert.equal(Object.keys(stored.responses).length, 4);
      assert.equal(stored.completedAt, null);
    });
  });

  // ---------------------------------------------------------------------
  // Security audit (post-M2a): ownership must never depend on interpreting
  // a UID as a pattern or prefix. Firebase Auth's own UIDs are 28
  // alphanumeric characters, but UIDs minted elsewhere (custom tokens) may
  // be any string up to 128 characters, so regex-special characters,
  // underscores and prefix relationships are exercised here.
  describe('UID ownership isolation', () => {
    const getAttempt = (uid, id) => fsdk.getDoc(fsdk.doc(db(uid), ATTEMPTS, id));

    it('a UID with regex metacharacters cannot probe another participant’s attempts', async () => {
      // 'stu.x' as a regex would also match 'stuax'.
      await seedParticipant('stu.x');
      await seedParticipant('stuax');
      await rut.assertFails(getAttempt('stu.x', attemptId('stuax'))); // before it exists
      await startedAttempt('stuax', 1);
      await rut.assertFails(getAttempt('stu.x', attemptId('stuax'))); // after it exists
    });

    it('denials do not reveal whether another participant’s attempt exists', async () => {
      await seedParticipant('stu-a2');
      await seedParticipant('stu-other');
      await startedAttempt('stu-other', 0);
      await rut.assertFails(getAttempt('stu-a2', attemptId('stu-other'))); // exists
      await rut.assertFails(getAttempt('stu-a2', attemptId('stu-other', 'postTest', 1))); // missing
      await rut.assertFails(getAttempt('stu-a2', attemptId('stu-other', 'preTest', 7))); // missing
    });

    it('a UID full of regex metacharacters still works for its own attempts', async () => {
      const uid = '(stu)+[1]*.^$|?{2}';
      await seedParticipant(uid);
      await rut.assertSucceeds(getAttempt(uid, attemptId(uid))); // own, not yet created
      const { attempt, id } = await startedAttempt(uid, 20);
      await rut.assertSucceeds(getAttempt(uid, id));
      await rut.assertSucceeds(complete(db(uid), id));
      assert.equal(attempt.itemOrder.length, 20);
    });

    it('prefix-related UIDs cannot read or write each other’s attempts', async () => {
      // 'stu' is a prefix of 'stu1' and of 'stu_preTest'; IDs are uid_stage_n.
      for (const uid of ['stu', 'stu1', 'stu_preTest']) await seedParticipant(uid);
      const own = {};
      for (const uid of ['stu', 'stu1', 'stu_preTest']) own[uid] = await startedAttempt(uid, 1);
      for (const reader of ['stu', 'stu1', 'stu_preTest']) {
        for (const owner of ['stu', 'stu1', 'stu_preTest']) {
          if (reader === owner) continue;
          await rut.assertFails(getAttempt(reader, own[owner].id));
          const { attempt, id } = own[owner];
          await rut.assertFails(saveAnswer(db(reader), id, attempt.itemOrder[1], answerFor(attempt, attempt.itemOrder[1], 1)));
        }
        await rut.assertSucceeds(getAttempt(reader, own[reader].id));
      }
      // 'stu' cannot create a document that would sit in 'stu_preTest''s namespace.
      await rut.assertFails(
        fsdk.setDoc(fsdk.doc(db('stu'), ATTEMPTS, 'stu_preTest_preTest_1'), newAttempt('stu'))
      );
    });

    it('a student can check only their currently authorized, not-yet-created attempts', async () => {
      await seedParticipant('stu-a2', { preTest: 1, postTest: 0 });
      await rut.assertSucceeds(getAttempt('stu-a2', attemptId('stu-a2', 'preTest', 1)));
      await rut.assertFails(getAttempt('stu-a2', attemptId('stu-a2', 'postTest', 1))); // not authorized
      await rut.assertFails(getAttempt('stu-a2', attemptId('stu-a2', 'preTest', 2))); // not authorized
      await rut.assertFails(getAttempt('stu-a2', 'stu-a2_preTest_01'));
    });
  });

  // ---------------------------------------------------------------------
  describe('answer and completion integrity (audit)', () => {
    it('a saved answer cannot be deleted', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 2);
      const ref = fsdk.doc(db('stu-a2'), ATTEMPTS, id);
      const item = attempt.itemOrder[0];
      await rut.assertFails(
        fsdk.updateDoc(ref, new fsdk.FieldPath('responses', item), fsdk.deleteField(), 'updatedAt', fsdk.serverTimestamp())
      );
      await rut.assertFails(
        fsdk.updateDoc(
          ref,
          new fsdk.FieldPath('responses', item), fsdk.deleteField(),
          'lastAnsweredItemId', item,
          'updatedAt', fsdk.serverTimestamp()
        )
      );
    });

    it('a new answer cannot remove or rewrite a different saved answer in the same write', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 1);
      const [first, second] = attempt.itemOrder;
      await rut.assertFails(
        fsdk.updateDoc(
          fsdk.doc(db('stu-a2'), ATTEMPTS, id),
          new fsdk.FieldPath('responses', first), fsdk.deleteField(),
          new fsdk.FieldPath('responses', second), answerFor(attempt, second, 1),
          'lastAnsweredItemId', second,
          'updatedAt', fsdk.serverTimestamp()
        )
      );
      await rut.assertFails(
        fsdk.updateDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, id), {
          responses: { [second]: answerFor(attempt, second, 1) },
          lastAnsweredItemId: second,
          updatedAt: fsdk.serverTimestamp(),
        })
      );
    });

    it('an answer write cannot change unrelated attempt fields', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 0);
      const item = attempt.itemOrder[0];
      const ref = fsdk.doc(db('stu-a2'), ATTEMPTS, id);
      for (const [field, value] of [['status', 'completed'], ['band', 'B1'], ['completedAt', fsdk.serverTimestamp()], ['score', 1]]) {
        await rut.assertFails(
          fsdk.updateDoc(
            ref,
            new fsdk.FieldPath('responses', item), answerFor(attempt, item, 1),
            'lastAnsweredItemId', item,
            'updatedAt', fsdk.serverTimestamp(),
            field, value
          )
        );
      }
    });

    it('completion cannot add the missing 20th answer in the same write', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 19);
      const last = attempt.itemOrder[19];
      await rut.assertFails(
        fsdk.updateDoc(
          fsdk.doc(db('stu-a2'), ATTEMPTS, id),
          new fsdk.FieldPath('responses', last), answerFor(attempt, last, 1),
          'lastAnsweredItemId', last,
          'status', 'completed',
          'completedAt', fsdk.serverTimestamp(),
          'updatedAt', fsdk.serverTimestamp()
        )
      );
    });

    it('completion requires the 20 distinct items of this attempt, each saved through a validated write', async () => {
      await seedParticipant('stu-a2');
      const { attempt, id } = await startedAttempt('stu-a2', 19);
      // A foreign or invented key can never be added, so the map cannot reach
      // 20 entries without the 20th real item.
      const b1 = itemsOf('B1')[0];
      await rut.assertFails(
        saveAnswer(db('stu-a2'), id, b1.id, {
          optionId: b1.options[0].id, optionText: b1.options[0].text, displayPosition: 1, answeredAt: fsdk.serverTimestamp(),
        })
      );
      await rut.assertFails(saveAnswer(db('stu-a2'), id, 'A2-99', answerFor(attempt, attempt.itemOrder[19], 1)));
      await rut.assertFails(complete(db('stu-a2'), id));
      await rut.assertSucceeds(saveAnswer(db('stu-a2'), id, attempt.itemOrder[19], answerFor(attempt, attempt.itemOrder[19], 5)));
      await rut.assertSucceeds(complete(db('stu-a2'), id));
      const stored = await readTrusted(ATTEMPTS, id);
      assert.deepEqual(Object.keys(stored.responses).sort(), attempt.itemOrder.slice().sort());
    });

    it('a completed attempt cannot be replaced through a full-document set', async () => {
      await seedParticipant('stu-a2');
      const { id } = await startedAttempt('stu-a2', 20);
      await rut.assertSucceeds(complete(db('stu-a2'), id));
      const stored = await readTrusted(ATTEMPTS, id);
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, id), { ...stored, status: 'in_progress', completedAt: null }));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, id), { status: 'completed' }, { merge: true }));
    });

    it('a posttest cannot be created under the pretest ID or with stage/ID mismatches', async () => {
      await seedParticipant('stu-a2', { preTest: 1, postTest: 0 });
      const pre = await startedAttempt('stu-a2', 20);
      await rut.assertSucceeds(complete(db('stu-a2'), pre.id));
      await rut.assertFails(
        fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2', 'preTest', 1)), newAttempt('stu-a2', { stage: 'postTest' }))
      );
      await rut.assertFails(
        fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2', 'postTest', 1)), newAttempt('stu-a2', { stage: 'preTest' }))
      );
      await rut.assertFails(
        fsdk.setDoc(fsdk.doc(db('stu-a2'), ATTEMPTS, attemptId('stu-a2', 'postTest', 1)), newAttempt('stu-a2', { stage: 'postTest' }))
      );
    });
  });
});
