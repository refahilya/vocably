#!/usr/bin/env node
'use strict';

/**
 * Seeds dummy accounts and research data into the RUNNING local emulators
 * (start them first with `npm run emulators`). Emulator-only: it refuses
 * unless FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST point at
 * localhost and the project is `demo-*`. Safe to run more than once.
 *
 * Usage (from tools/research):
 *   npm run seed:emulator -- --password <dummy password>
 * The password is used for every dummy account and is never printed.
 */

const { resolveTarget, initAdmin } = require('../lib/admin/target');
const { parseArgs, readBank, REPO_ROOT } = require('../lib/admin/cli');
const { seedEmulator } = require('../lib/admin/emulatorSeed');

async function main() {
  const args = parseArgs(process.argv.slice(2), { password: 'string' });
  const env = {
    FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
    FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
    GCLOUD_PROJECT: 'demo-vocably-test',
    ...process.env,
  };
  Object.assign(process.env, {
    FIRESTORE_EMULATOR_HOST: env.FIRESTORE_EMULATOR_HOST,
    FIREBASE_AUTH_EMULATOR_HOST: env.FIREBASE_AUTH_EMULATOR_HOST,
  });
  delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const target = resolveTarget({ emulator: true, project: env.GCLOUD_PROJECT }, { env, repoRoot: REPO_ROOT });
  const { app, db, auth } = initAdmin(target);
  try {
    const { bank, bankJson } = readBank();
    const result = await seedEmulator({ target, db, auth, bank, bankJson, password: args.password });
    console.log(`Seeded ${target.projectId} (emulator). Dummy accounts (password as given):`);
    for (const a of result.accounts) {
      console.log(`  ${a.email}\t${a.participant ? `participant ${a.participant.researchId}, band ${a.participant.band}, pretest authorized` : 'not a participant'}`);
    }
  } finally {
    await app.delete();
  }
}

main().catch((error) => {
  console.error(`Error: ${error.message}`);
  process.exit(1);
});
