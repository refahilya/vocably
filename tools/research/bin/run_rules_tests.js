#!/usr/bin/env node
'use strict';

/**
 * Runs the emulator test suites (`test/rules/`: security rules, researcher
 * admin tooling, the replay of the app's payloads, the end-to-end flow and
 * the export) against LOCAL Firestore + Auth emulators started just for
 * this run, then shuts them down. Emulator data is in memory only, so every
 * run starts empty.
 *
 * Safety: demo project only, `emulators:exec` only (never deploy), Java
 * from the portable JDK for the child process only — see
 * lib/emulatorEnv.js. Test files run one at a time because they share the
 * emulator.
 *
 * Usage (from tools/research): npm run test:rules
 */

const path = require('path');
const { PROJECT_ID, REPO_ROOT, EMULATORS, emulatorChildEnv, runFirebase } = require('../lib/emulatorEnv');

const { env, java } = emulatorChildEnv();
console.log(`Java ${java.major} from ${java.home}`);

process.exit(
  runFirebase(
    [
      'emulators:exec',
      '--only', EMULATORS,
      '--project', PROJECT_ID,
      '--config', path.join(REPO_ROOT, 'firebase.json'),
      'node --test --test-concurrency=1 test/rules/*.test.js',
    ],
    env
  )
);
