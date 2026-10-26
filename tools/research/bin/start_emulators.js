#!/usr/bin/env node
'use strict';

/**
 * Starts local Firestore (127.0.0.1:8080) and Auth (127.0.0.1:9099)
 * emulators for manual testing of the app, under the demo project
 * `demo-vocably-test`, with the repository's real `firestore.rules`.
 * Data lives in memory only: stopping the emulators (Ctrl+C) is the
 * teardown, and the next start is empty again.
 *
 * Then, in a second terminal: `npm run seed:emulator -- --password <dummy>`
 * and run the app with `--dart-define=USE_FIREBASE_EMULATORS=true`
 * (see tools/research/README.md, "Running the app against the emulators").
 *
 * Usage (from tools/research): npm run emulators
 */

const path = require('path');
const { PROJECT_ID, REPO_ROOT, EMULATORS, emulatorChildEnv, runFirebase } = require('../lib/emulatorEnv');

const { env, java } = emulatorChildEnv();
console.log(`Java ${java.major} from ${java.home}`);
process.exit(
  runFirebase(['emulators:start', '--only', EMULATORS, '--project', PROJECT_ID, '--config', path.join(REPO_ROOT, 'firebase.json')], env)
);
