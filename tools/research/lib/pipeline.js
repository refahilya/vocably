'use strict';

/**
 * PDF → validated instrument, end to end, without writing anything.
 * Used by `bin/build_instrument.js` and by the optional PDF-backed test.
 */

const fs = require('fs');
const path = require('path');

const { extractPdfText, tryExtractPdfText } = require('./pdfText');
const {
  InstrumentSourceError,
  parseItems,
  parseComposition,
  hasBalancedKeyStatement,
  parseKeyLetters,
  verifyKeyTexts,
} = require('./instrumentParser');
const { sha256, withItemIds, buildInstrument } = require('./instrumentBuild');
const { loadBundles, checkVocabulary } = require('./vocabLookup');

function buildFromPdf({ pdfPath, repoRoot, pdftotext = 'pdftotext' }) {
  if (!pdfPath || !fs.existsSync(pdfPath)) {
    throw new InstrumentSourceError(`Source PDF not found: ${pdfPath || '(none supplied)'}`);
  }
  const pdfBytes = fs.readFileSync(pdfPath);

  let raw;
  let layout;
  try {
    raw = extractPdfText({ pdfPath, mode: 'raw', pdftotext });
    layout = extractPdfText({ pdfPath, mode: 'layout', pdftotext });
  } catch (error) {
    throw new InstrumentSourceError(
      `Could not run pdftotext (${pdftotext}). Install xpdf or poppler, or pass --pdftotext <path>. ` +
        `Cause: ${error.code || error.message}`
    );
  }
  const table = tryExtractPdfText({ pdfPath, mode: 'table', pdftotext });

  const items = withItemIds(parseItems(raw));
  const composition = parseComposition(table || layout);

  const problems = [];
  if (!hasBalancedKeyStatement(raw)) {
    problems.push('The PDF no longer states the balanced-key rule (§3.2: "a, b, c, d masing-masing 5 butir per band")');
  }

  // Read the key from every available layout-preserving extraction and
  // require them to agree, so a single extraction quirk cannot change a key.
  const keyReads = [{ mode: 'layout', ...parseKeyLetters(layout, items) }];
  if (table) keyReads.push({ mode: 'table', ...parseKeyLetters(table, items) });
  for (const read of keyReads) problems.push(...read.problems.map((p) => `[${read.mode}] ${p}`));
  const keyLetters = keyReads[0].letters;
  for (const read of keyReads.slice(1)) {
    const disagreeing = items.filter((i) => read.letters.get(i.id) !== keyLetters.get(i.id)).map((i) => i.id);
    if (disagreeing.length) {
      problems.push(`Key letters disagree between extraction modes for: ${disagreeing.join(', ')}`);
    }
  }

  const keyText = verifyKeyTexts([layout, table], items, keyLetters);
  problems.push(...keyText.problems);
  if (problems.length) throw new InstrumentSourceError(problems);

  const source = {
    fileName: path.basename(pdfPath),
    sha256: sha256(pdfBytes),
    pageCount: raw.split('\f').filter((page) => page.trim()).length,
  };

  const built = buildInstrument({ items, keyLetters, composition, source });
  const vocab = checkVocabulary(built.bank.items, loadBundles(path.join(repoRoot, 'assets', 'vocab')));

  return {
    ...built,
    items,
    keyLetters,
    keyTextStatus: keyText.status,
    composition,
    source,
    vocab,
    extractionModes: keyReads.map((r) => r.mode),
  };
}

module.exports = { buildFromPdf };
