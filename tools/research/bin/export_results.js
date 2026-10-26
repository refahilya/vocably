#!/usr/bin/env node
'use strict';

/**
 * Offline scoring and export of the pretest/posttest (trusted researcher
 * tooling; the app never scores).
 *
 *   node bin/export_results.js validate-key --key <key.private.json>
 *   node bin/export_results.js export --key <key.private.json> --out-dir <folder>
 *        (--emulator | --production --project <id> --confirm-project <id>) [--cohort study|pilot|test]
 *
 * - The key must be the private key built for the committed bank (checked:
 *   instrument, version, bank SHA-256, every item, option IDs and texts).
 *   Its contents are never printed; problems name item IDs only.
 * - The output folder must already exist, outside this repository, any Git
 *   working tree and OneDrive. Files are created new; nothing is ever
 *   overwritten. Nothing is uploaded anywhere.
 * - Reads Firestore only (no writes).
 */

const fs = require('fs');
const path = require('path');
const { resolveTarget, initAdmin, TargetError } = require('../lib/admin/target');
const { parseArgs, readBank, REPO_ROOT } = require('../lib/admin/cli');
const { assessPrivateOutputPath, assessPrivateOutputDir, writeNewPrivateFile } = require('../lib/safeOutput');
const { validateKey, buildExport } = require('../lib/export/scoring');
const { exportFiles, fetchResearchData, COLUMNS } = require('../lib/export/files');

const SPEC = {
  key: 'string',
  outDir: 'string',
  cohort: 'string',
  emulator: 'boolean',
  production: 'boolean',
  project: 'string',
  confirmProject: 'string',
};

function loadKey(keyPath) {
  if (!keyPath) throw new Error('--key <path to the private key> is required');
  const check = assessPrivateOutputPath(keyPath, { repoRoot: REPO_ROOT, requiredSuffix: '.private.json', allowExisting: true });
  if (!check.ok) throw new Error(`Refusing the key location: ${check.reasons.join('; ')}`);
  if (!fs.existsSync(check.resolved)) throw new Error('The key file does not exist.');
  return JSON.parse(fs.readFileSync(check.resolved, 'utf8'));
}

async function run(argv, { log = console.log } = {}) {
  const args = parseArgs(argv, SPEC);
  const [command] = args._;
  const { bank, bankSha256 } = readBank();
  const key = loadKey(args.key);
  const keyProblems = validateKey(key, bank, bankSha256);
  if (keyProblems.length) throw new Error(`The key does not match the bank:\n- ${keyProblems.join('\n- ')}`);

  if (command === 'validate-key') {
    log(`Key OK: ${key.entries.length} entries for ${bank.instrumentId} ${bank.instrumentVersion}, bank SHA-256 matches.`);
    return null;
  }
  if (command !== 'export') throw new Error('Usage: export_results.js validate-key|export [options]');

  const out = assessPrivateOutputDir(args.outDir, { repoRoot: REPO_ROOT });
  if (!out.ok) throw new Error(`Refusing the output folder: ${out.reasons.join('; ')}`);
  const names = [...Object.keys(COLUMNS), 'export_manifest.json'];
  const clashes = names.filter((n) => fs.existsSync(path.join(out.resolved, n)));
  if (clashes.length) throw new Error(`Refusing to overwrite existing files: ${clashes.join(', ')}`);

  const target = resolveTarget(args, { repoRoot: REPO_ROOT });
  const { app, db } = initAdmin(target);
  let result;
  try {
    const data = await fetchResearchData(db);
    result = buildExport({ bank, key, ...data, cohort: args.cohort || null });
  } finally {
    await app.delete();
  }

  const files = exportFiles(result);
  const manifest = {
    generatedAt: new Date().toISOString(),
    source: { mode: target.mode, projectId: target.projectId },
    instrumentId: bank.instrumentId,
    instrumentVersion: bank.instrumentVersion,
    bankSha256,
    keyVerified: true,
    cohortFilter: args.cohort || null,
    scoring: 'B=1; S, T, K=0; score 0-20; gain = post - pre; n_gain = gain / (20 - pre), blank when pre = 20',
    instrumentStatus: bank.status,
    summary: result.summary,
    files: Object.fromEntries(Object.entries(COLUMNS).map(([name, cols]) => [name, cols])),
  };
  for (const [name, text] of Object.entries(files)) writeNewPrivateFile(path.join(out.resolved, name), text);
  writeNewPrivateFile(path.join(out.resolved, 'export_manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);

  log(`Export written to ${out.resolved}`);
  log(`  participants ${result.summary.participants}, paired ${result.summary.pairedIncluded}, excluded from pairs ${result.summary.pairedExcluded}`);
  log(`  N-gain not computed (pre = 20): ${result.summary.nGainNotComputed}; data problems: ${result.summary.dataProblems}`);
  return result;
}

if (require.main === module) {
  run(process.argv.slice(2)).catch((error) => {
    console.error(error instanceof TargetError ? error.message : `Error: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { run };
