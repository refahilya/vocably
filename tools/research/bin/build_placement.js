#!/usr/bin/env node
'use strict';

/**
 * Builds the Placement Test bank (PT-V1.1) from the researcher's item file
 * `placement_items_v1.0.json` (PT-V1.0, which contains the answer key):
 *
 * 1. validates the 50 items and 12 reserves (ids, options, markup, unique
 *    words), the pool separation from the pretest/posttest bank (spec K4,
 *    §10) and the source test vectors (PT-V1.0 rule; K2 may change only the
 *    documented vector);
 * 2. writes the app-safe bank to `assets/placement/placement_bank_pt_v1_1.json`
 *    (no key) — or, with `--check`, only compares against it;
 * 3. writes the private key ONLY with `--key-out <file.private.json>`
 *    (outside this repository, any Git working tree and OneDrive; never
 *    overwritten).
 *
 * Nothing from the key is ever printed.
 *
 * Usage:
 *   node bin/build_placement.js --source <placement_items_v1.0.json> [--check] [--key-out <file.private.json>]
 */

const fs = require('fs');
const path = require('path');
const { buildPlacement, privateKeyFile, PlacementValidationError } = require('../lib/placement/build');
const { assessPrivateOutputPath, writeNewPrivateFile } = require('../lib/safeOutput');
const { PLACEMENT_BANK_ASSET_RELATIVE_PATH } = require('../lib/placement/constants');
const { BANK_ASSET_RELATIVE_PATH, PRIVATE_KEY_SUFFIX } = require('../lib/constants');
const { parseArgs } = require('../lib/admin/cli');

const REPO_ROOT = path.join(__dirname, '..', '..', '..');
const BANK_PATH = path.join(REPO_ROOT, ...PLACEMENT_BANK_ASSET_RELATIVE_PATH.split('/'));
const PRETEST_BANK_PATH = path.join(REPO_ROOT, ...BANK_ASSET_RELATIVE_PATH.split('/'));

function main(argv) {
  const args = parseArgs(argv, { source: 'string', check: 'boolean', keyOut: 'string' });
  if (!args.source || args._.length) throw new Error('Usage: build_placement.js --source <placement_items_v1.0.json> [--check] [--key-out <file.private.json>]');

  let keyTarget = null;
  if (args.keyOut) {
    const check = assessPrivateOutputPath(args.keyOut, { repoRoot: REPO_ROOT, requiredSuffix: PRIVATE_KEY_SUFFIX });
    if (!check.ok) throw new Error(`Refusing --key-out: ${check.reasons.join('; ')}`);
    keyTarget = check.resolved;
  }

  const sourceJson = fs.readFileSync(args.source, 'utf8');
  const pretestBank = JSON.parse(fs.readFileSync(PRETEST_BANK_PATH, 'utf8'));
  const built = buildPlacement({ source: JSON.parse(sourceJson), sourceJson, pretestBank });

  const s = built.summary;
  console.log(`Validated ${s.items} items + ${s.reservesChecked} reserves (${s.placementWordsChecked} words); overlap with ${s.pretestWordsCompared} pretest/posttest words: ${s.overlap}.`);
  console.log(`Source test vectors: ${s.testVectors} match PT-V1.0; K2 changes only [${s.k2ChangedVectors.join('] [')}].`);

  if (args.check) {
    const current = fs.existsSync(BANK_PATH) ? fs.readFileSync(BANK_PATH, 'utf8').replace(/\r\n/g, '\n') : null;
    if (current !== built.bankJson) {
      console.error(`${PLACEMENT_BANK_ASSET_RELATIVE_PATH} is missing or differs from a fresh build.`);
      return 1;
    }
    console.log(`${PLACEMENT_BANK_ASSET_RELATIVE_PATH} is up to date (sha256 ${built.bankSha256}).`);
  } else {
    fs.mkdirSync(path.dirname(BANK_PATH), { recursive: true });
    fs.writeFileSync(BANK_PATH, built.bankJson);
    console.log(`Wrote ${PLACEMENT_BANK_ASSET_RELATIVE_PATH} (sha256 ${built.bankSha256}).`);
  }
  if (keyTarget) {
    writeNewPrivateFile(keyTarget, privateKeyFile(built));
    console.log('Wrote the private key (contents not printed).');
  }
  return 0;
}

if (require.main === module) {
  try {
    process.exit(main(process.argv.slice(2)));
  } catch (error) {
    console.error(error instanceof PlacementValidationError ? error.message : `Error: ${error.message}`);
    process.exit(1);
  }
}

module.exports = { main };
