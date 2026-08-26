'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { buildBundles } = require('../lib/bundleGen');

test('groups documents by cefrLevel and produces the exact 5-field bundle shape', () => {
  const { levels } = buildBundles([
    {
      word: 'apple',
      cefrLevel: 'A1',
      source: 'oxford3000',
      topics: ['Food'],
      meanings: [{ pos: 'noun', translation: 'apel' }],
    },
  ]);

  assert.equal(levels.A1.length, 1);
  assert.deepEqual(Object.keys(levels.A1[0]).sort(), [
    'cefrLevel',
    'meanings',
    'posList',
    'topics',
    'word',
  ]);
  assert.deepEqual(levels.A1[0].posList, ['noun']);
});

test('never leaks Firestore-only or pipeline-internal fields into the bundle', () => {
  const { levels } = buildBundles([
    {
      word: 'apple',
      cefrLevel: 'A1',
      source: 'oxford3000',
      addedByTeacherId: null,
      createdAt: 'should-not-appear',
      topics: ['Food'],
      meanings: [
        {
          pos: 'noun',
          translation: 'apel',
          _translationContext: { topics: ['Food'], cefrLevel: 'A1' },
        },
      ],
    },
  ]);

  const entry = levels.A1[0];
  assert.equal('source' in entry, false);
  assert.equal('createdAt' in entry, false);
  assert.equal('_translationContext' in entry.meanings[0], false);
});

test('a level with no documents is reported as empty (C2 legitimately absent)', () => {
  const { emptyLevels } = buildBundles([
    { word: 'apple', cefrLevel: 'A1', topics: [], meanings: [{ pos: 'noun', translation: 'apel' }] },
  ]);
  assert.deepEqual(emptyLevels, ['A2', 'B1', 'B2', 'C1', 'C2']);
});

test('entries within a level are sorted alphabetically by word', () => {
  const { levels } = buildBundles([
    { word: 'zebra', cefrLevel: 'A1', topics: [], meanings: [{ pos: 'noun', translation: 'zebra' }] },
    { word: 'apple', cefrLevel: 'A1', topics: [], meanings: [{ pos: 'noun', translation: 'apel' }] },
  ]);
  assert.deepEqual(levels.A1.map((e) => e.word), ['apple', 'zebra']);
});

test('a meaning with no translation yet is preserved as translation: null, not dropped', () => {
  const { levels } = buildBundles([
    { word: 'apple', cefrLevel: 'A1', topics: [], meanings: [{ pos: 'noun', translation: null }] },
  ]);
  assert.equal(levels.A1[0].meanings[0].translation, null);
});
