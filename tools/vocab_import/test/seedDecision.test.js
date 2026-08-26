'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { decideVocabWordAction, topicSlug } = require('../lib/seedDecision');

const canonical = {
  word: 'bank',
  cefrLevel: 'A1',
  source: 'oxford3000',
  topics: ['Money'],
  meanings: [{ pos: 'noun', translation: 'bank' }],
};

test('creates a new document when none exists yet', () => {
  const result = decideVocabWordAction(null, canonical);
  assert.equal(result.action, 'create');
  assert.deepEqual(result.data.meanings, [{ pos: 'noun', translation: 'bank' }]);
});

test('skips a document whose source is "guru" — never touches teacher data', () => {
  const existing = { ...canonical, source: 'guru' };
  const result = decideVocabWordAction(existing, canonical);
  assert.equal(result.action, 'skip-foreign');
  assert.match(result.reason, /guru/);
});

test('skips a document with an unrecognized/foreign source', () => {
  const existing = { ...canonical, source: 'something-else' };
  const result = decideVocabWordAction(existing, canonical);
  assert.equal(result.action, 'skip-foreign');
});

test('skip-unchanged when a prior oxford-sourced document already matches exactly', () => {
  const existing = {
    ...canonical,
    meanings: [{ pos: 'noun', translation: 'bank' }],
    posList: ['noun'],
  };
  const result = decideVocabWordAction(existing, canonical);
  assert.equal(result.action, 'skip-unchanged');
});

test('update (backfill) when an existing document predates posList being persisted', () => {
  // Regression coverage for the Milestone 4 browse-bug investigation:
  // the seed pipeline used to omit `posList` entirely. A document
  // written by that older code is otherwise identical to canonical —
  // this should be detected as needing an update (to add posList), not
  // wrongly treated as already up to date.
  const existing = {
    ...canonical,
    meanings: [{ pos: 'noun', translation: 'bank' }],
    // no posList field at all — the old seed-pipeline shape.
  };
  const result = decideVocabWordAction(existing, canonical);
  assert.equal(result.action, 'update');
  assert.deepEqual(result.data.posList, ['noun']);
});

test('updates when a prior oxford-sourced document differs (e.g. a new meaning was added)', () => {
  const existing = { ...canonical, meanings: [{ pos: 'noun', translation: 'bank' }] };
  const updatedCanonical = {
    ...canonical,
    meanings: [
      { pos: 'noun', translation: 'bank' },
      { pos: 'verb', translation: 'menyimpan uang' },
    ],
  };
  const result = decideVocabWordAction(existing, updatedCanonical);
  assert.equal(result.action, 'update');
  assert.equal(result.data.meanings.length, 2);
});

test('never regresses an existing non-null translation to null from a partially-translated rerun', () => {
  const existing = {
    ...canonical,
    meanings: [{ pos: 'noun', translation: 'bank' }],
    posList: ['noun'],
  };
  const partiallyTranslatedCanonical = {
    ...canonical,
    meanings: [{ pos: 'noun', translation: null }],
  };
  const result = decideVocabWordAction(existing, partiallyTranslatedCanonical);
  // Since nothing actually changed once the existing translation is
  // preserved, this should resolve to skip-unchanged, not a write that
  // would wipe out the translation.
  assert.equal(result.action, 'skip-unchanged');
});

test('rerunning with identical merged canonical data twice is idempotent (second run is skip-unchanged)', () => {
  const first = decideVocabWordAction(null, canonical);
  const second = decideVocabWordAction(first.data, canonical);
  assert.equal(second.action, 'skip-unchanged');
});

test('topicSlug produces a stable, filesystem/docId-safe slug', () => {
  assert.equal(topicSlug('Body And Health'), 'body_and_health');
  assert.equal(topicSlug('  General  '), 'general');
  assert.equal(topicSlug(topicSlug('Body And Health')), 'body_and_health');
});
