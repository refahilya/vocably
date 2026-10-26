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
 * - their `users/{uid}` profiles (role `siswa`, placement already prompted
 *   so the app goes straight to the dashboard);
 * - the `researchInstrument` documents.
 * The dummy password is supplied by the caller and never printed.
 */

const { BANDS } = require('../constants');
const ops = require('./operations');

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
  return { accounts: accounts.map(({ uid, email, participant }) => ({ uid, email, participant })), seeded, newlyEnrolled: fresh.length };
}

module.exports = { seedEmulator, dummyAccounts, DOMAIN };
