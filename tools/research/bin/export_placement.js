#!/usr/bin/env node
'use strict';

/**
 * Offline Placement Test export (trusted researcher tooling; read-only).
 *
 *   node bin/export_placement.js --key <placement_key.private.json> --out-dir <folder>
 *        (--emulator | --production --project <id> --confirm-project <id>) [--cohort study|pilot|test]
 *
 * - The key must be the private key built for the committed PT-V1.1 bank
 *   (version, bank SHA-256, every item). Its contents are never printed.
 * - The output folder must already exist, outside this repository, any Git
 *   working tree and OneDrive. Files are created new; never overwritten.
 * - Research attempts only; band scores and quality flags are derived here
 *   from the frozen answers and are never written back to Firestore.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { resolveTarget, initAdmin, TargetError } = require('../lib/admin/target');
const { parseArgs, REPO_ROOT } = require('../lib/admin/cli');
const { assessPrivateOutputPath, assessPrivateOutputDir, writeNewPrivateFile } = require('../lib/safeOutput');
const { validatePlacementKey } = require('../lib/placement/build');
const { PLACEMENT_BANK_ASSET_RELATIVE_PATH } = require('../lib/placement/constants');
const { buildPlacementExport, PLACEMENT_COLUMNS } = require('../lib/export/placement');
const { toCsv, plain } = require('../lib/export/files');

const SPEC = { key: 'string', outDir: 'string', cohort: 'string', emulator: 'boolean', production: 'boolean', project: 'string', confirmProject: 'string' };

async function run(argv, { log = console.log } = {}) {
  const args = parseArgs(argv, SPEC);
  const raw = fs.readFileSync(path.join(REPO_ROOT, ...PLACEMENT_BANK_ASSET_RELATIVE_PATH.split('/')), 'utf8').replace(/\r\n/g, '\n');
  const bank = JSON.parse(raw);
  const bankSha256 = crypto.createHash('sha256').update(raw).digest('hex');
  if (!args.key) throw new Error('--key <path to the private placement key> is required');
  const keyCheck = assessPrivateOutputPath(args.key, { repoRoot: REPO_ROOT, requiredSuffix: '.private.json', allowExisting: true });
  if (!keyCheck.ok) throw new Error(`Refusing the key location: ${keyCheck.reasons.join('; ')}`);
  const keyFile = JSON.parse(fs.readFileSync(keyCheck.resolved, 'utf8'));
  const keyProblems = validatePlacementKey(keyFile, bank, bankSha256);
  if (keyProblems.length) throw new Error(`The key does not match the bank:\n- ${keyProblems.join('\n- ')}`);

  const out = assessPrivateOutputDir(args.outDir, { repoRoot: REPO_ROOT });
  if (!out.ok) throw new Error(`Refusing the output folder: ${out.reasons.join('; ')}`);
  const names = [...Object.keys(PLACEMENT_COLUMNS), 'placement_manifest.json'];
  const clashes = names.filter((n) => fs.existsSync(path.join(out.resolved, n)));
  if (clashes.length) throw new Error(`Refusing to overwrite existing files: ${clashes.join(', ')}`);

  const target = resolveTarget(args, { repoRoot: REPO_ROOT });
  const { app, db } = initAdmin(target);
  let result;
  try {
    const [participants, attempts] = await Promise.all([db.collection('researchParticipants').get(), db.collection('placementAttempts').get()]);
    result = buildPlacementExport({
      bank,
      keyFile,
      participants: participants.docs.map((d) => ({ uid: d.id, data: plain(d.data()) })),
      attempts: attempts.docs.map((d) => ({ id: d.id, data: plain(d.data()) })),
      cohort: args.cohort || null,
    });
  } finally {
    await app.delete();
  }
  const rowsFor = {
    'placement_attempts.csv': result.attemptRows,
    'placement_items.csv': result.itemRows,
    'placement_operational_problems.csv': result.problems,
  };
  for (const [name, cols] of Object.entries(PLACEMENT_COLUMNS)) writeNewPrivateFile(path.join(out.resolved, name), toCsv(cols, rowsFor[name]));
  writeNewPrivateFile(
    path.join(out.resolved, 'placement_manifest.json'),
    `${JSON.stringify({
      generatedAt: new Date().toISOString(),
      source: { mode: target.mode, projectId: target.projectId },
      instrumentVersion: bank.instrumentVersion,
      bankSha256,
      scoringPolicy: 'K2 (researcher-selected; not expert-validated)',
      cohortFilter: args.cohort || null,
      counts: { attempts: result.attemptRows.length, items: result.itemRows.length, problems: result.problems.length },
    }, null, 2)}\n`
  );
  log(`Placement export written to ${out.resolved}: ${result.attemptRows.length} research attempt(s), ${result.problems.length} problem(s).`);
  return result;
}

if (require.main === module) {
  run(process.argv.slice(2)).catch((error) => {
    console.error(error instanceof TargetError ? error.message : `Error: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { run };
