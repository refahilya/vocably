'use strict';

/**
 * Dummy accounts and research setup for the LOCAL emulators only — used by
 * `bin/seed_emulator.js` (manual app testing) and the end-to-end emulator
 * test. Never run against production: callers must have resolved an
 * emulator target first.
 *
 * Creates, in the demo project:
 * - one enrolled student per band (`siswa.a2@example.test` …), pretest
 *   authorized, researchId `EMU-A2` …;
 * - one student who is not a participant (`siswa.umum@example.test`);
 * - one participant enrolled WITHOUT a band, awaiting the Placement Test
 *   (`siswa.placement@example.test`, researchId `EMU-PT`);
 * - an active study with the placement, pretest and posttest windows open,
 *   the Placement Test bank with a SYNTHETIC key (letter by item number —
 *   never the real key) and learning placement open;
 * - their `users/{uid}` profiles (role `siswa`, placement already prompted
 *   so the app goes straight to the dashboard);
 * - the `researchInstrument` documents.
 * The dummy password is supplied by the caller and never printed.
 */

const { BANDS } = require('../constants');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const ops = require('./operations');
const pops = require('./placementOperations');
const { PLACEMENT_BANK_ASSET_RELATIVE_PATH } = require('../placement/constants');

const DOMAIN = 'example.test';

function dummyAccounts() {
  return [
    ...BANDS.map((band) => ({
      uid: `emuStudent${band}`,
      email: `siswa.${band.toLowerCase()}@${DOMAIN}`,
      name: `Siswa Uji ${band}`,
      participant: { researchId: `EMU-${band}`, band, cohort: 'test' },
    })),
    { uid: 'emuStudentUmum', email: `siswa.umum@${DOMAIN}`, name: 'Siswa Uji Umum', participant: null },
    { uid: 'emuStudentPlacement', email: `siswa.placement@${DOMAIN}`, name: 'Siswa Uji Placement', participant: null, pendingPlacement: 'EMU-PT' },
  ];
}

async function seedEmulator({ target, db, auth, bank, bankJson, password, accounts = dummyAccounts() }) {
  if (target.mode !== 'emulator' || !target.projectId.startsWith('demo-')) {
    throw new Error('seedEmulator runs only against a demo-* emulator target');
  }
  if (!target.authHost) throw new Error('FIREBASE_AUTH_EMULATOR_HOST must be set (start the emulators with npm run emulators)');
  if (!password || String(password).length < 6) throw new Error('a dummy password of at least 6 characters is required');
  const { FieldValue } = require('firebase-admin/firestore');

  for (const account of accounts) {
    try {
      await auth.getUser(account.uid);
    } catch {
      await auth.createUser({ uid: account.uid, email: account.email, password, displayName: account.name });
    }
    const userRef = db.collection('users').doc(account.uid);
    if (!(await userRef.get()).exists) {
      await userRef.set({
        uid: account.uid,
        email: account.email,
        name: account.name,
        role: 'siswa',
        createdAt: FieldValue.serverTimestamp(),
        cefrLevel: null,
        placementTestCompleted: false,
        placementTestPrompted: true,
      });
    }
  }

  const seeded = await ops.seedInstrument(db, { bank, bankJson, apply: true });

  // Study lifecycle + Placement Test (synthetic key; emulator only).
  const study = await db.collection(pops.STUDY).doc('current').get();
  if (!study.exists) {
    await pops.setStudyStatus(db, { status: 'active', apply: true });
    for (const stage of ['placement', 'preTest', 'postTest']) await pops.setStageWindow(db, { stage, open: true, apply: true });
  }
  const bankPath = path.join(__dirname, '..', '..', '..', '..', ...PLACEMENT_BANK_ASSET_RELATIVE_PATH.split('/'));
  const raw = fs.readFileSync(bankPath, 'utf8').replace(/\r\n/g, '\n');
  const placementBank = JSON.parse(raw);
  const bankSha256 = crypto.createHash('sha256').update(raw).digest('hex');
  const letters = ['A', 'B', 'C', 'D'];
  await pops.seedPlacement(db, {
    bank: placementBank,
    bankSha256,
    keyFile: {
      instrumentVersion: placementBank.instrumentVersion,
      bankSha256,
      key: Object.fromEntries(placementBank.items.map((i) => [i.id, letters[i.number % 4]])),
    },
    apply: true,
  });
  await pops.setLearningPlacement(db, { open: true, apply: true });
  for (const a of accounts.filter((x) => x.pendingPlacement)) {
    const ref = db.collection(ops.PARTICIPANTS).doc(a.uid);
    if (!(await ref.get()).exists) {
      await ref.create({
        researchId: a.pendingPlacement, band: null, bandSource: null, status: 'awaiting_placement', exclusionReason: null,
        placementAttemptId: null, reviewStatus: null, instrumentVersion: bank.instrumentVersion,
        authorizedAttempts: { placement: 1, preTest: 0, postTest: 0 }, cohort: 'test',
        createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }
  const enrolled = accounts.filter((a) => a.participant);
  const fresh = [];
  for (const a of enrolled) {
    if (!(await db.collection(ops.PARTICIPANTS).doc(a.uid).get()).exists) fresh.push(a);
  }
  if (fresh.length) {
    await ops.enrolParticipants(db, {
      rows: fresh.map((a, i) => ({ line: i + 2, uid: a.uid, ...a.participant })),
      apply: true,
    });
    await ops.authorizeStage(db, { uids: fresh.map((a) => a.uid), stage: 'preTest', apply: true });
  }
  return { accounts: accounts.map(({ uid, email, participant, pendingPlacement }) => ({ uid, email, participant, pendingPlacement })), seeded, newlyEnrolled: fresh.length };
}

module.exports = { seedEmulator, dummyAccounts, DOMAIN };
