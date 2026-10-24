'use strict';

/**
 * The researchInstrument documents the rules read must mirror the app-safe
 * bank exactly and must never carry answer-key information.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const { buildInstrumentDocs, instrumentDocId } = require('../lib/instrumentDocs');
const { findForbiddenFields } = require('../lib/instrumentBuild');
const { BANK_ASSET_RELATIVE_PATH } = require('../lib/constants');

const REPO_ROOT = path.join(__dirname, '..', '..', '..');
const bankJson = fs.readFileSync(path.join(REPO_ROOT, ...BANK_ASSET_RELATIVE_PATH.split('/')), 'utf8');
const bank = JSON.parse(bankJson);
const docs = buildInstrumentDocs(bank, bankJson);

test('one document per band, named {version}_{band}', () => {
  assert.deepEqual(
    docs.map((d) => d.id),
    ['A2', 'B1', 'B2', 'C1'].map((band) => instrumentDocId('v1', band))
  );
});

test('each document mirrors exactly its band’s 20 items and their 4 option IDs and texts', () => {
  for (const { data } of docs) {
    const items = bank.items.filter((item) => item.band === data.band);
    assert.equal(Object.keys(data.optionIds).length, 20);
    for (const item of items) {
      assert.deepEqual(data.optionIds[item.id], item.options.map((o) => o.id));
      assert.deepEqual(data.optionTexts[item.id], Object.fromEntries(item.options.map((o) => [o.id, o.text])));
    }
    assert.match(data.sourceBankSha256, /^[0-9a-f]{64}$/);
  }
});

test('the documents carry no answer-key or correctness fields, and no "tidak tahu" option', () => {
  for (const { data } of docs) {
    assert.deepEqual(findForbiddenFields(data), []);
    assert.ok(!JSON.stringify(data).includes('dont_know'));
  }
});
