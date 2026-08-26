'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { loadCsvRecords, parseJsonStringArray } = require('../lib/csvParser');

test('loadCsvRecords parses a well-formed CSV with quoted JSON-array columns', () => {
  const csv =
    'word,cefrLevel,topics,pos,source\n' +
    'apple,A1,"[""Food""]","[""noun""]",oxford3000\n' +
    'after,A2,"[""General""]","[""conjunction"", ""adverb""]",oxford3000\n';

  const { records } = loadCsvRecords(csv, ['word', 'cefrLevel', 'topics', 'pos', 'source']);

  assert.equal(records.length, 2);
  assert.equal(records[0].word, 'apple');
  assert.equal(records[1].pos, '["conjunction", "adverb"]');
});

test('loadCsvRecords throws on an unexpected header', () => {
  const csv = 'word,level\napple,A1\n';
  assert.throws(
    () => loadCsvRecords(csv, ['word', 'cefrLevel', 'topics', 'pos', 'source']),
    /Unexpected CSV header/
  );
});

test('parseJsonStringArray accepts a valid JSON array of non-empty strings', () => {
  const result = parseJsonStringArray('["noun", "verb"]');
  assert.deepEqual(result, { ok: true, value: ['noun', 'verb'] });
});

test('parseJsonStringArray rejects invalid JSON', () => {
  const result = parseJsonStringArray('[noun]');
  assert.equal(result.ok, false);
});

test('parseJsonStringArray rejects a JSON value that is not an array', () => {
  const result = parseJsonStringArray('"noun"');
  assert.equal(result.ok, false);
});

test('parseJsonStringArray rejects an array containing an empty string', () => {
  const result = parseJsonStringArray('["noun", ""]');
  assert.equal(result.ok, false);
});
