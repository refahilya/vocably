'use strict';

/**
 * Researcher placement/study operations (lib/admin/placementOperations.js)
 * against the local emulator, together with the client rules they feed.
 * Synthetic key and participants only; skipped outside the emulator.
 */

const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const projectId = process.env.GCLOUD_PROJECT || '';
const { INSTRUMENT_VERSION: V } = require('../../lib/constants');
const RUN = /^(127\.0\.0\.1|localhost):\d+$/.test(emulatorHost) && projectId.startsWith('demo-');

const REPO_ROOT = path.join(__dirname, '..', '..', '..', '..');
const bankJson = fs.readFileSync(path.join(REPO_ROOT, 'assets', 'placement', 'placement_bank_pt_v1_1.json'), 'utf8').replace(/\r\n/g, '\n');
const bank = JSON.parse(bankJson);
const bankSha256 = require('crypto').createHash('sha256').update(bankJson).digest('hex');
const LETTERS = ['A', 'B', 'C', 'D'];
const syntheticKeyFile = () => ({
  instrumentVersion: bank.instrumentVersion,
  bankSha256,
  key: Object.fromEntries(bank.items.map((i) => [i.id, LETTERS[i.number % 4]])),
});

describe('placement admin operations (emulator)', { skip: !RUN && 'not inside the Firestore emulator (npm run test:rules)' }, () => {
  let rut;
  let env;
  let admin;
  let ops;
  let pops;

  before(async () => {
    rut = require('@firebase/rules-unit-testing');
    ops = require('../../lib/admin/operations');
    pops = require('../../lib/admin/placementOperations');
    const { resolveTarget, initAdmin } = require('../../lib/admin/target');
    env = await rut.initializeTestEnvironment({ projectId, firestore: { rules: fs.readFileSync(path.join(REPO_ROOT, 'firestore.rules'), 'utf8') } });
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
  const get = async (col, id) => (await db().collection(col).doc(id).get()).data();
  const { FieldValue } = require('firebase-admin/firestore');

  async function pending(uid, extra = {}) {
    await db().collection('users').doc(uid).set({ uid, email: `${uid}@example.test`, name: uid, role: 'siswa' });
    await db().collection('researchParticipants').doc(uid).set({
      researchId: `R-${uid}`, band: null, bandSource: null, status: 'awaiting_placement', exclusionReason: null,
      placementAttemptId: null, reviewStatus: null, instrumentVersion: V,
      authorizedAttempts: { placement: 1, preTest: 0, postTest: 0 }, cohort: 'test',
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), ...extra,
    });
  }

  async function attempt(uid, status, extra = {}) {
    await db().collection('placementAttempts').doc(`${uid}_research_1`).set({
      studentId: uid, context: 'research', attemptNumber: 1, instrumentVersion: bank.instrumentVersion,
      itemOrder: [], answers: {}, status, ...extra,
    });
  }

  describe('seed-placement', () => {
    it('seeds the public instrument, the unreadable key and a closed learning config; never overwrites', async () => {
      const dry = await pops.seedPlacement(db(), { bank, bankSha256, keyFile: syntheticKeyFile() });
      assert.equal(dry.applied, false);
      assert.equal(await get('placementKey', bank.instrumentVersion), undefined);
      await pops.seedPlacement(db(), { bank, bankSha256, keyFile: syntheticKeyFile(), apply: true });
      const inst = await get('placementInstrument', bank.instrumentVersion);
      assert.equal(inst.bandItems.A1.length, 10);
      assert.equal((await get('placementConfig', 'current')).learningOpen, false);
      const again = await pops.seedPlacement(db(), { bank, bankSha256, keyFile: syntheticKeyFile(), apply: true });
      assert.ok(again.actions.every((a) => a.type === 'unchanged'));
      const other = syntheticKeyFile();
      other.key[bank.items[0].id] = other.key[bank.items[0].id] === 'A' ? 'B' : 'A';
      await assert.rejects(pops.seedPlacement(db(), { bank, bankSha256, keyFile: other, apply: true }), /different content/);
      const client = env.authenticatedContext('u1').firestore();
      const { getDoc, doc } = require('firebase/firestore');
      await rut.assertFails(getDoc(doc(client, 'placementKey', bank.instrumentVersion)));
    });

    it('refuses a key file for another bank', async () => {
      const keyFile = { ...syntheticKeyFile(), bankSha256: 'nope' };
      await assert.rejects(pops.seedPlacement(db(), { bank, bankSha256, keyFile, apply: true }), /bankSha256/);
    });
  });

  describe('study and stage windows', () => {
    it('setup → active → closed (final); windows open with server time and close at server time', async () => {
      await pops.setStudyStatus(db(), { status: 'setup', apply: true });
      await assert.rejects(pops.setStudyStatus(db(), { status: 'closed', apply: true }), /not allowed/);
      await pops.setStudyStatus(db(), { status: 'active', apply: true });
      await pops.setStageWindow(db(), { stage: 'placement', open: true, apply: true });
      let w = (await get('researchStudy', 'current')).stages.placement;
      assert.ok(w.openAt.toMillis() <= Date.now() && w.closeAt.toMillis() > Date.now());
      await pops.setStageWindow(db(), { stage: 'placement', close: true, apply: true });
      w = (await get('researchStudy', 'current')).stages.placement;
      assert.ok(w.closeAt.toMillis() <= Date.now() + 1000);
      await assert.rejects(pops.setStageWindow(db(), { stage: 'placement', close: true, apply: true }), /not open/);
      await assert.rejects(pops.setStageWindow(db(), { stage: 'preTest', open: true, closeAt: '2000-01-01T00:00:00Z' }), /future/);
      await pops.setStudyStatus(db(), { status: 'closed', apply: true });
      assert.ok((await get('researchStudy', 'current')).closedAt);
      await assert.rejects(pops.setStudyStatus(db(), { status: 'active', apply: true }), /closed is final/);
      await assert.rejects(pops.setStageWindow(db(), { stage: 'preTest', open: true, apply: true }), /closed/);
    });
  });

  describe('review, void, retake, restore, manual band', () => {
    it('a technical void revokes the automatic band and allows a retake (new attempt number)', async () => {
      await pending('p1', { band: 'B1', bandSource: 'placement_test', status: 'enrolled', placementAttemptId: 'p1_research_1' });
      await attempt('p1', 'scored', { pretestTargetBand: 'B1', resultLevel: 'A2' });
      await assert.rejects(pops.retakePlacement(db(), { uid: 'p1', reason: 'x', apply: true }), /void placement attempt 1 first/);
      await pops.voidPlacement(db(), { uid: 'p1', category: 'technical', reason: 'perangkat mati', apply: true });
      const p = await get('researchParticipants', 'p1');
      assert.deepEqual([p.band, p.status, p.placementAttemptId], [null, 'awaiting_placement', null]);
      assert.equal(p.bandHistory[0].change, 'revoked');
      const a = await get('placementAttempts', 'p1_research_1');
      assert.deepEqual([a.status, a.voidCategory, a.voidedFromStatus], ['voided', 'technical', 'scored']);
      assert.ok(!('voidReason' in a), 'the reason is not stored on the student-readable attempt');
      await pops.retakePlacement(db(), { uid: 'p1', reason: 'perangkat mati', apply: true });
      assert.equal((await get('researchParticipants', 'p1')).authorizedAttempts.placement, 2);
      const reviews = await db().collection('researchReviews').where('uid', '==', 'p1').get();
      assert.equal(reviews.size, 2);
    });

    it('an integrity void needs a confirmed human review and never allows a replacement attempt', async () => {
      await pending('p1');
      await attempt('p1', 'submitted');
      await assert.rejects(pops.voidPlacement(db(), { uid: 'p1', category: 'integrity', reason: 'x', apply: true }), /confirmed human review/);
      await pops.setReview(db(), { uid: 'p1', open: true, reason: 'laporan pengawas', apply: true });
      assert.equal((await get('researchParticipants', 'p1')).reviewStatus, 'pending');
      await assert.rejects(pops.voidPlacement(db(), { uid: 'p1', category: 'integrity', reason: 'x', apply: true }), /confirmed human review/);
      await pops.setReview(db(), { uid: 'p1', close: true, outcome: 'confirmed', reason: 'diperiksa', apply: true });
      await pops.voidPlacement(db(), { uid: 'p1', category: 'integrity', reason: 'terbukti', apply: true });
      assert.equal((await get('researchParticipants', 'p1')).status, 'awaiting_manual_band');
      await assert.rejects(pops.retakePlacement(db(), { uid: 'p1', reason: 'x', apply: true }), /no replacement research attempt/);
    });

    it('a manual band needs basis and reason, leaves the participant conditional, and authorize refuses it', async () => {
      await pending('p1', { status: 'awaiting_manual_band', reviewStatus: 'confirmed' });
      await attempt('p1', 'voided', { voidCategory: 'integrity' });
      await assert.rejects(pops.assignManualBand(db(), { uid: 'p1', band: 'B1', reason: 'x', apply: true }), /basis/);
      await assert.rejects(pops.assignManualBand(db(), { uid: 'p1', band: 'A1', basis: 'x', reason: 'x', apply: true }), /band must be/);
      await pops.assignManualBand(db(), { uid: 'p1', band: 'B1', basis: 'nilai rapor', reason: 'keputusan peneliti', apply: true });
      const p = await get('researchParticipants', 'p1');
      assert.deepEqual([p.band, p.bandSource, p.status], ['B1', 'manual_review', 'conditional']);
      await ops.seedInstrument(db(), { bank: require('../researchFixtures').bank, bankJson: require('../researchFixtures').bankJson, apply: true });
      await assert.rejects(ops.authorizeStage(db(), { uids: ['p1'], stage: 'preTest', apply: true }), /conditional/);
    });

    it('restore corrects an erroneous void of the same attempt and restores its band; no attempt is created', async () => {
      await pending('p1', { band: 'B2', bandSource: 'placement_test', status: 'enrolled', placementAttemptId: 'p1_research_1' });
      await attempt('p1', 'scored', { pretestTargetBand: 'B2', resultLevel: 'B1' });
      await pops.voidPlacement(db(), { uid: 'p1', category: 'technical', reason: 'keliru', apply: true });
      await pops.restorePlacement(db(), { uid: 'p1', reason: 'void keliru', apply: true });
      const p = await get('researchParticipants', 'p1');
      assert.deepEqual([p.band, p.status, p.placementAttemptId, p.authorizedAttempts.placement], ['B2', 'enrolled', 'p1_research_1', 1]);
      const a = await get('placementAttempts', 'p1_research_1');
      assert.equal(a.status, 'scored');
      assert.ok(!('voidCategory' in a));
      assert.equal((await db().collection('placementAttempts').get()).size, 1);
    });

    it('voiding is refused once the pretest is authorized', async () => {
      await pending('p1', { band: 'A2', bandSource: 'placement_test', status: 'enrolled', authorizedAttempts: { placement: 1, preTest: 1, postTest: 0 } });
      await attempt('p1', 'scored');
      await assert.rejects(pops.voidPlacement(db(), { uid: 'p1', category: 'technical', reason: 'x', apply: true }), /pretest is already authorized/);
    });
  });

  describe('authorize with placement bands', () => {
    it('refuses pending, excluded or under-review participants and needs the policy acknowledgement', async () => {
      await ops.seedInstrument(db(), { bank: require('../researchFixtures').bank, bankJson: require('../researchFixtures').bankJson, apply: true });
      await pending('p1');
      await pending('p2', { status: 'excluded', exclusionReason: 'placement_c1' });
      await pending('p3', { band: 'B1', bandSource: 'placement_test', status: 'enrolled', reviewStatus: 'pending' });
      await pending('p4', { band: 'B1', bandSource: 'placement_test', status: 'enrolled' });
      for (const uid of ['p1', 'p2', 'p3']) {
        await assert.rejects(ops.authorizeStage(db(), { uids: [uid], stage: 'preTest', apply: true }), /awaiting_placement|excluded|review/);
      }
      await assert.rejects(ops.authorizeStage(db(), { uids: ['p4'], stage: 'preTest', apply: true }), /acknowledge-placement-policy/);
      const ok = await ops.authorizeStage(db(), { uids: ['p4'], stage: 'preTest', acknowledgePlacementPolicy: true, apply: true });
      assert.match(ok.actions[0].placementPolicy, /not expert-validated/);
      assert.equal((await get('researchParticipants', 'p4')).authorizedAttempts.preTest, 1);
      const status = await ops.stageStatus(db(), {});
      assert.equal(status.find((r) => r.uid === 'p1').status, 'awaiting_placement');
      assert.equal(status.find((r) => r.uid === 'p1').band, null);
    });
  });

  it('status reports the stored level and target band, and nothing from the answers', async () => {
    await pending('s1');
    await attempt('s1', 'scored', {
      answers: { 'pt-a1-01': 'E', 'pt-a1-02': 'B' },
      resultLevel: 'B2', belowA1Threshold: false, pretestTargetBand: 'C1',
    });
    await pending('s2');
    await attempt('s2', 'in_progress', { answers: { 'pt-a1-01': 'A' } });
    await pending('s3');

    const rows = await ops.stageStatus(db(), {});
    const row = (uid) => rows.find((r) => r.uid === uid);
    // The participant record still has no band: the level comes from the attempt alone.
    assert.equal(row('s1').band, null);
    assert.deepEqual(row('s1').placement, { n: 1, status: 'scored', answered: 2, resultLevel: 'B2', belowA1Threshold: false, targetBand: 'C1' });
    assert.equal(ops.formatPlacementStatus(row('s1').placement), 'placement=#1 scored answered=2/50 level=B2 targetBand=C1');
    assert.equal(ops.formatPlacementStatus(row('s2').placement), 'placement=#1 in_progress answered=1/50 level=- targetBand=-');
    assert.equal(ops.formatPlacementStatus(row('s3').placement), 'placement=#1 not_started answered=0/50 level=- targetBand=-');
    assert.ok(!Object.keys(row('s1').placement).includes('answers'));
  });

  it('learning placement can be opened and closed', async () => {
    await pops.seedPlacement(db(), { bank, bankSha256, keyFile: syntheticKeyFile(), apply: true });
    await pops.setLearningPlacement(db(), { open: true, apply: true });
    assert.equal((await get('placementConfig', 'current')).learningOpen, true);
    await pops.setLearningPlacement(db(), { open: false, apply: true });
    assert.equal((await get('placementConfig', 'current')).learningOpen, false);
  });

  it('the emulator seed (manual testing) adds an open study, the placement bank and a pending-band participant', { skip: !process.env.FIREBASE_AUTH_EMULATOR_HOST && 'needs the Auth emulator' }, async () => {
    const { seedEmulator } = require('../../lib/admin/emulatorSeed');
    const { resolveTarget } = require('../../lib/admin/target');
    const fixtures = require('../researchFixtures');
    const target = resolveTarget({ emulator: true }, { env: process.env, repoRoot: REPO_ROOT });
    const result = await seedEmulator({ target, db: db(), auth: admin.auth, bank: fixtures.bank, bankJson: fixtures.bankJson, password: 'dummy-password' });
    assert.ok(result.accounts.some((a) => a.pendingPlacement === 'EMU-PT'));
    const p = await get('researchParticipants', 'emuStudentPlacement');
    assert.deepEqual([p.band, p.status, p.authorizedAttempts.placement], [null, 'awaiting_placement', 1]);
    assert.equal((await get('researchStudy', 'current')).status, 'active');
    assert.equal((await get('placementConfig', 'current')).learningOpen, true);
    assert.equal((await get('researchOperators', 'emuResearcher')).active, true);
    assert.equal(await get('researchOperators', 'emuTeacher'), undefined);
    assert.equal((await get('researchRoster', 'emuStudentPlacement')).researchId, 'EMU-PT');
    assert.equal((await get('researchRoster', 'emuStudentA2')).name, 'Siswa Uji A2');
    const a2 = await get('researchParticipants', 'emuStudentA2');
    assert.deepEqual([a2.band, a2.bandSource, a2.status, a2.authorizedAttempts.preTest], ['A2', 'placement_test', 'enrolled', 1]);
    for (const a of result.accounts) await admin.auth.deleteUser(a.uid);
  });
});
