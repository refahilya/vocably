#!/usr/bin/env node
'use strict';

/**
 * Stage 1 of the vocab import pipeline: CSV -> canonical merged JSON.
 * Pure local computation — no network, no Firestore, no OpenAI, no
 * secrets. Safe to run repeatedly; always overwrites `output/` with a
 * fresh, deterministic result (this stage itself is not the "avoid
 * regenerating unnecessarily" one — that's the translation stage).
 *
 * Usage: node bin/merge.js
 */

const fs = require('fs');
const path = require('path');

const { loadCsvRecords, parseJsonStringArray } = require('../lib/csvParser');
const { mergeRows, CEFR_ORDER } = require('../lib/merge');

const ROOT = path.join(__dirname, '..');
const INPUT_DIR = path.join(ROOT, 'input');
const OUTPUT_DIR = path.join(ROOT, 'output');

const EXPECTED_HEADER = ['word', 'cefrLevel', 'topics', 'pos', 'source'];

function readAndValidate(fileName, sourceTag) {
  const filePath = path.join(INPUT_DIR, fileName);
  if (!fs.existsSync(filePath)) {
    throw new Error(
      `Missing input file: ${filePath}\n` +
        `Expected the Oxford CSV at tools/vocab_import/input/${fileName}.`
    );
  }
  const text = fs.readFileSync(filePath, 'utf8');
  const { records } = loadCsvRecords(text, EXPECTED_HEADER);

  const validRows = [];
  const malformedRows = [];

  records.forEach((record, index) => {
    const rowNumber = index + 2; // +1 header, +1 for 1-based line numbers

    if (!record.word || record.word.trim() === '') {
      malformedRows.push({
        file: fileName,
        row: rowNumber,
        reason: 'empty/missing word',
      });
      return;
    }
    if (!CEFR_ORDER.includes(record.cefrLevel)) {
      malformedRows.push({
        file: fileName,
        row: rowNumber,
        word: record.word,
        reason: `unrecognized cefrLevel "${record.cefrLevel}"`,
      });
      return;
    }

    const topics = parseJsonStringArray(record.topics);
    if (!topics.ok) {
      malformedRows.push({
        file: fileName,
        row: rowNumber,
        word: record.word,
        reason: `topics: ${topics.error}`,
      });
      return;
    }

    const pos = parseJsonStringArray(record.pos);
    if (!pos.ok) {
      malformedRows.push({
        file: fileName,
        row: rowNumber,
        word: record.word,
        reason: `pos: ${pos.error}`,
      });
      return;
    }

    validRows.push({
      word: record.word,
      cefrLevel: record.cefrLevel,
      topics: topics.value,
      pos: pos.value,
      sourceFile: sourceTag,
    });
  });

  return { validRows, malformedRows, totalRows: records.length };
}

function main() {
  const ox3k = readAndValidate('oxford3000.csv', 'oxford3000');
  const ox5k = readAndValidate('oxford5000.csv', 'oxford5000');

  const allValidRows = [...ox3k.validRows, ...ox5k.validRows];
  const allMalformedRows = [...ox3k.malformedRows, ...ox5k.malformedRows];

  const { documents, report } = mergeRows(allValidRows);

  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'canonical_vocab.json'),
    JSON.stringify(documents, null, 2)
  );

  const fullReport = {
    generatedAt: new Date().toISOString(),
    input: {
      oxford3000: { totalRows: ox3k.totalRows, validRows: ox3k.validRows.length },
      oxford5000: { totalRows: ox5k.totalRows, validRows: ox5k.validRows.length },
    },
    malformedRowCount: allMalformedRows.length,
    malformedRows: allMalformedRows,
    ...report,
  };
  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'import_report.json'),
    JSON.stringify(fullReport, null, 2)
  );

  // Human-readable summary — the developer's dry-run preview
  // (`IMPORT PIPELINE REQUIREMENTS`: dry-run must report row counts,
  // unique words, duplicate groups, overlaps, CEFR distribution,
  // malformed rows, and words needing special handling).
  console.log('=== Vocab import — Stage 1 (merge) dry-run ===');
  console.log(`Oxford 3000: ${ox3k.totalRows} rows (${ox3k.malformedRows.length} malformed)`);
  console.log(`Oxford 5000: ${ox5k.totalRows} rows (${ox5k.malformedRows.length} malformed)`);
  console.log(`Unique normalized words (final documents): ${report.uniqueWordCount}`);
  console.log(`Duplicate-word groups merged: ${report.duplicateWordGroupCount}`);
  console.log(`Oxford 3000/5000 overlap words: ${report.crossFileOverlapCount}`);
  console.log('CEFR distribution (final documents):', report.cefrDistribution);
  console.log(
    `Same-POS collisions requiring manual review: ${report.samePosCollisionCount}`
  );
  if (allMalformedRows.length > 0) {
    console.log(`\n⚠ ${allMalformedRows.length} malformed rows were SKIPPED (not silently — see import_report.json):`);
    for (const row of allMalformedRows.slice(0, 10)) {
      console.log(`  ${row.file}:${row.row} (${row.word ?? '?'}) — ${row.reason}`);
    }
    if (allMalformedRows.length > 10) {
      console.log(`  ...and ${allMalformedRows.length - 10} more (see import_report.json).`);
    }
  }
  if (report.samePosCollisionCount > 0) {
    console.log(
      `\n⚠ ${report.samePosCollisionCount} words had the same POS contributed by more ` +
        'than one source row (genuinely different senses the current schema cannot ' +
        'hold separately — first-encountered row kept, see import_report.json ' +
        '"samePosCollisions" for the full list):'
    );
    for (const c of report.samePosCollisions.slice(0, 10)) {
      console.log(`  "${c.word}" (${c.pos}): kept ${JSON.stringify(c.kept.contextTopics)}, discarded ${JSON.stringify(c.discarded.contextTopics)}`);
    }
  }
  console.log(`\nWrote:\n  ${path.relative(ROOT, path.join(OUTPUT_DIR, 'canonical_vocab.json'))}\n  ${path.relative(ROOT, path.join(OUTPUT_DIR, 'import_report.json'))}`);
}

main();
