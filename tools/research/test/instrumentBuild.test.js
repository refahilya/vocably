'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  InstrumentValidationError,
  buildInstrument,
  findForbiddenFields,
  optionId,
  validateKeyAgainstBank,
} = require('../lib/instrumentBuild');
const { LETTERS } = require('../lib/constants');
const { makeFixture } = require('./helpers');

const SOURCE = { fileName: 'fixture.pdf', sha256: '0'.repeat(64) };

function build(mutate = () => {}) {
  const fixture = makeFixture();
  mutate(fixture);
  return buildInstrument({ ...fixture, source: SOURCE });
}

function assertInvalid(mutate, pattern) {
  assert.throws(
    () => build(mutate),
    (error) => error instanceof InstrumentValidationError && pattern.test(error.message)
  );
}

test('builds 80 items, 20 per band, each with 4 opaque substantive options', () => {
  const { bank, summary } = build();
  assert.equal(bank.items.length, 80);
  assert.deepEqual(summary.perBand, { A2: 20, B1: 20, B2: 20, C1: 20 });
  const optionIds = bank.items.flatMap((item) => item.options.map((o) => o.id));
  assert.equal(optionIds.length, 320);
  assert.equal(new Set(optionIds).size, 320, 'option IDs are unique across the bank');
  assert.ok(optionIds.every((id) => /^opt_[0-9a-f]{12}$/.test(id)), 'option IDs are opaque hashes');
  assert.equal(new Set(bank.items.map((i) => i.id)).size, 80);
  assert.ok(bank.items.every((item) => item.options.length === 4));
});

test('"Saya tidak tahu kata ini" is a separate choice, never one of the four options', () => {
  const { bank } = build();
  assert.deepEqual(bank.dontKnowOption, { id: 'dont_know', text: 'Saya tidak tahu kata ini' });
  for (const item of bank.items) {
    assert.ok(!item.options.some((o) => o.id === 'dont_know' || o.text === 'Saya tidak tahu kata ini'));
  }
});

test('the app-safe bank carries no answer-key or correctness fields', () => {
  const { bank, bankJson } = build();
  assert.deepEqual(findForbiddenFields(bank), []);
  assert.ok(!/correct|answerKey|referenceLetter|isCorrect/i.test(bankJson));
});

test('the forbidden-field scan catches a key smuggled into the bank', () => {
  const { bank } = build();
  const tampered = structuredClone(bank);
  tampered.items[3].options[1].isCorrect = true;
  tampered.items[7].correctOptionId = 'opt_000000000000';
  assert.deepEqual(findForbiddenFields(tampered), [
    '$.items[3].options[1].isCorrect',
    '$.items[7].correctOptionId',
  ]);
});

test('option IDs depend on item and text only, not on the letter or on correctness', () => {
  const fixture = makeFixture();
  const item = fixture.items[0];
  const before = buildInstrument({ ...fixture, source: SOURCE }).bank.items[0].options;
  // Reverse the reference order of the same four texts: every text keeps its ID.
  const texts = LETTERS.map((l) => item.options[l]).reverse();
  LETTERS.forEach((l, i) => {
    item.options[l] = texts[i];
  });
  const after = buildInstrument({ ...fixture, source: SOURCE }).bank.items[0].options;
  for (const option of before) {
    assert.equal(after.find((o) => o.text === option.text).id, option.id);
  }
  assert.equal(optionId('v1', 'A2-01', 'X'), optionId('v1', 'A2-01', 'X'));
  assert.notEqual(optionId('v1', 'A2-01', 'X'), optionId('v1', 'A2-02', 'X'));
});

test('builds are deterministic', () => {
  assert.equal(build().bankJson, build().bankJson);
});

test('the private key maps every item to the source-derived option, never "tidak tahu"', () => {
  const fixture = makeFixture();
  const { bank, key } = buildInstrument({ ...fixture, source: SOURCE });
  assert.deepEqual(validateKeyAgainstBank(key, bank), []);
  assert.equal(key.entries.length, 80);
  const allMatch = key.entries.every((entry) => {
    const item = bank.items.find((i) => i.id === entry.itemId);
    const letter = fixture.keyLetters.get(entry.itemId);
    return entry.correctOptionId === item.options[LETTERS.indexOf(letter)].id && entry.referenceLetter === letter;
  });
  assert.ok(allMatch, 'every key entry points to the option at its source key letter');
});

test('key validation rejects a missing entry, a "tidak tahu" key and a foreign option', () => {
  const { bank, key } = build();
  const broken = structuredClone(key);
  broken.entries = broken.entries.filter((e) => e.itemId !== 'B1-05');
  broken.entries.find((e) => e.itemId === 'A2-02').correctOptionId = 'dont_know';
  broken.entries.find((e) => e.itemId === 'C1-20').correctOptionId = bank.items[0].options[0].id;
  assert.deepEqual(validateKeyAgainstBank(broken, bank), [
    'A2-02: key points to the "tidak tahu" choice',
    'B1-05: no key entry',
    "C1-20: key does not point to one of the item's four options",
  ]);
});

test('fails when a band does not have 20 items', () => {
  assertInvalid((f) => {
    f.items = f.items.filter((i) => i.id !== 'C1-11');
  }, /Band C1: expected 20 items, found 19/);
});

test('fails on duplicate option text within an item', () => {
  assertInvalid((f) => {
    f.items[2].options.d = f.items[2].options.a;
  }, /A2-03: duplicate option text/);
});

test('fails on duplicate option text across items of one band', () => {
  assertInvalid((f) => {
    f.items[21].options.b = f.items[20].options.c;
  }, /Band B1: option text .* appears in both B1-01 and B1-02/);
});

test('fails on a missing option', () => {
  assertInvalid((f) => {
    delete f.items[44].options.c;
  }, /B2-05: expected exactly 4 substantive options/);
});

test('fails on a duplicate target word or item ID', () => {
  assertInvalid((f) => {
    f.items[10].word = f.items[60].word;
  }, /Duplicate target word/);
  assertInvalid((f) => {
    f.items[1].id = f.items[0].id;
  }, /Duplicate item ID A2-01/);
});

test('fails when the part-of-speech counts differ from the documented composition', () => {
  assertInvalid((f) => {
    f.items[0].posLabel = 'kata sifat';
  }, /Band A2: noun count is 9, the PDF's §3.4 documents 10/);
});

test('fails when key letters are missing or unbalanced', () => {
  assertInvalid((f) => {
    f.keyLetters.delete('B2-09');
  }, /B2-09: no key letter/);
  assertInvalid((f) => {
    f.keyLetters.set('C1-01', f.keyLetters.get('C1-02'));
  }, /Band C1: key letters are not balanced/);
});
