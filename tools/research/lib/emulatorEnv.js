'use strict';

/**
 * Shared setup for running the Firebase Emulators locally (rules tests,
 * admin-tooling tests, manual app testing).
 *
 * - Always the demo project `demo-vocably-test`: Firebase treats `demo-*`
 *   projects as offline-only, so nothing can reach production and no login
 *   or credentials are used. The real project is never passed.
 * - Java 21+ (required by the Firestore emulator) is taken from
 *   `VOCABLY_JAVA_HOME`, then `JAVA_HOME`, then a portable JDK under
 *   `%USERPROFILE%\.vocably-dev\jdk-21*`, and put on PATH for the child
 *   process only. Nothing system-wide changes.
 * - GOOGLE_APPLICATION_CREDENTIALS is removed from the child environment.
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'demo-vocably-test';
const REPO_ROOT = path.join(__dirname, '..', '..', '..');
const TOOL_ROOT = path.join(__dirname, '..');
const MIN_JAVA = 21;
const EMULATORS = 'firestore,auth';

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

/** Child environment with Java on PATH and no production credentials; exits if Java is missing. */
function emulatorChildEnv() {
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
  delete env.GOOGLE_APPLICATION_CREDENTIALS;
  return { env, java };
}

/** Runs `firebase <args>` (shell, stdio inherited) and returns the exit code. */
function runFirebase(args, env) {
  const firebase = process.env.FIREBASE_CLI || 'firebase';
  console.log(`Running: ${firebase} ${args.map((a) => (a.includes(' ') ? `"${a}"` : a)).join(' ')}`);
  const quoted = args.map((a) => (/[\s"]/.test(a) ? `"${a.replace(/"/g, '\\"')}"` : a)).join(' ');
  const result = spawnSync(`${firebase} ${quoted}`, { cwd: TOOL_ROOT, env, stdio: 'inherit', shell: true });
  return result.status === null ? 1 : result.status;
}

module.exports = { PROJECT_ID, REPO_ROOT, TOOL_ROOT, EMULATORS, emulatorChildEnv, runFirebase, findJavaHome };
