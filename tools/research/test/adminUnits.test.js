'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { parseParticipantsCsv } = require('../lib/admin/participantsCsv');
const { resolveTarget, TargetError } = require('../lib/admin/target');
const { parseArgs, openAuditLog } = require('../lib/admin/cli');
const { toCsv } = require('../lib/export/files');
const { assessPrivateOutputDir } = require('../lib/safeOutput');

const REPO_ROOT = path.join(__dirname, '..', '..', '..');
const HEADER = 'uid,researchId,band,cohort';
const tempDir = () => fs.mkdtempSync(path.join(os.tmpdir(), 'vocably-admin-'));

test('participants CSV: accepts a valid file (BOM, CRLF, trailing newline)', () => {
  const { rows, problems } = parseParticipantsCsv(`\uFEFF${HEADER}\r\nabcdef123,R-01,A2,study\r\nghijkl456,R-02,C1,pilot\r\n`);
  assert.deepEqual(problems, []);
  assert.deepEqual(rows.map((r) => [r.line, r.uid, r.researchId, r.band, r.cohort]), [
    [2, 'abcdef123', 'R-01', 'A2', 'study'],
    [3, 'ghijkl456', 'R-02', 'C1', 'pilot'],
  ]);
});

test('participants CSV: rejects headers that are missing, extra or reordered', () => {
  for (const header of ['uid,researchId,band', 'uid,researchId,band,cohort,name', 'researchId,uid,band,cohort', '']) {
    const { rows, problems } = parseParticipantsCsv(`${header}\nabcdef123,R-01,A2,study\n`);
    assert.equal(rows.length, 0);
    assert.ok(problems.length, header);
  }
});

test('participants CSV: rejects bad rows and refuses the whole file', () => {
  const { rows, problems } = parseParticipantsCsv(
    [
      HEADER,
      'abcdef123,R-01,A2,study',
      'abcdef123,R-02,A2,study', // duplicate uid
      'zzzzzz999,R-01,B1,study', // duplicate researchId
      'yyyyyy888,R-03,C2,study', // bad band
      'xxxxxx777,R-04,b1,study', // band is case-sensitive
      'wwwwww666,R-05,A2,class', // bad cohort
      'vvvvvv555,siswa@sekolah,A2,study', // e-mail as research ID
      'short,R-06,A2,study', // uid too short
      'uuuuuu444,R-07,A2', // missing column
      'tttttt333,R-08,A2,study,extra', // extra column
      '"ssssss222",R-09,A2,study', // quotes
      '',
      'rrrrrr111,R-10,A2,study',
      'qqqqqq000,-R11,A2,study', // research ID starting with '-' (spreadsheet formula)
    ].join('\n')
  );
  assert.equal(rows.length, 0, 'nothing is accepted when any row is invalid');
  for (const fragment of ['line 3: duplicate uid', 'line 4: duplicate researchId', 'line 5: band', 'line 6: band', 'line 7: cohort', 'line 8: invalid researchId', 'line 9: invalid uid', 'line 10: expected 4 columns', 'line 11: expected 4 columns', 'line 12: quotes', 'line 13: empty line', 'line 15: invalid researchId']) {
    assert.ok(problems.some((p) => p.startsWith(fragment)), fragment);
  }
  assert.ok(!problems.some((p) => p.includes('siswa@sekolah')), 'field values are never echoed');
  assert.deepEqual(parseParticipantsCsv(`${HEADER}\n`).problems, ['the file has no participant rows']);
});

test('target: refuses no target, both targets, and non-local or non-demo emulators', () => {
  const opts = (env) => ({ env, repoRoot: REPO_ROOT });
  assert.throws(() => resolveTarget({}, opts({})), TargetError);
  assert.throws(() => resolveTarget({ emulator: true, production: true }, opts({})), TargetError);
  assert.throws(() => resolveTarget({ emulator: true }, opts({})), /FIRESTORE_EMULATOR_HOST/);
  assert.throws(() => resolveTarget({ emulator: true }, opts({ FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443' })), /local emulator/);
  assert.throws(() => resolveTarget({ emulator: true, project: 'vocably-idn-en' }, opts({ FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' })), /demo-/);
  assert.deepEqual(resolveTarget({ emulator: true }, opts({ FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' })), {
    mode: 'emulator', projectId: 'demo-vocably-test', firestoreHost: '127.0.0.1:8080', authHost: null,
  });
});

test('target: production needs a confirmed real project, outside credentials and no emulator variables', () => {
  const dir = tempDir();
  const creds = path.join(dir, 'service-account.json');
  fs.writeFileSync(creds, '{}');
  const base = { production: true, project: 'vocably-idn-en', confirmProject: 'vocably-idn-en' };
  const env = { GOOGLE_APPLICATION_CREDENTIALS: creds };
  const opts = (e) => ({ env: e, repoRoot: REPO_ROOT });
  assert.deepEqual(resolveTarget(base, opts(env)), { mode: 'production', projectId: 'vocably-idn-en' });
  assert.throws(() => resolveTarget({ ...base, confirmProject: undefined }, opts(env)), /confirm-project/);
  assert.throws(() => resolveTarget({ ...base, confirmProject: 'other' }, opts(env)), /confirm-project/);
  assert.throws(() => resolveTarget({ ...base, project: 'demo-x', confirmProject: 'demo-x' }, opts(env)), /non-demo/);
  assert.throws(() => resolveTarget(base, opts({})), /GOOGLE_APPLICATION_CREDENTIALS/);
  assert.throws(() => resolveTarget(base, opts({ ...env, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' })), /FIRESTORE_EMULATOR_HOST/);
  const inRepo = path.join(REPO_ROOT, 'tools', 'research', 'package.json');
  assert.throws(() => resolveTarget(base, opts({ GOOGLE_APPLICATION_CREDENTIALS: inRepo })), /inside the Vocably repository/);
});

test('cli: parses flags, values and repeatable options; refuses unknown options', () => {
  const spec = { apply: 'boolean', stage: 'string', uid: 'list' };
  assert.deepEqual(parseArgs(['authorize', '--stage', 'preTest', '--uid', 'a', '--uid', 'b', '--apply'], spec), {
    _: ['authorize'], uid: ['a', 'b'], stage: 'preTest', apply: true,
  });
  assert.throws(() => parseArgs(['--force'], spec), /Unknown option/);
  assert.throws(() => parseArgs(['--stage'], spec), /needs a value/);
});

test('audit log: refuses a log inside the repository, appends JSON lines outside it', () => {
  assert.throws(() => openAuditLog(path.join(REPO_ROOT, 'audit.private.jsonl')), /inside the Vocably repository/);
  assert.throws(() => openAuditLog(path.join(tempDir(), 'audit.log')), /\.private\.jsonl/);
  const logPath = path.join(tempDir(), 'audit.private.jsonl');
  const audit = openAuditLog(logPath, { env: {} });
  audit({ command: 'status', outcome: 'ok' });
  audit({ command: 'void', outcome: 'refused' });
  const lines = fs.readFileSync(logPath, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
  assert.deepEqual(lines.map((l) => l.command), ['status', 'void']);
  assert.ok(lines.every((l) => typeof l.at === 'string'));
});

test('export folder: must exist and be outside the repository', () => {
  assert.equal(assessPrivateOutputDir(tempDir(), { repoRoot: REPO_ROOT, env: {} }).ok, true);
  assert.match(assessPrivateOutputDir(path.join(tempDir(), 'missing'), { repoRoot: REPO_ROOT, env: {} }).reasons[0], /does not exist/);
  assert.ok(assessPrivateOutputDir(REPO_ROOT, { repoRoot: REPO_ROOT, env: {} }).reasons.includes('it is inside the Vocably repository'));
  assert.equal(assessPrivateOutputDir('', { repoRoot: REPO_ROOT }).ok, false);
});

test('csv: quotes commas, quotes and newlines; empty for null', () => {
  assert.equal(toCsv(['a', 'b', 'c'], [{ a: 'x,y', b: 'say "hi"', c: null }, { a: 'line\nbreak', b: -1, c: 0 }]), 'a,b,c\r\n"x,y","say ""hi""",\r\n"line\nbreak",-1,0\r\n');
});
