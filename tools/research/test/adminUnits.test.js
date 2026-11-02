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
const { formatPlacementStatus } = require('../lib/admin/operations');

const REPO_ROOT = path.join(__dirname, '..', '..', '..');
const HEADER = 'uid,researchId,cohort';
const EMAIL_HEADER = 'email,researchId,cohort';
const tempDir = () => fs.mkdtempSync(path.join(os.tmpdir(), 'vocably-admin-'));

test('placement status: separates attempt status, answered count, stored level and target band', () => {
  const base = { n: 1, status: 'scored', answered: 50 };
  const line = (extra) => formatPlacementStatus({ ...base, ...extra });
  assert.equal(line({ resultLevel: 'A1', belowA1Threshold: true, targetBand: 'A2' }), 'placement=#1 scored answered=50/50 level=A1* targetBand=A2');
  assert.equal(line({ resultLevel: 'A1', belowA1Threshold: false, targetBand: 'A2' }), 'placement=#1 scored answered=50/50 level=A1 targetBand=A2');
  assert.equal(line({ resultLevel: 'B2', belowA1Threshold: false, targetBand: 'C1' }), 'placement=#1 scored answered=50/50 level=B2 targetBand=C1');
  assert.equal(line({ resultLevel: 'C1', belowA1Threshold: false, targetBand: null }), 'placement=#1 scored answered=50/50 level=C1 targetBand=none');
});

test('placement status: never infers a value that is not stored', () => {
  assert.equal(formatPlacementStatus({ n: 2, status: 'not_started', answered: 0 }), 'placement=#2 not_started answered=0/50 level=- targetBand=-');
  assert.equal(formatPlacementStatus({ n: 1, status: 'in_progress', answered: 12 }), 'placement=#1 in_progress answered=12/50 level=- targetBand=-');
  assert.equal(formatPlacementStatus({ n: 1, status: 'scored', answered: 50, targetBand: 'B1' }), 'placement=#1 scored answered=50/50 level=- targetBand=B1');
});

test('participants CSV: accepts a valid uid file (BOM, CRLF, trailing newline)', () => {
  const { rows, problems } = parseParticipantsCsv(`\uFEFF${HEADER}\r\nabcdef123,R-01,study\r\nghijkl456,R-02,pilot\r\n`);
  assert.deepEqual(problems, []);
  assert.deepEqual(rows.map((r) => [r.line, r.uid, r.researchId, r.cohort]), [
    [2, 'abcdef123', 'R-01', 'study'],
    [3, 'ghijkl456', 'R-02', 'pilot'],
  ]);
});

test('participants CSV: accepts sign-in e-mails (lower-cased) instead of UIDs', () => {
  const { rows, problems } = parseParticipantsCsv(`${EMAIL_HEADER}\nSiswa.Satu@Sekolah.sch.id,R-01,study\nsiswa2@example.test,R-02,study\n`);
  assert.deepEqual(problems, []);
  assert.deepEqual(rows.map((r) => [r.email, r.uid, r.researchId]), [
    ['siswa.satu@sekolah.sch.id', undefined, 'R-01'],
    ['siswa2@example.test', undefined, 'R-02'],
  ]);
});

test('participants CSV: there is no band column (bands come from the research Placement Test)', () => {
  for (const header of ['uid,researchId,band,cohort', 'email,researchId,band,cohort', 'uid,researchId', 'uid,researchId,cohort,name', 'researchId,uid,cohort', 'uid,email,researchId,cohort', '']) {
    const { rows, problems } = parseParticipantsCsv(`${header}\nabcdef123,R-01,A2,study\n`);
    assert.equal(rows.length, 0);
    assert.ok(problems.length, header);
  }
  assert.match(parseParticipantsCsv('uid,researchId,band,cohort\nabcdef123,R-01,A2,study\n').problems[0], /no band column/);
});

test('participants CSV: rejects bad rows and refuses the whole file', () => {
  const { rows, problems } = parseParticipantsCsv(
    [
      HEADER,
      'abcdef123,R-01,study',
      'abcdef123,R-02,study', // duplicate uid
      'zzzzzz999,R-01,study', // duplicate researchId
      'wwwwww666,R-05,class', // bad cohort
      'vvvvvv555,siswa@sekolah,study', // e-mail as research ID
      'short,R-06,study', // uid too short
      'uuuuuu444,R-07', // missing column
      'tttttt333,R-08,study,extra', // extra column
      '"ssssss222",R-09,study', // quotes
      '',
      'rrrrrr111,R-10,study',
      'qqqqqq000,-R11,study', // research ID starting with '-' (spreadsheet formula)
    ].join('\n')
  );
  assert.equal(rows.length, 0, 'nothing is accepted when any row is invalid');
  for (const fragment of ['line 3: duplicate uid', 'line 4: duplicate researchId', 'line 5: cohort', 'line 6: invalid researchId', 'line 7: invalid uid', 'line 8: expected 3 columns', 'line 9: expected 3 columns', 'line 10: quotes', 'line 11: empty line', 'line 13: invalid researchId']) {
    assert.ok(problems.some((p) => p.startsWith(fragment)), fragment);
  }
  assert.ok(!problems.some((p) => p.includes('siswa@sekolah')), 'field values are never echoed');
  assert.deepEqual(parseParticipantsCsv(`${HEADER}\n`).problems, ['the file has no participant rows']);
  const emails = parseParticipantsCsv(`${EMAIL_HEADER}\nnot-an-email,R-01,study\na@b.co,R-02,study\nA@B.co,R-03,study\n`);
  assert.ok(emails.problems.includes('line 2: invalid email'));
  assert.ok(emails.problems.includes('line 4: duplicate email'));
  assert.ok(!emails.problems.some((p) => p.includes('not-an-email')), 'e-mails are never echoed');
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
