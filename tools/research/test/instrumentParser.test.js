'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  InstrumentSourceError,
  parseItems,
  parseComposition,
  hasBalancedKeyStatement,
  parseKeyLetters,
  verifyKeyTexts,
} = require('../lib/instrumentParser');
const { withItemIds } = require('../lib/instrumentBuild');
const { makeFixture, rawText, keyText, compositionText } = require('./helpers');

test('parses all 80 items from raw-mode text, across page footers and form feeds', () => {
  const { items } = makeFixture();
  const parsed = withItemIds(parseItems(rawText(items)));
  assert.equal(parsed.length, 80);
  assert.deepEqual(
    parsed.map((i) => i.id),
    items.map((i) => i.id)
  );
  assert.deepEqual(parsed[0].options, items[0].options);
  assert.equal(parsed[0].posLabel, 'kata benda');
  assert.equal(parsed[79].dontKnowText, 'Saya tidak tahu kata ini');
});

test('a missing item is reported (numbering gap), never silently dropped', () => {
  const { items } = makeFixture();
  const text = rawText(items.filter((i) => i.id !== 'B2-07'));
  assert.throws(() => parseItems(text), (error) => {
    assert.ok(error instanceof InstrumentSourceError);
    assert.match(error.message, /Band B2: item at position 7 is numbered 8/);
    return true;
  });
});

test('unparseable text inside a band section fails the parse', () => {
  const { items } = makeFixture();
  const text = rawText(items).replace('6.2 Pretest band B1 (20 butir)', '6.2 Pretest band B1 (20 butir)\nstray garbage');
  assert.throws(() => parseItems(text), /Band B1: unparsed text before item 1/);
});

test('an item whose fifth choice is not "Saya tidak tahu kata ini" fails', () => {
  const { items } = makeFixture();
  items[3].dontKnowText = 'Tidak tahu';
  assert.throws(() => parseItems(rawText(items)), /option e\) is "Tidak tahu"/);
});

test('an option with characters that cannot be established confidently fails', () => {
  const { items } = makeFixture();
  items[5].options.c = 'Opsi ?? c';
  assert.throws(() => parseItems(rawText(items)), /option c\) has unexpected characters/);
});

test('a missing band heading fails', () => {
  const { items } = makeFixture();
  const text = rawText(items).replace('6.3 Pretest band B2 (20 butir)', '');
  assert.throws(() => parseItems(text), /Expected 4 band headings/);
});

test('parses the §3.4 composition table and rejects a missing row', () => {
  const { composition } = makeFixture();
  const parsed = parseComposition(compositionText(composition));
  assert.deepEqual(parsed.B2, { noun: 10, verb: 5, adjective: 5, total: 20 });
  const withoutC1 = compositionText(composition).replace(/^C1 .*$/m, '');
  assert.throws(() => parseComposition(withoutC1), /composition row missing for: C1/);
});

test('detects the balanced-key statement from §3.2', () => {
  const { items } = makeFixture();
  assert.equal(hasBalancedKeyStatement(rawText(items)), true);
  assert.equal(hasBalancedKeyStatement('no such statement'), false);
});

test('reads one key letter per item from the key section', () => {
  const { items, keyLetters } = makeFixture();
  const { letters, problems } = parseKeyLetters(keyText(items, keyLetters), items);
  assert.deepEqual(problems, []);
  assert.equal(letters.size, 80);
  assert.ok(items.every((i) => letters.get(i.id) === keyLetters.get(i.id)), 'every key letter is read back');
});

test('a missing key entry is reported by item ID only, without key content', () => {
  const { items, keyLetters } = makeFixture();
  const target = items[12];
  const text = keyText(items, keyLetters)
    .split('\n')
    .filter((line) => !line.includes(` ${target.word} →`))
    .join('\n');
  const { problems } = parseKeyLetters(text, items);
  const joined = problems.join('\n');
  assert.match(joined, new RegExp(`${target.id}: key entry found 0 times`));
  assert.match(joined, /§7 contains 79 key entries, expected 80/);
  assert.ok(!joined.includes(target.options[keyLetters.get(target.id)]), 'problem text must not reveal key text');
});

test('key text check: exact, wrapped table cell, and mismatch', () => {
  const { items, keyLetters } = makeFixture();
  const wrapId = items[25].id;
  const ok = verifyKeyTexts([keyText(items, keyLetters, { wrapIds: [wrapId] })], items, keyLetters);
  assert.deepEqual(ok.problems, []);
  assert.equal(ok.status.get(items[0].id), 'exact');
  assert.equal(ok.status.get(wrapId), 'wrapped');

  // The key table prints a text that is not the option the letter points to.
  const target = items[40];
  const letter = keyLetters.get(target.id);
  const tampered = keyText(items, keyLetters).replace(
    `${target.word} → ${letter}) ${target.options[letter]}`,
    `${target.word} → ${letter}) Teks lain`
  );
  const bad = verifyKeyTexts([tampered], items, keyLetters);
  assert.equal(bad.problems.length, 1);
  assert.match(bad.problems[0], new RegExp(`^${target.id}: the key text in §7 does not match`));
  assert.ok(!bad.problems[0].includes(target.options[letter]), 'problem text must not reveal key text');
});
