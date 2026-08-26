'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { mergeRows, lowestCefr } = require('../lib/merge');

test('lowestCefr picks the lowest of several levels regardless of input order', () => {
  assert.equal(lowestCefr(['B2', 'A1']), 'A1');
  assert.equal(lowestCefr(['A2', 'B1', 'A2']), 'A2');
  assert.equal(lowestCefr(['C1']), 'C1');
});

test('a single row with one POS becomes one document with one meaning', () => {
  const { documents } = mergeRows([
    { word: 'apple', cefrLevel: 'A1', topics: ['Food'], pos: ['noun'], sourceFile: 'oxford3000' },
  ]);
  assert.equal(documents.length, 1);
  assert.deepEqual(documents[0].meanings.map((m) => m.pos), ['noun']);
  assert.equal(documents[0].cefrLevel, 'A1');
  assert.equal(documents[0].source, 'oxford3000');
});

test('a single row with multiple POS values becomes multiple distinct meanings', () => {
  const { documents } = mergeRows([
    {
      word: 'after',
      cefrLevel: 'A2',
      topics: ['General'],
      pos: ['conjunction', 'adverb'],
      sourceFile: 'oxford3000',
    },
  ]);
  assert.equal(documents.length, 1);
  assert.deepEqual(
    documents[0].meanings.map((m) => m.pos).sort(),
    ['adverb', 'conjunction']
  );
});

test('duplicate normalized word (case/whitespace) across rows merges into one document, lowest CEFR wins, meanings preserved', () => {
  const { documents, report } = mergeRows([
    { word: 'Address', cefrLevel: 'A1', topics: ['General'], pos: ['noun'], sourceFile: 'oxford3000' },
    { word: ' address ', cefrLevel: 'B2', topics: ['General'], pos: ['verb'], sourceFile: 'oxford3000' },
  ]);
  assert.equal(documents.length, 1);
  const doc = documents[0];
  assert.equal(doc.word, 'address');
  assert.equal(doc.cefrLevel, 'A1');
  assert.deepEqual(doc.meanings.map((m) => m.pos).sort(), ['noun', 'verb']);
  assert.equal(report.duplicateWordGroupCount, 1);
});

test('topics are unioned across duplicate rows without duplicates, first-seen order preserved', () => {
  const { documents } = mergeRows([
    { word: 'bank', cefrLevel: 'A1', topics: ['Money'], pos: ['noun'], sourceFile: 'oxford3000' },
    { word: 'bank', cefrLevel: 'B1', topics: ['Money', 'Natural World'], pos: ['noun'], sourceFile: 'oxford3000' },
  ]);
  assert.deepEqual(documents[0].topics, ['Money', 'Natural World']);
});

test('same POS contributed by two different rows for the same word is a collision: first row kept, discarded one reported, not silently lost', () => {
  const { documents, report } = mergeRows([
    { word: 'bank', cefrLevel: 'A1', topics: ['Money'], pos: ['noun'], sourceFile: 'oxford3000' },
    { word: 'bank', cefrLevel: 'B1', topics: ['Natural World'], pos: ['noun'], sourceFile: 'oxford3000' },
  ]);
  assert.equal(documents[0].meanings.length, 1);
  assert.equal(documents[0].meanings[0]._translationContext.topics[0], 'Money');
  assert.equal(report.samePosCollisionCount, 1);
  assert.equal(report.samePosCollisions[0].word, 'bank');
  assert.equal(report.samePosCollisions[0].discarded.contextTopics[0], 'Natural World');
});

test('a word present in both Oxford 3000 and Oxford 5000 merges into one document with source = oxford3000', () => {
  const { documents, report } = mergeRows([
    { word: 'arm', cefrLevel: 'A1', topics: ['Body And Health'], pos: ['noun'], sourceFile: 'oxford3000' },
    { word: 'arm', cefrLevel: 'C1', topics: ['General'], pos: ['verb'], sourceFile: 'oxford5000' },
  ]);
  assert.equal(documents.length, 1);
  assert.equal(documents[0].source, 'oxford3000');
  assert.equal(documents[0].cefrLevel, 'A1');
  assert.deepEqual(documents[0].meanings.map((m) => m.pos).sort(), ['noun', 'verb']);
  assert.equal(report.crossFileOverlapCount, 1);
});

test('a word present only in Oxford 5000 gets source = oxford5000', () => {
  const { documents } = mergeRows([
    { word: 'acid', cefrLevel: 'B2', topics: ['Natural World'], pos: ['noun'], sourceFile: 'oxford5000' },
  ]);
  assert.equal(documents[0].source, 'oxford5000');
});

test('output document order is deterministic (alphabetical by normalized word)', () => {
  const { documents } = mergeRows([
    { word: 'zebra', cefrLevel: 'A1', topics: ['Animals'], pos: ['noun'], sourceFile: 'oxford3000' },
    { word: 'apple', cefrLevel: 'A1', topics: ['Food'], pos: ['noun'], sourceFile: 'oxford3000' },
  ]);
  assert.deepEqual(documents.map((d) => d.word), ['apple', 'zebra']);
});

test('every meaning starts with translation: null (never fabricated here)', () => {
  const { documents } = mergeRows([
    { word: 'apple', cefrLevel: 'A1', topics: ['Food'], pos: ['noun'], sourceFile: 'oxford3000' },
  ]);
  assert.equal(documents[0].meanings[0].translation, null);
});
