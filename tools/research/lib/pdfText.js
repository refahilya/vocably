'use strict';

/**
 * Thin wrapper around the `pdftotext` command-line tool (xpdf or poppler),
 * which is used instead of an npm PDF library so this tooling has no
 * dependencies. The extracted text is returned to the caller only — it is
 * never printed, because the source PDF contains the answer key (§7).
 */

const { execFileSync } = require('child_process');

const MODE_FLAGS = {
  raw: [],
  layout: ['-layout'],
  // `-table` exists in xpdf's pdftotext only; callers treat it as optional.
  table: ['-table'],
};

function extractPdfText({ pdfPath, mode, pdftotext = 'pdftotext' }) {
  const flags = MODE_FLAGS[mode];
  if (!flags) throw new Error(`Unknown pdftotext mode: ${mode}`);
  return execFileSync(pdftotext, ['-enc', 'UTF-8', ...flags, pdfPath, '-'], {
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

/** Same as [extractPdfText] but returns `null` if the mode is unsupported. */
function tryExtractPdfText(options) {
  try {
    return extractPdfText(options);
  } catch {
    return null;
  }
}

module.exports = { extractPdfText, tryExtractPdfText };
