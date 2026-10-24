'use strict';

/**
 * Optional checks against the real source PDF and private key. Skipped
 * unless you point them at your local files:
 *
 *   VOCABLY_INSTRUMENT_PDF=<path to Rancangan_Instrumen_Pretest_Vocably.pdf>
 *   VOCABLY_INSTRUMENT_KEY=<path to your .private.json key>   (optional)
 *
 * Assertions use booleans and counts only, so a failure never prints key
 * content.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const { buildFromPdf } = require('../lib/pipeline');
const { validateKeyAgainstBank, sha256 } = require('../lib/instrumentBuild');
const { BANK_ASSET_RELATIVE_PATH } = require('../lib/constants');

const REPO_ROOT = path.join(__dirname, '..', '..', '..');
const BANK_PATH = path.join(REPO_ROOT, ...BANK_ASSET_RELATIVE_PATH.split('/'));
const PDF = process.env.VOCABLY_INSTRUMENT_PDF;
const KEY = process.env.VOCABLY_INSTRUMENT_KEY;

test('rebuilding from the PDF reproduces the committed bank exactly', { skip: !PDF && 'VOCABLY_INSTRUMENT_PDF not set' }, () => {
  const result = buildFromPdf({ pdfPath: PDF, repoRoot: REPO_ROOT });
  assert.ok(result.bankJson === fs.readFileSync(BANK_PATH, 'utf8'), 'committed bank differs from a fresh build');
  assert.equal(validateKeyAgainstBank(result.key, result.bank).length, 0, 'generated key is inconsistent');
});

test('the private key file matches a fresh build from the PDF', { skip: !(PDF && KEY) && 'VOCABLY_INSTRUMENT_PDF/KEY not set' }, () => {
  const result = buildFromPdf({ pdfPath: PDF, repoRoot: REPO_ROOT });
  const key = JSON.parse(fs.readFileSync(KEY, 'utf8'));
  assert.ok(key.bankSha256 === sha256(fs.readFileSync(BANK_PATH, 'utf8')), 'key was generated for a different bank');
  assert.equal(validateKeyAgainstBank(key, result.bank).length, 0, 'key is inconsistent with the bank');
  const expected = new Map(result.key.entries.map((e) => [e.itemId, e.correctOptionId]));
  const mismatches = key.entries.filter((e) => expected.get(e.itemId) !== e.correctOptionId).length;
  assert.equal(mismatches, 0, 'key entries differ from the PDF');
});
