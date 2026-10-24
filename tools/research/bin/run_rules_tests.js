#!/usr/bin/env node
'use strict';

/**
 * Runs the Firestore security-rules tests (`test/rules/`) against a LOCAL
 * Firestore Emulator started just for this run, then shuts it down.
 *
 * Safety:
 * - The emulator runs under the demo project `demo-vocably-test`. Firebase
 *   treats `demo-*` projects as offline-only: no production resource can
 *   be reached and no login or credentials are used. The real project
 *   (`vocably-idn-en`) is never passed to any command here.
 * - Only `firebase emulators:exec --only firestore` is run — never deploy.
 * - Java 21+ (required by firebase-tools' emulators) is taken from
 *   `VOCABLY_JAVA_HOME`, then `JAVA_HOME`, then a portable JDK under
 *   `%USERPROFILE%\.vocably-dev\jdk-21*`, and is put on PATH for the child
 *   processes only. Nothing system-wide is changed.
 *
 * Usage (from tools/research): npm run test:rules
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'demo-vocably-test';
const REPO_ROOT = path.join(__dirname, '..', '..', '..');
const TOOL_ROOT = path.join(__dirname, '..');
const MIN_JAVA = 21;

if (!PROJECT_ID.startsWith('demo-')) throw new Error('Refusing: emulator project must be a demo- project');

function javaMajor(javaHome) {
  const exe = path.join(javaHome, 'bin', process.platform === 'win32' ? 'java.exe' : 'java');
  if (!fs.existsSync(exe)) return null;
  const out = spawnSync(exe, ['-version'], { encoding: 'utf8' });
  const match = /version "(\d+)(?:\.(\d+))?/.exec(`${out.stderr}${out.stdout}`);
  if (!match) return null;
  const major = Number(match[1]);
  return major === 1 ? Number(match[2]) : major;
}

function findJavaHome() {
  const candidates = [process.env.VOCABLY_JAVA_HOME, process.env.JAVA_HOME].filter(Boolean);
  const portableRoot = path.join(os.homedir(), '.vocably-dev');
  if (fs.existsSync(portableRoot)) {
    for (const name of fs.readdirSync(portableRoot).sort().reverse()) {
      if (/^jdk-2\d/.test(name)) candidates.push(path.join(portableRoot, name));
    }
  }
  for (const home of candidates) {
    const major = javaMajor(home);
    if (major !== null && major >= MIN_JAVA) return { home, major };
  }
  return null;
}

const java = findJavaHome();
if (!java) {
  console.error(
    `No Java ${MIN_JAVA}+ found (checked VOCABLY_JAVA_HOME, JAVA_HOME and ${path.join(os.homedir(), '.vocably-dev')}).\n` +
      'firebase-tools requires Java 21+ for the emulators. See tools/research/README.md ("Security-rules tests").'
  );
  process.exit(2);
}

const env = {
  ...process.env,
  JAVA_HOME: java.home,
  PATH: `${path.join(java.home, 'bin')}${path.delimiter}${process.env.PATH}`,
};
// Never let an inherited production credential reach the emulator run.
delete env.GOOGLE_APPLICATION_CREDENTIALS;

const firebase = process.env.FIREBASE_CLI || 'firebase';
const args = [
  'emulators:exec',
  '--only', 'firestore',
  '--project', PROJECT_ID,
  '--config', path.join(REPO_ROOT, 'firebase.json'),
  'node --test test/rules/*.test.js',
];

console.log(`Java ${java.major} from ${java.home}`);
console.log(`Running: ${firebase} ${args.map((a) => (a.includes(' ') ? `"${a}"` : a)).join(' ')}`);

const quoted = args.map((a) => (/[\s"]/.test(a) ? `"${a.replace(/"/g, '\\"')}"` : a)).join(' ');
const result = spawnSync(`${firebase} ${quoted}`, {
  cwd: TOOL_ROOT,
  env,
  stdio: 'inherit',
  shell: true,
});
process.exit(result.status === null ? 1 : result.status);
