'use strict';

/**
 * Placement bank build and app-safe asset checks. The committed asset is
 * checked for its invariants and for the absence of any key-like field;
 * rebuilding from the researcher's private item file runs only when
 * VOCABLY_PLACEMENT_SOURCE points at it (never committed). Synthetic
 * fixtures below use invented words and options.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { buildPlacement, validatePlacementSource, validatePlacementKey, privateKeyFile, PlacementValidationError } = require('../lib/placement/build');
const { findForbiddenFields } = require('../lib/instrumentBuild');
const { PLACEMENT_BANDS, PLACEMENT_BANK_ASSET_RELATIVE_PATH } = require('../lib/placement/constants');

const REPO_ROOT = path.join(__dirname, '..', '..', '..');
const assetJson = fs.readFileSync(path.join(REPO_ROOT, ...PLACEMENT_BANK_ASSET_RELATIVE_PATH.split('/')), 'utf8').replace(/\r\n/g, '\n');
const asset = JSON.parse(assetJson);
const pretestBank = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, ...require('../lib/constants').BANK_ASSET_RELATIVE_PATH.split('/')), 'utf8'));

const LETTERS = ['A', 'B', 'C', 'D'];
function syntheticSource() {
  const word = (b, i) => `zq${b}${String.fromCharCode(97 + i)}`;
  const mk = (band, b, i, id) => ({
    id,
    band,
    word: word(b, i),
    normalizedWord: word(b, i),
    pos: 'n.',
    targetForm: word(b, i),
    sentence: `This is ${word(b, i)} here.`,
    sentenceMarkup: `This is [[${word(b, i)}|${word(b, i)}]] here.`,
    options: Object.fromEntries(LETTERS.map((l) => [l, `opsi ${band} ${i} ${l}`])),
    key: LETTERS[i % 4],
    csvLevel: band,
  });
  const items = PLACEMENT_BANDS.flatMap((band, b) =>
    Array.from({ length: 10 }, (_, i) => mk(band, b, i, `pt-${band.toLowerCase()}-${String(i + 1).padStart(2, '0')}`))
  );
  const reserves = [mk('A2', 9, 20, 'pt-res-a2-1')];
  return {
    instrumentVersion: 'PT-V1.0',
    bands: PLACEMENT_BANDS,
    thresholds: { mastered: 7, lowerBandMin: 6, itemsPerBand: 10 },
    items,
    reserves,
    testVectors: [
      { s: [10, 10, 10, 10, 10], resultLevel: 'C1', belowA1Threshold: false, pretestTargetBand: null, flags: [] },
      { s: [7, 6, 6, 6, 7], resultLevel: 'C1', belowA1Threshold: false, pretestTargetBand: null, flags: [] },
    ],
  };
}

describe('placement bank build', () => {
  it('builds a key-free bank and a separate key from a valid source', () => {
    const source = syntheticSource();
    const built = buildPlacement({ source, sourceJson: JSON.stringify(source), pretestBank });
    assert.equal(built.bank.items.length, 50);
    assert.deepEqual(findForbiddenFields(built.bank), []);
    assert.equal(Object.keys(built.key).length, 50);
    assert.deepEqual(validatePlacementKey(JSON.parse(privateKeyFile(built)), built.bank, built.bankSha256), []);
  });

  it('refuses a word shared with the pretest/posttest bank', () => {
    const source = syntheticSource();
    const shared = pretestBank.items[0].word;
    Object.assign(source.items[3], { word: shared, normalizedWord: shared.toLowerCase(), targetForm: shared, sentence: `A ${shared}.`, sentenceMarkup: `A [[${shared}|${shared}]].` });
    const { problems } = validatePlacementSource(source, pretestBank);
    assert.ok(problems.some((p) => p.includes('also a pretest/posttest word')));
  });

  it('refuses duplicates, bad options, bad markup and missing items', () => {
    const source = syntheticSource();
    source.items[1].word = source.items[0].word;
    source.items[1].normalizedWord = source.items[0].normalizedWord;
    source.items[2].options.B = source.items[2].options.A;
    source.items[4].sentenceMarkup = 'no marker';
    source.items[5].key = 'E';
    source.items.pop();
    const { problems } = validatePlacementSource(source, pretestBank);
    for (const text of ['duplicate word', 'duplicate option text', 'exactly one [[word|form]] marker', 'key must be one of A–D', 'expected 50 items']) {
      assert.ok(problems.some((p) => p.includes(text)), text);
    }
  });

  it('refuses test vectors that no longer follow the documented K2 change', () => {
    const source = syntheticSource();
    source.testVectors.pop();
    assert.throws(() => buildPlacement({ source, sourceJson: '{}', pretestBank }), PlacementValidationError);
  });

  it('a key file for another bank is refused', () => {
    const source = syntheticSource();
    const built = buildPlacement({ source, sourceJson: JSON.stringify(source), pretestBank });
    const keyFile = JSON.parse(privateKeyFile(built));
    keyFile.bankSha256 = 'x';
    delete keyFile.key[built.bank.items[0].id];
    const problems = validatePlacementKey(keyFile, built.bank, built.bankSha256);
    assert.ok(problems.some((p) => p.includes('bankSha256')));
    assert.ok(problems.some((p) => p.includes('missing or invalid key entry')));
  });
});

describe('committed placement asset', () => {
  it('is PT-V1.1, 5 bands × 10 items, fixed options A–D, and carries no key-like field', () => {
    assert.equal(asset.instrumentVersion, 'PT-V1.1');
    assert.equal(asset.scoringPolicy, 'K2');
    assert.deepEqual(asset.bands, PLACEMENT_BANDS);
    assert.equal(asset.items.length, 50);
    for (const band of PLACEMENT_BANDS) assert.equal(asset.items.filter((i) => i.band === band).length, 10);
    for (const item of asset.items) assert.deepEqual(item.options.map((o) => o.id), LETTERS);
    assert.deepEqual(findForbiddenFields(asset), []);
    assert.ok(!/"key"\s*:/.test(assetJson));
  });

  it('shares no word with the pretest/posttest bank', () => {
    const pretestWords = new Set(pretestBank.items.map((i) => i.word.trim().toLowerCase()));
    assert.deepEqual(asset.items.filter((i) => pretestWords.has(i.word.trim().toLowerCase())).map((i) => i.id), []);
  });

  const sourcePath = process.env.VOCABLY_PLACEMENT_SOURCE;
  it('rebuilding from the private item file reproduces the committed asset exactly', { skip: !sourcePath && 'VOCABLY_PLACEMENT_SOURCE not set' }, () => {
    const sourceJson = fs.readFileSync(sourcePath, 'utf8');
    const built = buildPlacement({ source: JSON.parse(sourceJson), sourceJson, pretestBank });
    assert.equal(built.bankJson, assetJson);
  });
});
