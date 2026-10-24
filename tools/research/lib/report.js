'use strict';

/**
 * Builds the human-readable comparison report (Markdown) used to check
 * the extraction against the PDF item by item. The report CONTAINS THE
 * ANSWER KEY, so it is only ever written to a private path validated by
 * `safeOutput.js` — never into the repository, never to the terminal.
 */

const { BANDS, LETTERS, POS_CODES, DONT_KNOW_TEXT } = require('./constants');

function cell(text) {
  return String(text).replace(/\|/g, '\\|');
}

function buildComparisonReport({ items, keyLetters, keyTextStatus, composition, bank, bankSha256, vocab, source, checks }) {
  const lines = [];
  const vocabById = new Map(vocab.map((v) => [v.id, v]));
  const bankById = new Map(bank.items.map((i) => [i.id, i]));

  lines.push('# PRIVATE — Instrument v1 extraction comparison report');
  lines.push('');
  lines.push('> **Contains the answer key.** Keep it outside every repository and outside OneDrive.');
  lines.push('> Do not commit, upload or share it. Delete it once you have finished reviewing.');
  lines.push('');
  lines.push(`- Source PDF: \`${source.fileName}\` (SHA-256 \`${source.sha256}\`, ${source.pageCount} pages)`);
  lines.push(`- Generated app-safe bank: \`assets/research/instrument_v1.json\` (SHA-256 \`${bankSha256}\`)`);
  lines.push(`- Instrument status: expert validation and the non-respondent pilot are **pending**.`);
  lines.push('');
  lines.push('## How to review');
  lines.push('');
  lines.push('For each band, compare every row with §6 (items and options a–d, in reference order) and');
  lines.push('§7 (key) of the PDF. Rows whose key-text check says **wrapped** are cells that wrap onto a');
  lines.push('second line in the PDF table, so the tool could confirm the words but not their exact');
  lines.push('layout — please check those by eye.');
  lines.push('');
  lines.push('## Automated checks');
  lines.push('');
  for (const check of checks) lines.push(`- ${check.ok ? '✅' : '❌'} ${check.label}`);
  lines.push('');

  lines.push('## Part-of-speech composition (PDF §3.4 vs extracted)');
  lines.push('');
  lines.push('| Band | Noun (PDF / extracted) | Verb | Adjective | Total |');
  lines.push('|---|---|---|---|---|');
  for (const band of BANDS) {
    const bandItems = bank.items.filter((i) => i.band === band);
    const counts = Object.fromEntries(POS_CODES.map((p) => [p, bandItems.filter((i) => i.pos === p).length]));
    const doc = composition[band];
    lines.push(
      `| ${band} | ${doc.noun} / ${counts.noun} | ${doc.verb} / ${counts.verb} | ` +
        `${doc.adjective} / ${counts.adjective} | ${doc.total} / ${bandItems.length} |`
    );
  }
  lines.push('');

  lines.push('## Key-letter distribution (PDF §3.2 requires 5 / 5 / 5 / 5 per band)');
  lines.push('');
  lines.push('| Band | a | b | c | d |');
  lines.push('|---|---|---|---|---|');
  for (const band of BANDS) {
    const counts = LETTERS.map(
      (l) => items.filter((i) => i.band === band && keyLetters.get(i.id) === l).length
    );
    lines.push(`| ${band} | ${counts.join(' | ')} |`);
  }
  lines.push('');

  for (const band of BANDS) {
    lines.push(`## Band ${band}`);
    lines.push('');
    lines.push('| No | Item ID | Word (POS) | a) | b) | c) | d) | Key (letter → text) | Key-text check | Vocab bundle |');
    lines.push('|---|---|---|---|---|---|---|---|---|---|');
    for (const item of items.filter((i) => i.band === band)) {
      const letter = keyLetters.get(item.id);
      const v = vocabById.get(item.id);
      const vocabCell =
        v.status === 'found'
          ? `found in ${band}${v.posMatches ? '' : ` (bundle POS: ${v.bundlePos.join(', ') || 'none'})`}`
          : v.status === 'otherLevel'
            ? `NOT in ${band}; found in ${v.levels.join(', ')}`
            : 'NOT FOUND';
      lines.push(
        `| ${item.number} | ${item.id} | **${cell(item.word)}** (${item.posLabel}) | ` +
          `${LETTERS.map((l) => cell(item.options[l])).join(' | ')} | ` +
          `${letter}) ${cell(item.options[letter])} | ${keyTextStatus.get(item.id)} | ${vocabCell} |`
      );
    }
    lines.push('');
    lines.push(`Every ${band} item also offers e) "${DONT_KNOW_TEXT}" (stored as the separate \`dont_know\` choice).`);
    lines.push('');
  }

  lines.push('## Appendix — opaque option IDs (reference letter → ID)');
  lines.push('');
  lines.push('| Item ID | a) | b) | c) | d) |');
  lines.push('|---|---|---|---|---|');
  for (const item of items) {
    const bankItem = bankById.get(item.id);
    lines.push(`| ${item.id} | ${bankItem.options.map((o) => `\`${o.id}\``).join(' | ')} |`);
  }
  lines.push('');
  return `${lines.join('\n')}\n`;
}

module.exports = { buildComparisonReport };
