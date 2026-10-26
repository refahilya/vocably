'use strict';

/**
 * End-to-end research flow on the LOCAL emulators, without the Flutter UI:
 *
 * 1. Trusted setup with the researcher tooling (dummy Auth account, profile,
 *    bank documents, enrolment, pretest authorization).
 * 2. The student signs in through the Auth emulator (real ID token, not a
 *    mocked one) and replays the EXACT payloads the app produces —
 *    `fixtures/client_payloads.json`, generated from the Dart payload
 *    builders by test/research_client_payloads_test.dart — against the real
 *    firestore.rules: create, interruption + resume, duplicate and changed
 *    answers, early completion, completion, posttest gating, void, retake.
 * 3. The offline export scores the result with a SYNTHETIC key.
 *
 * Runs only inside `npm run test:rules` (demo project).
 */

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '';
const projectId = process.env.GCLOUD_PROJECT || '';
const RUN =
  /^(127\.0\.0\.1|localhost):\d+$/.test(emulatorHost) &&
  /^(127\.0\.0\.1|localhost):\d+$/.test(authHost) &&
  projectId.startsWith('demo-');

const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'client_payloads.json'), 'utf8'));
const PASSWORD = 'emulator-only-dummy';
const EMAIL = 'e2e.student@example.test';

describe('app payloads and full flow (emulators, real Auth emulator sign-in)', { skip: !RUN && 'not inside the emulators (npm run test:rules)' }, () => {
  const REPO_ROOT = path.join(__dirname, '..', '..', '..', '..');
  let admin;
  let ops;
  let fixtures;
  let fsdk;
  let rut;
  let clients = [];

  before(async () => {
    rut = require('@firebase/rules-unit-testing');
    fsdk = require('firebase/firestore');
    ops = require('../../lib/admin/operations');
    fixtures = require('../researchFixtures');
    const { resolveTarget, initAdmin } = require('../../lib/admin/target');
    admin = initAdmin(resolveTarget({ emulator: true }, { env: process.env, repoRoot: REPO_ROOT }));

    // Fresh state (shared emulator, earlier files cleared their own data).
    const env = await rut.initializeTestEnvironment({ projectId, firestore: { rules: fs.readFileSync(path.join(REPO_ROOT, 'firestore.rules'), 'utf8') } });
    await env.clearFirestore();
    await env.cleanup();

    await admin.auth.createUser({ uid: fixture.uid, email: EMAIL, password: PASSWORD });
    await admin.db.collection('users').doc(fixture.uid).set({ uid: fixture.uid, email: EMAIL, name: 'E2E', role: 'siswa' });
    await ops.seedInstrument(admin.db, { bank: fixtures.bank, bankJson: fixtures.bankJson, apply: true });
    await ops.enrolParticipants(admin.db, { rows: [{ line: 2, uid: fixture.uid, researchId: 'E2E-01', band: fixture.band, cohort: 'test' }], apply: true });
    await ops.authorizeStage(admin.db, { uids: [fixture.uid], stage: 'preTest', apply: true });
  });

  after(async () => {
    for (const c of clients) await require('firebase/app').deleteApp(c.app);
    await admin.app.delete();
  });

  /** A fresh client app instance, signed in through the Auth emulator (as after an app restart). */
  async function signedInClient() {
    const { initializeApp } = require('firebase/app');
    const { getAuth, connectAuthEmulator, signInWithEmailAndPassword } = require('firebase/auth');
    const app = initializeApp({ projectId, apiKey: 'demo-api-key' }, `client-${clients.length}`);
    const auth = getAuth(app);
    connectAuthEmulator(auth, `http://${authHost}`, { disableWarnings: true });
    const [host, port] = emulatorHost.split(':');
    const db = fsdk.getFirestore(app);
    fsdk.connectFirestoreEmulator(db, host, Number(port));
    const cred = await signInWithEmailAndPassword(auth, EMAIL, PASSWORD);
    assert.equal(cred.user.uid, fixture.uid);
    clients.push({ app });
    return db;
  }

  const TS = fixture.serverTimestampMarker;
  const withTimestamps = (v) =>
    v === TS ? fsdk.serverTimestamp() : Array.isArray(v) ? v.map(withTimestamps) : v && typeof v === 'object' ? Object.fromEntries(Object.entries(v).map(([k, x]) => [k, withTimestamps(x)])) : v;

  /** Applies a fixture update map ("fieldPath:a/b" keys become FieldPaths). */
  function update(db, attemptId, payload) {
    const args = [];
    for (const [k, v] of Object.entries(payload)) {
      args.push(k.startsWith('fieldPath:') ? new fsdk.FieldPath(...k.slice('fieldPath:'.length).split('/')) : k, withTimestamps(v));
    }
    return fsdk.updateDoc(fsdk.doc(db, ops.ATTEMPTS, attemptId), ...args);
  }

  const create = (db, stagePayload, overrides = {}) =>
    fsdk.setDoc(fsdk.doc(db, ops.ATTEMPTS, overrides.attemptId || stagePayload.attemptId), withTimestamps({ ...stagePayload.create, ...overrides.data }));

  const stored = async (id) => (await admin.db.collection(ops.ATTEMPTS).doc(id).get()).data();

  it('runs the whole pretest → posttest flow with the app\'s exact payloads', async () => {
    const pre = fixture.preTest;
    let db = await signedInClient();

    // Own participant record readable; the not-yet-created attempt is readable (resume check).
    await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db, ops.PARTICIPANTS, fixture.uid)));
    assert.equal((await fsdk.getDoc(fsdk.doc(db, ops.ATTEMPTS, pre.attemptId))).exists(), false);

    await rut.assertSucceeds(create(db, pre));
    await rut.assertFails(create(db, pre)); // never overwritten (second tab / retry)

    for (const a of pre.answers.slice(0, 5)) await rut.assertSucceeds(update(db, pre.attemptId, a.update));

    // Interruption: a new app instance signs in again and finds the same order and answers.
    db = await signedInClient();
    const resumed = (await fsdk.getDoc(fsdk.doc(db, ops.ATTEMPTS, pre.attemptId))).data();
    assert.deepEqual(resumed.itemOrder, pre.create.itemOrder);
    assert.deepEqual(resumed.optionOrder, pre.create.optionOrder);
    assert.deepEqual(Object.keys(resumed.responses).sort(), pre.answers.slice(0, 5).map((a) => a.itemId).sort());

    // A saved answer can be neither resent nor changed.
    await rut.assertFails(update(db, pre.attemptId, pre.answers[0].update));
    const changed = JSON.parse(JSON.stringify(pre.answers[0].update));
    const key = Object.keys(changed).find((k) => k.startsWith('fieldPath:'));
    changed[key] = { optionId: 'dont_know', optionText: 'Saya tidak tahu kata ini', displayPosition: 5, answeredAt: TS };
    await rut.assertFails(update(db, pre.attemptId, changed));

    // Completion before all 20 answers is refused.
    await rut.assertFails(update(db, pre.attemptId, pre.complete));
    for (const a of pre.answers.slice(5)) await rut.assertSucceeds(update(db, pre.attemptId, a.update));
    await rut.assertSucceeds(update(db, pre.attemptId, pre.complete));
    await rut.assertFails(update(db, pre.attemptId, pre.answers[19].update)); // frozen
    const done = await stored(pre.attemptId);
    assert.equal(done.status, 'completed');
    assert.equal(Object.keys(done.responses).length, 20);
    assert.ok(!('score' in done) && !('isCorrect' in done));

    // Posttest: refused until the researcher opens it.
    const post = fixture.postTest;
    await rut.assertFails(create(db, post));
    await ops.authorizeStage(admin.db, { uids: [fixture.uid], stage: 'postTest', confirmSession4: true, apply: true });
    await rut.assertSucceeds(create(db, post));
    for (const a of post.answers.slice(0, 3)) await rut.assertSucceeds(update(db, post.attemptId, a.update));

    // Technical interruption: void + retake → attempt 2; attempt 1 frozen.
    await ops.voidAttempt(admin.db, { uid: fixture.uid, stage: 'postTest', reason: 'uji gangguan teknis', apply: true });
    await rut.assertFails(update(db, post.attemptId, post.answers[3].update));
    await ops.authorizeRetake(admin.db, { uid: fixture.uid, stage: 'postTest', reason: 'uji gangguan teknis', apply: true });
    const retakeId = post.attemptId.replace(/_1$/, '_2');
    await rut.assertSucceeds(create(db, post, { attemptId: retakeId, data: { attemptNumber: 2 } }));
    for (const a of post.answers.slice(0, 7)) await rut.assertSucceeds(update(db, retakeId, a.update));

    // Offline export with a synthetic key: the retake is incomplete, so no pair yet.
    const { run } = require('../../bin/export_results');
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vocably-export-'));
    const keyPath = path.join(dir, 'synthetic_key.private.json');
    fs.writeFileSync(keyPath, JSON.stringify(fixtures.syntheticKey()));
    const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'vocably-export-out-'));
    let result = await run(['export', '--emulator', '--key', keyPath, '--out-dir', outDir], { log: () => {} });
    assert.equal(result.pairedRows.length, 0);
    assert.deepEqual(
      result.attemptRows.map((r) => [r.stage, r.attempt_number, r.status, r.included_in_scoring, r.exclusion_reason]),
      [['preTest', 1, 'completed', 'yes', ''], ['postTest', 1, 'voided', 'no', 'voided'], ['postTest', 2, 'in_progress', 'no', 'incomplete']]
    );
    assert.ok(fs.existsSync(path.join(outDir, 'export_manifest.json')));
    await assert.rejects(run(['export', '--emulator', '--key', keyPath, '--out-dir', outDir], { log: () => {} }), /overwrite/);

    // Finish the retake; the pair is now scored.
    for (const a of post.answers.slice(7)) await rut.assertSucceeds(update(db, retakeId, a.update));
    await rut.assertSucceeds(update(db, retakeId, post.complete));
    const outDir2 = fs.mkdtempSync(path.join(os.tmpdir(), 'vocably-export-out-'));
    result = await run(['export', '--emulator', '--key', keyPath, '--out-dir', outDir2], { log: () => {} });
    assert.equal(result.pairedRows.length, 1);
    const row = result.pairedRows[0];
    assert.equal(row.research_id, 'E2E-01');
    assert.equal(row.gain, row.post_score - row.pre_score);
    // The fixture answers position (index mod 5) + 1, so items 4, 9, 14, 19 are "tidak tahu".
    assert.equal(row.pre_dont_know, 4);
    const csv = fs.readFileSync(path.join(outDir2, 'analysis_paired.csv'), 'utf8');
    assert.ok(!csv.includes(fixture.uid), 'no UID in analysis files');
  });
});
