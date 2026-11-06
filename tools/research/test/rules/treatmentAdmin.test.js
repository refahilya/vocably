'use strict';

/**
 * Research treatment tooling (`lib/admin/treatmentOperations.js`) against
 * the LOCAL emulators: seeding the locked plan and the study's treatment
 * configuration, refusing to replace a plan in use, and repairing a lost
 * completion record only from complete evidence. Synthetic bank and words.
 * Runs only inside `npm run test:rules`.
 */

const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const projectId = process.env.GCLOUD_PROJECT || '';
const RUN = /^(127\.0\.0\.1|localhost):\d+$/.test(emulatorHost) && projectId.startsWith('demo-');

describe('research treatment tooling (emulator)', { skip: !RUN && 'not inside the emulators (npm run test:rules)' }, () => {
  let admin;
  let ops;
  let pops;
  let tops;
  let fixtures;
  let planLib;
  const REPO_ROOT = path.join(__dirname, '..', '..', '..', '..');

  before(() => {
    ops = require('../../lib/admin/operations');
    pops = require('../../lib/admin/placementOperations');
    tops = require('../../lib/admin/treatmentOperations');
    fixtures = require('../researchFixtures');
    planLib = require('../../lib/treatment/plan');
    const { resolveTarget, initAdmin } = require('../../lib/admin/target');
    admin = initAdmin(resolveTarget({ emulator: true }, { env: process.env, repoRoot: REPO_ROOT }));
  });
  after(async () => {
    await admin.app.delete();
  });

  const db = () => admin.db;
  const plan = (version = 't1', seed = 'ab'.repeat(32)) =>
    planLib.buildTreatmentPlan({ bank: fixtures.bank, bankSha256: fixtures.bankSha256, planVersion: version, seed, createdAt: '2026-11-03T00:00:00.000Z' });
  const seed = (p, extra = {}) => tops.seedTreatment(db(), { plan: p, bank: fixtures.bank, bankSha256: fixtures.bankSha256, apply: true, ...extra });

  async function clear() {
    for (const col of ['researchTreatmentPlan', 'researchStudy', 'targetWordSets', 'learningSessions', 'researchTreatment', 'researchParticipants']) {
      const docs = (await db().collection(col).get()).docs;
      for (const d of docs) await d.ref.delete();
    }
  }

  beforeEach(async () => {
    await clear();
    await pops.setStudyStatus(db(), { status: 'active', apply: true });
  });

  it('seeds the plan once (create, then unchanged) and sets the study config', async () => {
    const first = await seed(plan());
    assert.deepEqual(first.actions.filter((a) => a.type === 'create').length, 4);
    const study = (await db().collection('researchStudy').doc('current').get()).data();
    assert.deepEqual(study.treatment, { planVersion: 't1', makeupDeadlineDays: 2 });
    const again = await seed(plan());
    assert.ok(again.actions.every((a) => a.type === 'unchanged'));
    const doc = (await db().collection('researchTreatmentPlan').doc('t1_A2').get()).data();
    assert.equal(doc.sessions['1'].length, 5);
  });

  it('never overwrites an allocation; adjusts only the make-up deadline', async () => {
    await seed(plan());
    await assert.rejects(seed(plan('t1', 'cd'.repeat(32))), /different allocation/);
    const result = await seed(plan(), { makeupDeadlineDays: 3 });
    assert.equal(result.actions.at(-1).type, 'update');
    assert.equal((await db().collection('researchStudy').doc('current').get()).get('treatment.makeupDeadlineDays'), 3);
    await assert.rejects(seed(plan(), { makeupDeadlineDays: 0 }), /makeup-days/);
  });

  it('switches the plan version only while no session of the old one exists', async () => {
    await seed(plan());
    await seed(plan('t2', 'cd'.repeat(32)));
    assert.equal((await db().collection('researchStudy').doc('current').get()).get('treatment.planVersion'), 't2');
    await db().collection('targetWordSets').doc('rt_t2_A2_s1_o1').set({ research: { planVersion: 't2', band: 'A2', session: 1, kind: 'regular', opening: 1 } });
    await assert.rejects(seed(plan('t3', 'ef'.repeat(32))), /already in use/);
  });

  it('refuses a plan that does not match the bank, and a dry run writes nothing', async () => {
    await assert.rejects(seed({ ...plan(), bankSha256: '0'.repeat(64) }), /bankSha256/);
    await seed(plan(), { apply: false });
    assert.equal((await db().collection('researchTreatmentPlan').get()).size, 0);
  });

  it('the treatment export reads the emulator and writes only counts, keyed by research ID', async () => {
    const os = require('os');
    const fsx = require('fs');
    await seed(plan());
    await db().collection('researchParticipants').doc('stu1').set({ researchId: 'R-1', band: 'A2', cohort: 'study', status: 'enrolled', authorizedAttempts: { placement: 1, preTest: 1, postTest: 0 } });
    const w = (await db().collection('researchTreatmentPlan').doc('t1_A2').get()).get('sessions')['1'];
    await db().collection('targetWordSets').doc('rt_t1_A2_s1_o1').set({ wordIds: w, targetStudentIds: ['stu1'], startAt: new Date(), endAt: new Date(Date.now() + 3600e3), research: { planVersion: 't1', instrumentVersion: 'v1', band: 'A2', session: 1, kind: 'regular', opening: 1 } });
    await db().collection('learningSessions').doc('ls1').set({ studentId: 'stu1', wordIds: w, sourceType: 'targetGuru', currentPhase: 'selesai', startedAt: new Date(), completedAt: new Date(), clozeTestResult: { [w[0]]: true }, cowriteTranscript: [{ sender: 'siswa', text: 'PRIVATE TEXT', usedSuggestion: false }], cowriteWordsUsedCorrectly: [], targetWordSetId: 'rt_t1_A2_s1_o1', researchSession: 1 });
    await db().collection('learningSessions').doc('ls0').set({ studentId: 'stu1', wordIds: [w[1]], sourceType: 'keranjangPelajari', currentPhase: 'membaca', startedAt: new Date(Date.now() - 864e5), completedAt: null });
    await db().collection('researchTreatment').doc('stu1').set({ studentId: 'stu1', planVersion: 't1', lastRecorded: 1, sessions: { 1: { sessionId: 'ls1', setId: 'rt_t1_A2_s1_o1', kind: 'regular', recordedAt: new Date() } } });
    const dir = fsx.mkdtempSync(path.join(os.tmpdir(), 'vocably-treatment-export-'));
    const { run } = require('../../bin/export_treatment');
    const result = await run(['--emulator', '--out-dir', dir], { log: () => {} });
    assert.equal(result.summaryRows[0].sessions_completed, 1);
    assert.equal(result.exposureRows[0].period, 'before_pretest');
    const all = fsx.readdirSync(dir).map((n) => fsx.readFileSync(path.join(dir, n), 'utf8')).join(' ');
    assert.ok(!all.includes('PRIVATE TEXT'));
    await assert.rejects(run(['--emulator', '--out-dir', dir], { log: () => {} }), /overwrite/);
    fsx.rmSync(dir, { recursive: true, force: true });
  });

  describe('treatment-record (repair)', () => {
    const words = ['wa', 'wb', 'wc', 'wd', 'we'];
    async function evidence({ phase = 'selesai', cloze = 5, transcript = 2, owner = 'stu1', targets = ['stu1'] } = {}) {
      await db().collection(ops.PARTICIPANTS).doc('stu1').set({ researchId: 'R-1', band: 'A2', status: 'enrolled', authorizedAttempts: { preTest: 1, postTest: 0 } });
      await db().collection('targetWordSets').doc('rt_t1_A2_s1_o1').set({
        wordIds: words, targetStudentIds: targets, research: { planVersion: 't1', instrumentVersion: 'v1', band: 'A2', session: 1, kind: 'regular', opening: 1 },
      });
      await db().collection('learningSessions').doc('ls1').set({
        studentId: owner, wordIds: words, currentPhase: phase, completedAt: phase === 'selesai' ? new Date() : null,
        clozeTestResult: Object.fromEntries(words.slice(0, cloze).map((w) => [w, true])),
        cowriteTranscript: Array.from({ length: transcript }, () => ({ sender: 'siswa', text: 'x' })),
        targetWordSetId: 'rt_t1_A2_s1_o1', researchSession: 1,
      });
    }
    const repair = (apply = true) => tops.recordTreatmentSession(db(), { uid: 'stu1', sessionId: 'ls1', reason: 'koneksi putus saat selesai', apply });

    it('records a completed official session once, marked as tooling', async () => {
      await evidence();
      await repair(false);
      assert.equal((await db().collection('researchTreatment').doc('stu1').get()).exists, false, 'dry run');
      await repair();
      const r = (await db().collection('researchTreatment').doc('stu1').get()).data();
      assert.equal(r.sessions['1'].recordedBy, 'tooling');
      assert.equal(r.lastRecorded, 1);
      await assert.rejects(repair(), /already recorded/);
      const [row] = await ops.stageStatus(db(), { uid: 'stu1' });
      assert.deepEqual(row.treatment, ['1']);
    });

    it('refuses incomplete evidence', async () => {
      for (const bad of [{ phase: 'coWrite' }, { cloze: 4 }, { transcript: 0 }, { owner: 'stu2' }, { targets: ['stu2'] }]) {
        await clear();
        await evidence(bad);
        await assert.rejects(repair(), /Refused/);
      }
      await assert.rejects(tops.recordTreatmentSession(db(), { uid: 'stu1', sessionId: 'ls1', reason: '', apply: true }), /reason/);
    });
  });
});
