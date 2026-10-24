#!/usr/bin/env node
'use strict';

/**
 * Builds the research instrument from the authoritative PDF
 * (`Rancangan_Instrumen_Pretest_Vocably.pdf`):
 *
 * 1. extracts the 80 items, the §3.4 part-of-speech table and the §7 key
 *    with `pdftotext`, and validates them (counts, options, duplicates,
 *    distributions, key consistency);
 * 2. writes the app-safe bank to `assets/research/instrument_v1.json`
 *    (no answer key) — or, with `--check`, only compares against it;
 * 3. writes the private answer key ONLY when `--key-out` is given, and
 *    the human-readable comparison report ONLY when `--report-out` is
 *    given. Both contain correct answers, so both paths must be outside
 *    this repository, outside any Git working tree and outside OneDrive,
 *    must end in `.private.json` / `.private.md`, and must not exist yet.
 *
 * Nothing from the answer key is ever printed.
 *
 * Usage:
 *   node bin/build_instrument.js --pdf <source.pdf>
 *        [--check] [--key-out <file.private.json>] [--report-out <file.private.md>]
 *        [--pdftotext <path-to-pdftotext>]
 */

const fs = require('fs');
const path = require('path');

const { buildFromPdf } = require('../lib/pipeline');
const { validateKeyAgainstBank } = require('../lib/instrumentBuild');
const { assessPrivateOutputPath, writeNewPrivateFile } = require('../lib/safeOutput');
const { buildComparisonReport } = require('../lib/report');
const {
  BANDS,
  LETTERS,
  KEYS_PER_LETTER_PER_BAND,
  PRIVATE_KEY_SUFFIX,
  PRIVATE_REPORT_SUFFIX,
  BANK_ASSET_RELATIVE_PATH,
} = require('../lib/constants');

const REPO_ROOT = path.join(__dirname, '..', '..', '..');
const BANK_PATH = path.join(REPO_ROOT, ...BANK_ASSET_RELATIVE_PATH.split('/'));

function parseArgs(argv) {
  const args = { check: false };
  const valueFlags = { '--pdf': 'pdf', '--key-out': 'keyOut', '--report-out': 'reportOut', '--pdftotext': 'pdftotext' };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--check') args.check = true;
    else if (flag === '--help' || flag === '-h') args.help = true;
    else if (valueFlags[flag]) {
      const value = argv[i + 1];
      if (!value || value.startsWith('--')) throw new Error(`${flag} needs a value`);
      args[valueFlags[flag]] = value;
      i += 1;
    } else throw new Error(`Unknown argument: ${flag}`);
  }
  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || !args.pdf) {
    console.log(
      'Usage: node bin/build_instrument.js --pdf <source.pdf> [--check]\n' +
        `       [--key-out <file${PRIVATE_KEY_SUFFIX}>] [--report-out <file${PRIVATE_REPORT_SUFFIX}>] [--pdftotext <path>]\n` +
        'See tools/research/README.md.'
    );
    process.exitCode = args.help ? 0 : 1;
    return;
  }

  // Refuse unsafe private paths before doing any work or writing anything.
  const privateOutputs = [
    ['--key-out', args.keyOut, PRIVATE_KEY_SUFFIX],
    ['--report-out', args.reportOut, PRIVATE_REPORT_SUFFIX],
  ].filter(([, value]) => value !== undefined);
  const resolved = {};
  for (const [flag, value, requiredSuffix] of privateOutputs) {
    const verdict = assessPrivateOutputPath(value, { repoRoot: REPO_ROOT, requiredSuffix });
    if (!verdict.ok) {
      console.error(`Refusing ${flag} ${verdict.resolved || value}:\n- ${verdict.reasons.join('\n- ')}`);
      console.error('Nothing was written. Choose a local folder outside the repository and outside OneDrive.');
      process.exitCode = 2;
      return;
    }
    resolved[flag] = verdict.resolved;
  }

  const result = buildFromPdf({ pdfPath: args.pdf, repoRoot: REPO_ROOT, pdftotext: args.pdftotext });
  const keyProblems = validateKeyAgainstBank(result.key, result.bank);
  if (keyProblems.length) throw new Error(`Generated key is inconsistent:\n- ${keyProblems.join('\n- ')}`);

  const { summary, vocab } = result;
  console.log(`Source: ${result.source.fileName} (sha256 ${result.source.sha256.slice(0, 16)}…, ${result.source.pageCount} pages)`);
  console.log(`Key read from extraction modes: ${result.extractionModes.join(' + ')} (all agree)`);
  console.log(`Items: ${summary.totalItems} (${BANDS.map((b) => `${b} ${summary.perBand[b]}`).join(', ')})`);
  for (const band of BANDS) {
    const p = summary.posPerBand[band];
    console.log(`  ${band}: noun ${p.noun}, verb ${p.verb}, adjective ${p.adjective} — matches PDF §3.4`);
  }
  console.log(`Key letters balanced ${LETTERS.map(() => KEYS_PER_LETTER_PER_BAND).join('/')} per band (PDF §3.2): yes`);
  console.log(`Opaque option IDs: ${summary.optionIds} unique`);
  const wrapped = [...result.keyTextStatus.values()].filter((s) => s === 'wrapped').length;
  console.log(`Key text checks: ${result.keyTextStatus.size - wrapped} exact, ${wrapped} wrapped (listed in the report)`);
  const vocabIssues = vocab.filter((v) => v.status !== 'found');
  const posDiffs = vocab.filter((v) => v.status === 'found' && !v.posMatches);
  console.log(
    `Vocab bundles: ${vocab.length - vocabIssues.length}/${vocab.length} found at their band level` +
      (vocabIssues.length ? ` — NOT found: ${vocabIssues.map((v) => `${v.id} ${v.word}`).join(', ')}` : '')
  );
  if (posDiffs.length) {
    console.log(`  Bundle part of speech differs for: ${posDiffs.map((v) => `${v.id} ${v.word}`).join(', ')}`);
  }

  const bankSha256 = result.key.bankSha256;
  if (args.check) {
    const current = fs.existsSync(BANK_PATH) ? fs.readFileSync(BANK_PATH, 'utf8') : null;
    if (current === result.bankJson) {
      console.log(`Check: ${BANK_ASSET_RELATIVE_PATH} is up to date.`);
    } else {
      console.error(`Check: ${BANK_ASSET_RELATIVE_PATH} is ${current === null ? 'missing' : 'out of date'}.`);
      process.exitCode = 1;
    }
  } else {
    fs.mkdirSync(path.dirname(BANK_PATH), { recursive: true });
    fs.writeFileSync(BANK_PATH, result.bankJson);
    console.log(`Wrote app-safe bank: ${BANK_ASSET_RELATIVE_PATH} (sha256 ${bankSha256.slice(0, 16)}…)`);
  }

  if (resolved['--report-out']) {
    const checks = [
      { ok: true, label: `${summary.totalItems} items; ${BANDS.map((b) => `${b} ${summary.perBand[b]}`).join(', ')}` },
      { ok: true, label: 'Every item has 4 substantive options a–d plus e) "Saya tidak tahu kata ini"' },
      { ok: true, label: 'No duplicated option text within an item or within a band' },
      { ok: true, label: 'Part-of-speech counts match §3.4 for every band' },
      { ok: true, label: 'Key letters balanced 5/5/5/5 per band (§3.2)' },
      { ok: true, label: `Key letters identical across extraction modes (${result.extractionModes.join(' + ')})` },
      { ok: true, label: 'Every key text in §7 matches the option its key letter points to (exact or wrapped)' },
      { ok: true, label: `${summary.optionIds} unique opaque option IDs; the app-safe bank contains no key fields` },
      {
        ok: vocabIssues.length === 0,
        label: `${vocab.length - vocabIssues.length}/${vocab.length} target words found in their band's vocab bundle`,
      },
    ];
    const report = buildComparisonReport({ ...result, bankSha256, checks });
    writeNewPrivateFile(resolved['--report-out'], report);
    console.log(`Wrote PRIVATE comparison report: ${resolved['--report-out']}`);
  }
  if (resolved['--key-out']) {
    writeNewPrivateFile(resolved['--key-out'], `${JSON.stringify(result.key, null, 2)}\n`);
    console.log(`Wrote PRIVATE answer key: ${resolved['--key-out']} (contents not shown)`);
  }
  if (!resolved['--key-out']) console.log('Answer key: not written (pass --key-out <file.private.json> to write it).');
}

try {
  main();
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
