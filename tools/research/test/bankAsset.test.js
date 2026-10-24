'use strict';

/**
 * Checks the committed app-safe bank (`assets/research/instrument_v1.json`)
 * itself — the file the Flutter app will bundle.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const { findForbiddenFields } = require('../lib/instrumentBuild');
const { loadBundles, checkVocabulary } = require('../lib/vocabLookup');
const { BANDS, BANK_ASSET_RELATIVE_PATH } = require('../lib/constants');

const REPO_ROOT = path.join(__dirname, '..', '..', '..');
const BANK_PATH = path.join(REPO_ROOT, ...BANK_ASSET_RELATIVE_PATH.split('/'));
const bank = JSON.parse(fs.readFileSync(BANK_PATH, 'utf8'));

/** Part-of-speech composition documented in §3.4 of the instrument PDF. */
const DOCUMENTED_COMPOSITION = {
  A2: { noun: 15, verb: 0, adjective: 5 },
  B1: { noun: 13, verb: 2, adjective: 5 },
  B2: { noun: 7, verb: 7, adjective: 6 },
  C1: { noun: 10, verb: 4, adjective: 6 },
};

test('bank metadata', () => {
  assert.equal(bank.schemaVersion, 1);
  assert.equal(bank.instrumentId, 'vocably-pretest-posttest');
  assert.equal(bank.instrumentVersion, 'v1');
  assert.deepEqual(bank.bands, BANDS);
  assert.equal(bank.itemsPerBand, 20);
  assert.match(bank.source.sha256, /^[0-9a-f]{64}$/);
  assert.match(bank.status, /pending/);
  assert.match(bank.status, /not yet validated/);
});

test('80 unique items, 20 per band, with IDs A2-01 … C1-20 in reference order', () => {
  assert.equal(bank.items.length, 80);
  assert.equal(new Set(bank.items.map((i) => i.id)).size, 80);
  assert.equal(new Set(bank.items.map((i) => i.word.toLowerCase())).size, 80);
  for (const band of BANDS) {
    const items = bank.items.filter((i) => i.band === band);
    assert.equal(items.length, 20, `band ${band}`);
    items.forEach((item, index) => {
      assert.equal(item.number, index + 1);
      assert.equal(item.id, `${band}-${String(index + 1).padStart(2, '0')}`);
    });
  }
});

test('every item has exactly four options with unique opaque IDs and unique text per band', () => {
  const allIds = new Set();
  for (const band of BANDS) {
    const texts = new Set();
    for (const item of bank.items.filter((i) => i.band === band)) {
      assert.equal(item.options.length, 4, item.id);
      for (const option of item.options) {
        assert.deepEqual(Object.keys(option).sort(), ['id', 'text'], item.id);
        assert.match(option.id, /^opt_[0-9a-f]{12}$/);
        assert.ok(!allIds.has(option.id), `duplicate option ID in ${item.id}`);
        allIds.add(option.id);
        const norm = option.text.trim().toLowerCase();
        assert.ok(!texts.has(norm), `duplicate option text in band ${band} (${item.id})`);
        texts.add(norm);
      }
    }
  }
  assert.equal(allIds.size, 320);
});

test('"Saya tidak tahu kata ini" is the separate dont_know choice', () => {
  assert.deepEqual(bank.dontKnowOption, { id: 'dont_know', text: 'Saya tidak tahu kata ini' });
  for (const item of bank.items) {
    assert.ok(!item.options.some((o) => o.id === 'dont_know' || /tidak tahu/i.test(o.text)), item.id);
  }
});

test('contains no answer key or correctness information', () => {
  assert.deepEqual(findForbiddenFields(bank), []);
  const allowedItemFields = ['band', 'id', 'number', 'options', 'pos', 'posLabel', 'word'];
  for (const item of bank.items) assert.deepEqual(Object.keys(item).sort(), allowedItemFields, item.id);
});

test('part-of-speech composition matches §3.4 of the PDF', () => {
  for (const band of BANDS) {
    const items = bank.items.filter((i) => i.band === band);
    const counts = { noun: 0, verb: 0, adjective: 0 };
    for (const item of items) counts[item.pos] += 1;
    assert.deepEqual(counts, DOCUMENTED_COMPOSITION[band], `band ${band}`);
  }
});

test('every target word exists in its band level vocabulary bundle', () => {
  const results = checkVocabulary(bank.items, loadBundles(path.join(REPO_ROOT, 'assets', 'vocab')));
  const missing = results.filter((r) => r.status !== 'found').map((r) => `${r.id} ${r.word}`);
  assert.deepEqual(missing, []);
});
