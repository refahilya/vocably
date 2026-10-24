'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { assessPrivateOutputPath, writeNewPrivateFile } = require('../lib/safeOutput');

const REPO_ROOT = path.join(__dirname, '..', '..', '..');
const KEY = '.private.json';

function tempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'vocably-safe-output-'));
}

function assess(target, overrides = {}) {
  return assessPrivateOutputPath(target, { repoRoot: REPO_ROOT, requiredSuffix: KEY, env: {}, ...overrides });
}

test('accepts a new file in an existing folder outside the repository and OneDrive', () => {
  const dir = tempDir();
  const verdict = assess(path.join(dir, 'instrument_v1_key.private.json'));
  assert.deepEqual(verdict.reasons, []);
  assert.equal(verdict.ok, true);
});

test('refuses a missing path', () => {
  assert.deepEqual(assess('').reasons, ['no output path was supplied']);
  assert.equal(assess(undefined).ok, false);
});

test('refuses paths inside the repository (including Flutter assets)', () => {
  const verdict = assess(path.join(REPO_ROOT, 'assets', 'research', 'k.private.json'));
  assert.equal(verdict.ok, false);
  assert.ok(verdict.reasons.includes('it is inside the Vocably repository'));
});

test('refuses paths inside a OneDrive root named by the environment', () => {
  const dir = tempDir();
  const verdict = assess(path.join(dir, 'k.private.json'), { env: { OneDrive: dir } });
  assert.ok(verdict.reasons.includes('it is inside a OneDrive-synchronised folder'));
});

test('refuses paths under a folder named like a OneDrive root', () => {
  const dir = path.join(tempDir(), 'OneDrive - Contoso', 'keys');
  fs.mkdirSync(dir, { recursive: true });
  const verdict = assess(path.join(dir, 'k.private.json'));
  assert.ok(verdict.reasons.includes('it is inside a OneDrive-synchronised folder'));
});

test('refuses paths inside any Git working tree', () => {
  const dir = tempDir();
  fs.mkdirSync(path.join(dir, '.git'));
  fs.mkdirSync(path.join(dir, 'sub'));
  const verdict = assess(path.join(dir, 'sub', 'k.private.json'));
  assert.ok(verdict.reasons.some((r) => r.startsWith('it is inside a Git working tree')));
});

test('refuses a folder that does not exist instead of creating it', () => {
  const missing = path.join(tempDir(), 'not-created');
  const verdict = assess(path.join(missing, 'k.private.json'));
  assert.ok(verdict.reasons.some((r) => r.includes('does not exist')));
  assert.equal(fs.existsSync(missing), false);
});

test('refuses the wrong filename suffix', () => {
  const verdict = assess(path.join(tempDir(), 'key.json'));
  assert.ok(verdict.reasons.includes('the filename must end with ".private.json"'));
});

test('refuses an existing file and never overwrites it', () => {
  const file = path.join(tempDir(), 'k.private.json');
  writeNewPrivateFile(file, 'first');
  assert.ok(assess(file).reasons.includes('the file already exists (refusing to overwrite)'));
  assert.throws(() => writeNewPrivateFile(file, 'second'), { code: 'EEXIST' });
  assert.equal(fs.readFileSync(file, 'utf8'), 'first');
});
