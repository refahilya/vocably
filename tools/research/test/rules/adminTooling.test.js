'use strict';

/**
 * Researcher admin tooling (lib/admin/operations.js, bin/research_admin.js)
 * against the LOCAL emulators, with the real firestore.rules checking what
 * students can do afterwards. Runs only inside `npm run test:rules`
 * (demo project); skipped everywhere else. All accounts are synthetic.
 */

const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const projectId = process.env.GCLOUD_PROJECT || '';
const RUN = /^(127\.0\.0\.1|localhost):\d+$/.test(emulatorHost) && projectId.startsWith('demo-');

describe('researcher admin tooling (emulator)', { skip: !RUN && 'not inside the emulators (npm run test:rules)' }, () => {
  let rut;
  let fsdk;
  let env;
  let admin;
  let ops;
  let fixtures;
  const REPO_ROOT = path.join(__dirname, '..', '..', '..', '..');

  before(async () => {
    rut = require('@firebase/rules-unit-testing');
    fsdk = require('firebase/firestore');
    ops = require('../../lib/admin/operations');
    fixtures = require('../researchFixtures');
    const { resolveTarget, initAdmin } = require('../../lib/admin/target');
    env = await rut.initializeTestEnvironment({
      projectId,
      firestore: { rules: fs.readFileSync(path.join(REPO_ROOT, 'firestore.rules'), 'utf8') },
    });
    admin = initAdmin(resolveTarget({ emulator: true }, { env: process.env, repoRoot: REPO_ROOT }));
  });

  after(async () => {
    await env.cleanup();
    await admin.app.delete();
  });

  beforeEach(async () => {
    await env.clearFirestore();
  });

  const db = () => admin.db;
  const client = (uid) => env.authenticatedContext(uid).firestore();
  const seedBank = () => ops.seedInstrument(db(), { bank: fixtures.bank, bankJson: fixtures.bankJson, apply: true });

  async function user(uid, role = 'siswa') {
    await db().collection('users').doc(uid).set({ uid, email: `${uid}@example.test`, name: uid, role });
  }

  async function enrol(uid, band = 'A2', researchId = `R-${uid}`, cohort = 'study') {
    await user(uid);
    await ops.enrolParticipants(db(), { rows: [{ line: 2, uid, researchId, band, cohort }], apply: true });
  }

  const participant = async (uid) => (await db().collection(ops.PARTICIPANTS).doc(uid).get()).data();

  /** A student creates an attempt (as the app would) and answers [count] items with "tidak tahu". */
  async function studentAttempt(uid, { stage = 'preTest', n = 1, band = 'A2', count = 0, complete = false } = {}) {
    const { itemOrder, optionOrder } = fixtures.orderFor(band);
    const ref = fsdk.doc(client(uid), ops.ATTEMPTS, `${uid}_${stage}_${n}`);
    await rut.assertSucceeds(
      fsdk.setDoc(ref, {
        studentId: uid, stage, attemptNumber: n, band, instrumentVersion: 'v1', itemOrder, optionOrder,
        responses: {}, lastAnsweredItemId: null, status: 'in_progress',
        startedAt: fsdk.serverTimestamp(), updatedAt: fsdk.serverTimestamp(), completedAt: null,
      })
    );
    for (const itemId of itemOrder.slice(0, count)) {
      await rut.assertSucceeds(answer(uid, `${uid}_${stage}_${n}`, itemId));
    }
    if (complete) {
      await rut.assertSucceeds(
        fsdk.updateDoc(ref, { status: 'completed', completedAt: fsdk.serverTimestamp(), updatedAt: fsdk.serverTimestamp() })
      );
    }
    return ref;
  }

  function answer(uid, id, itemId) {
    return fsdk.updateDoc(
      fsdk.doc(client(uid), ops.ATTEMPTS, id),
      new fsdk.FieldPath('responses', itemId),
      { optionId: 'dont_know', optionText: 'Saya tidak tahu kata ini', displayPosition: 5, answeredAt: fsdk.serverTimestamp() },
      'lastAnsweredItemId', itemId,
      'updatedAt', fsdk.serverTimestamp()
    );
  }

  describe('seed-instrument', () => {
    it('dry run writes nothing; apply creates the 4 band documents; a re-run is unchanged', async () => {
      const dry = await ops.seedInstrument(db(), { bank: fixtures.bank, bankJson: fixtures.bankJson });
      assert.deepEqual(dry.actions.map((a) => a.type), ['create', 'create', 'create', 'create']);
      assert.equal((await db().collection(ops.INSTRUMENT).get()).size, 0);
      await seedBank();
      const docs = await db().collection(ops.INSTRUMENT).get();
      assert.deepEqual(docs.docs.map((d) => d.id).sort(), ['v1_A2', 'v1_B1', 'v1_B2', 'v1_C1']);
      assert.equal(docs.docs[0].get('sourceBankSha256'), fixtures.bankSha256);
      assert.deepEqual((await seedBank()).actions.map((a) => a.type), ['unchanged', 'unchanged', 'unchanged', 'unchanged']);
    });

    it('never overwrites a bank document with different content', async () => {
      await seedBank();
      await db().collection(ops.INSTRUMENT).doc('v1_B1').update({ sourceBankSha256: 'other' });
      await assert.rejects(seedBank(), /v1_B1 already exists with different content/);
    });

    it('students can neither read nor write the bank documents', async () => {
      await seedBank();
      await rut.assertFails(fsdk.getDoc(fsdk.doc(client('stu1'), ops.INSTRUMENT, 'v1_A2')));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(client('stu1'), ops.INSTRUMENT, 'v1_A2'), {}));
    });
  });

  describe('enrol', () => {
    it('dry run writes nothing; apply creates the exact participant record', async () => {
      await user('stu100001');
      const rows = [{ line: 2, uid: 'stu100001', researchId: 'R-01', band: 'B2', cohort: 'pilot' }];
      await ops.enrolParticipants(db(), { rows });
      assert.equal((await db().collection(ops.PARTICIPANTS).get()).size, 0);
      await ops.enrolParticipants(db(), { rows, apply: true });
      const p = await participant('stu100001');
      assert.deepEqual(
        { ...p, createdAt: typeof p.createdAt, updatedAt: typeof p.updatedAt },
        { researchId: 'R-01', band: 'B2', bandSource: 'researcher_assigned', instrumentVersion: 'v1', authorizedAttempts: { preTest: 0, postTest: 0 }, cohort: 'pilot', createdAt: 'object', updatedAt: 'object' }
      );
    });

    it('refuses re-enrolment, reused research IDs, non-students and missing profiles — atomically', async () => {
      await enrol('stu100001', 'A2', 'R-01');
      await user('guru00001', 'guru');
      await user('stu100002');
      const rows = [
        { line: 2, uid: 'stu100002', researchId: 'R-02', band: 'A2', cohort: 'study' },
        { line: 3, uid: 'stu100001', researchId: 'R-03', band: 'A2', cohort: 'study' },
        { line: 4, uid: 'stu100003', researchId: 'R-01', band: 'A2', cohort: 'study' },
        { line: 5, uid: 'guru00001', researchId: 'R-04', band: 'A2', cohort: 'study' },
      ];
      await assert.rejects(ops.enrolParticipants(db(), { rows, apply: true }), (error) => {
        assert.ok(error.problems.includes('line 3: already enrolled (enrolment never overwrites)'));
        assert.ok(error.problems.includes('line 4: researchId already used by another participant'));
        assert.ok(error.problems.includes('line 4: no users/{uid} profile for this account'));
        assert.ok(error.problems.includes('line 5: the account is not a student (role must be "siswa")'));
        return true;
      });
      assert.equal((await db().collection(ops.PARTICIPANTS).doc('stu100002').get()).exists, false, 'valid row not written either');
    });

    it('students read only their own record and can never write one', async () => {
      await enrol('stu100001');
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(client('stu100001'), ops.PARTICIPANTS, 'stu100001')));
      await rut.assertFails(fsdk.getDoc(fsdk.doc(client('stu100002'), ops.PARTICIPANTS, 'stu100001')));
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(client('stu100001'), ops.PARTICIPANTS, 'stu100001'), { 'authorizedAttempts.preTest': 1 }));
    });
  });

  describe('authorize', () => {
    it('refuses until the bank is seeded, then authorizes pretest 0 → 1 exactly once', async () => {
      await enrol('stu100001');
      await assert.rejects(ops.authorizeStage(db(), { uids: ['stu100001'], stage: 'preTest', apply: true }), /not seeded/);
      await seedBank();
      await assert.rejects(ops.authorizeStage(db(), { uids: ['nobody000'], stage: 'preTest' }), /nobody000: not enrolled/);
      const dry = await ops.authorizeStage(db(), { uids: ['stu100001'], stage: 'preTest' });
      assert.equal(dry.actions.length, 1);
      assert.equal((await participant('stu100001')).authorizedAttempts.preTest, 0);
      await ops.authorizeStage(db(), { uids: ['stu100001'], stage: 'preTest', apply: true });
      assert.equal((await participant('stu100001')).authorizedAttempts.preTest, 1);
      await assert.rejects(ops.authorizeStage(db(), { uids: ['stu100001'], stage: 'preTest', apply: true }), /already authorized/);
      await rut.assertSucceeds(studentAttempt('stu100001'));
    });

    it('cohort mode authorizes the eligible and reports the rest', async () => {
      await seedBank();
      await enrol('stu100001', 'A2', 'R-01');
      await enrol('stu100002', 'B1', 'R-02');
      await enrol('stu100003', 'C1', 'R-03', 'pilot');
      await ops.authorizeStage(db(), { uids: ['stu100002'], stage: 'preTest', apply: true });
      const result = await ops.authorizeStage(db(), { cohort: 'study', stage: 'preTest', apply: true });
      assert.deepEqual(result.actions.map((a) => a.researchId), ['R-01']);
      assert.deepEqual(result.skipped.map((s) => s.researchId), ['R-02']);
      assert.equal((await participant('stu100003')).authorizedAttempts.preTest, 0, 'other cohort untouched');
    });

    it('the posttest needs the researcher attestation and a completed pretest', async () => {
      await seedBank();
      await enrol('stu100001');
      await ops.authorizeStage(db(), { uids: ['stu100001'], stage: 'preTest', apply: true });
      await assert.rejects(ops.authorizeStage(db(), { uids: ['stu100001'], stage: 'postTest', apply: true }), /confirm-session4-completed/);
      await studentAttempt('stu100001', { count: 19 });
      await assert.rejects(
        ops.authorizeStage(db(), { uids: ['stu100001'], stage: 'postTest', confirmSession4: true, apply: true }),
        /pretest not completed/
      );
      // A student can't open the posttest themselves either.
      await rut.assertFails(studentAttempt('stu100001', { stage: 'postTest' }));

      await rut.assertSucceeds(answer('stu100001', 'stu100001_preTest_1', fixtures.orderFor('A2').itemOrder[19]));
      await rut.assertSucceeds(
        fsdk.updateDoc(fsdk.doc(client('stu100001'), ops.ATTEMPTS, 'stu100001_preTest_1'), {
          status: 'completed', completedAt: fsdk.serverTimestamp(), updatedAt: fsdk.serverTimestamp(),
        })
      );
      const result = await ops.authorizeStage(db(), { uids: ['stu100001'], stage: 'postTest', confirmSession4: true, apply: true });
      assert.match(result.actions[0].attestation, /session 4/);
      await rut.assertSucceeds(studentAttempt('stu100001', { stage: 'postTest' }));
    });
  });

  describe('void and retake', () => {
    beforeEach(async () => {
      await seedBank();
      await enrol('stu100001');
      await ops.authorizeStage(db(), { uids: ['stu100001'], stage: 'preTest', apply: true });
    });

    it('voiding keeps every answer, needs a reason, and freezes the attempt for the student', async () => {
      await studentAttempt('stu100001', { count: 4 });
      await assert.rejects(ops.voidAttempt(db(), { uid: 'stu100001', stage: 'preTest', reason: ' ', apply: true }), /--reason/);
      await assert.rejects(ops.voidAttempt(db(), { uid: 'stu100001', stage: 'preTest', reason: 'a\nb', apply: true }), /single line/);
      const result = await ops.voidAttempt(db(), { uid: 'stu100001', stage: 'preTest', reason: 'koneksi terputus', apply: true });
      assert.deepEqual([result.actions[0].previousStatus, result.actions[0].answered], ['in_progress', 4]);
      const stored = (await db().collection(ops.ATTEMPTS).doc('stu100001_preTest_1').get()).data();
      assert.equal(stored.status, 'voided');
      assert.equal(stored.voidReason, 'koneksi terputus');
      assert.equal(Object.keys(stored.responses).length, 4);
      await rut.assertFails(answer('stu100001', 'stu100001_preTest_1', fixtures.orderFor('A2').itemOrder[4]));
      await assert.rejects(ops.voidAttempt(db(), { uid: 'stu100001', stage: 'preTest', reason: 'lagi', apply: true }), /already voided/);
    });

    it('a completed attempt is voided only with allowCompleted; never-started attempts cannot be voided', async () => {
      await assert.rejects(ops.voidAttempt(db(), { uid: 'stu100001', stage: 'preTest', reason: 'x', apply: true }), /never started/);
      await studentAttempt('stu100001', { count: 20, complete: true });
      await assert.rejects(ops.voidAttempt(db(), { uid: 'stu100001', stage: 'preTest', reason: 'x', apply: true }), /allow-completed/);
      await ops.voidAttempt(db(), { uid: 'stu100001', stage: 'preTest', reason: 'bantuan teman', allowCompleted: true, apply: true });
      assert.equal((await db().collection(ops.ATTEMPTS).doc('stu100001_preTest_1').get()).get('status'), 'voided');
    });

    it('a retake needs a voided current attempt and opens attempt n+1 only', async () => {
      await studentAttempt('stu100001', { count: 2 });
      await assert.rejects(ops.authorizeRetake(db(), { uid: 'stu100001', stage: 'preTest', reason: 'x', apply: true }), /void attempt 1/);
      await ops.voidAttempt(db(), { uid: 'stu100001', stage: 'preTest', reason: 'listrik padam', apply: true });
      const dry = await ops.authorizeRetake(db(), { uid: 'stu100001', stage: 'preTest', reason: 'listrik padam' });
      assert.deepEqual([dry.actions[0].fromAttempt, dry.actions[0].toAttempt], [1, 2]);
      assert.equal((await participant('stu100001')).authorizedAttempts.preTest, 1);
      await ops.authorizeRetake(db(), { uid: 'stu100001', stage: 'preTest', reason: 'listrik padam', apply: true });
      assert.equal((await participant('stu100001')).authorizedAttempts.preTest, 2);
      await rut.assertSucceeds(studentAttempt('stu100001', { n: 2 }));
      await rut.assertFails(studentAttempt('stu100001', { n: 3 }));
      assert.equal((await db().collection(ops.ATTEMPTS).doc('stu100001_preTest_1').get()).exists, true, 'old attempt kept');
    });

    it('pretest void or retake is refused once the posttest is authorized', async () => {
      await studentAttempt('stu100001', { count: 20, complete: true });
      await ops.authorizeStage(db(), { uids: ['stu100001'], stage: 'postTest', confirmSession4: true, apply: true });
      await assert.rejects(
        ops.voidAttempt(db(), { uid: 'stu100001', stage: 'preTest', reason: 'x', allowCompleted: true, apply: true }),
        /posttest is already authorized/
      );
    });

    it('status lists authorization and every attempt', async () => {
      await studentAttempt('stu100001', { count: 3 });
      const [row] = await ops.stageStatus(db(), { uid: 'stu100001' });
      assert.deepEqual(row.stages.preTest, { authorized: 1, attempts: [{ n: 1, status: 'in_progress', answered: 3 }] });
      assert.deepEqual(row.stages.postTest, { authorized: 0, attempts: [] });
    });
  });

  describe('command line', () => {
    it('dry-runs by default, applies with --apply, and appends to the audit log', async () => {
      const { run } = require('../../bin/research_admin');
      const logPath = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'vocably-audit-')), 'audit.private.jsonl');
      const quiet = console.log;
      console.log = () => {};
      try {
        await run(['seed-instrument', '--emulator', '--log', logPath]);
        assert.equal((await db().collection(ops.INSTRUMENT).get()).size, 0);
        await run(['seed-instrument', '--emulator', '--apply', '--log', logPath]);
        assert.equal((await db().collection(ops.INSTRUMENT).get()).size, 4);
        await assert.rejects(run(['void', '--emulator', '--uid', 'nobody000', '--stage', 'preTest', '--reason', 'x', '--log', logPath]));
      } finally {
        console.log = quiet;
      }
      const entries = fs.readFileSync(logPath, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
      assert.deepEqual(entries.map((e) => [e.command, e.apply, e.outcome]), [
        ['seed-instrument', false, 'ok'],
        ['seed-instrument', true, 'ok'],
        ['void', false, 'refused'],
      ]);
      assert.ok(entries.every((e) => e.target.mode === 'emulator' && e.target.projectId.startsWith('demo-')));
    });
  });
});
