'use strict';

/**
 * Pure text parsers for the instrument PDF's extracted text (no I/O, so
 * they are unit-testable with synthetic text).
 *
 * Sources inside the PDF:
 * - §6.1–§6.4 "Pretest band XX (20 butir)": the 80 items, read from
 *   pdftotext's default (raw) mode, where every item is one paragraph.
 * - §3.4 "Komposisi kelas kata per band": the documented part-of-speech
 *   counts, read from `-table` (or `-layout`) mode.
 * - §7 "Kunci jawaban": the key letter for each item, read from `-layout`
 *   and/or `-table` mode.
 *
 * IMPORTANT: every error message produced from §7 names item IDs only —
 * never a key letter or key text — so a failure can be printed safely.
 */

const {
  BANDS,
  ITEMS_PER_BAND,
  LETTERS,
  DONT_KNOW_TEXT,
  POS_BY_LABEL,
} = require('./constants');

class InstrumentSourceError extends Error {
  constructor(problems) {
    const list = Array.isArray(problems) ? problems : [problems];
    super(`Instrument source is incomplete or inconsistent:\n- ${list.join('\n- ')}`);
    this.name = 'InstrumentSourceError';
    this.problems = list;
  }
}

const FOOTER_RE = /Rancangan Instrumen Pretest[–-]Posttest Vocably\s*·\s*Halaman\s+\d+\s+dari\s+\d+/g;

function cleanText(text) {
  return text.replace(/\f/g, '\n').replace(FOOTER_RE, ' ');
}

function normalizeSpace(text) {
  return text.replace(/\s+/g, ' ').trim();
}

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Returns the text between the first [startRe] match and the next [endRe]. */
function sliceSection(text, startRe, endRe, label) {
  const start = text.search(startRe);
  if (start < 0) throw new InstrumentSourceError(`Section not found: ${label}`);
  const rest = text.slice(start);
  const end = rest.slice(1).search(endRe);
  if (end < 0) throw new InstrumentSourceError(`End of section not found: ${label}`);
  return rest.slice(0, end + 1);
}

const WORD_PATTERN = "[A-Za-z][A-Za-z'-]*(?: [A-Za-z][A-Za-z'-]*)*";
const OPTION_TEXT_RE = /^[A-Za-z][A-Za-z-]*(?: [A-Za-z][A-Za-z-]*)*$/;
const POS_LABEL_PATTERN = Object.keys(POS_BY_LABEL).map(escapeRegExp).join('|');

/**
 * Parses §6.1–§6.4 into `[{ band, number, word, posLabel, options: {a,b,c,d}, dontKnowText }]`.
 * Fails if anything in a band section is left unparsed, so no item can be
 * silently dropped.
 */
function parseItems(rawText) {
  const text = cleanText(rawText);
  const problems = [];

  const headingRe = /6\.(\d)\s+Pretest band (A2|B1|B2|C1) \((\d+) butir\)/g;
  const headings = [...text.matchAll(headingRe)];
  const endOfItems = text.search(/7\.\s+Kunci jawaban/);
  if (headings.length !== BANDS.length) {
    throw new InstrumentSourceError(
      `Expected ${BANDS.length} band headings in §6, found ${headings.length}`
    );
  }
  if (endOfItems < 0) throw new InstrumentSourceError('Section not found: §7 Kunci jawaban');

  const items = [];
  headings.forEach((heading, index) => {
    const band = heading[2];
    if (band !== BANDS[index]) {
      problems.push(`Band heading ${index + 1} is ${band}, expected ${BANDS[index]}`);
      return;
    }
    if (Number(heading[3]) !== ITEMS_PER_BAND) {
      problems.push(`Band ${band} heading declares ${heading[3]} items, expected ${ITEMS_PER_BAND}`);
    }
    const bodyStart = heading.index + heading[0].length;
    const bodyEnd = index + 1 < headings.length ? headings[index + 1].index : endOfItems;
    const body = normalizeSpace(text.slice(bodyStart, bodyEnd));

    const itemRe = new RegExp(
      `(\\d+)\\. (${WORD_PATTERN}) \\((${POS_LABEL_PATTERN})\\) ` +
        'a\\) (.+?) b\\) (.+?) c\\) (.+?) d\\) (.+?) e\\) (.+?)' +
        `(?= \\d+\\. ${WORD_PATTERN} \\(|$)`,
      'g'
    );

    let cursor = 0;
    const bandItems = [];
    for (const match of body.matchAll(itemRe)) {
      const gap = body.slice(cursor, match.index).trim();
      if (gap) problems.push(`Band ${band}: unparsed text before item ${match[1]}: "${gap}"`);
      cursor = match.index + match[0].length;
      bandItems.push({
        band,
        number: Number(match[1]),
        word: match[2],
        posLabel: match[3],
        options: { a: match[4], b: match[5], c: match[6], d: match[7] },
        dontKnowText: match[8],
      });
    }
    const tail = body.slice(cursor).trim();
    if (tail) problems.push(`Band ${band}: unparsed text after last item: "${tail}"`);

    bandItems.forEach((item, i) => {
      if (item.number !== i + 1) {
        problems.push(`Band ${band}: item at position ${i + 1} is numbered ${item.number}`);
      }
    });
    items.push(...bandItems);
  });

  for (const item of items) {
    const where = `${item.band} item ${item.number} (${item.word})`;
    if (item.dontKnowText !== DONT_KNOW_TEXT) {
      problems.push(`${where}: option e) is "${item.dontKnowText}", expected "${DONT_KNOW_TEXT}"`);
    }
    for (const letter of LETTERS) {
      if (!OPTION_TEXT_RE.test(item.options[letter])) {
        problems.push(`${where}: option ${letter}) has unexpected characters: "${item.options[letter]}"`);
      }
    }
  }

  if (problems.length) throw new InstrumentSourceError(problems);
  return items;
}

/** Parses §3.4's part-of-speech table into `{ A2: { noun, verb, adjective, total } , … }`. */
function parseComposition(text) {
  const section = sliceSection(
    cleanText(text),
    /Komposisi kelas kata per band/,
    /Daftar kata target/,
    '§3.4 Komposisi kelas kata per band'
  );
  const composition = {};
  for (const match of section.matchAll(/^\s*(A2|B1|B2|C1)\s+(\d+)\s+(\d+)\s+(\d+)\b/gm)) {
    const [noun, verb, adjective] = [match[2], match[3], match[4]].map(Number);
    composition[match[1]] = { noun, verb, adjective, total: noun + verb + adjective };
  }
  const missing = BANDS.filter((band) => !composition[band]);
  if (missing.length) {
    throw new InstrumentSourceError(`§3.4 composition row missing for: ${missing.join(', ')}`);
  }
  return composition;
}

/** Confirms the PDF states the balanced-key rule enforced by the build. */
function hasBalancedKeyStatement(rawText) {
  return /a, b, c, d masing-masing 5 butir per band/.test(normalizeSpace(cleanText(rawText)));
}

function keySection(text) {
  return sliceSection(cleanText(text), /7\.\s+Kunci jawaban/, /8\.\s+Rubrik penilaian/, '§7 Kunci jawaban');
}

/**
 * Reads the key letter for each item from one extraction of §7, by
 * locating "<word> → <letter>)". Returns `{ letters: Map(itemId → letter), problems }`.
 * [items] must carry `id` and `word`.
 */
function parseKeyLetters(text, items) {
  const section = keySection(text);
  const problems = [];
  const letters = new Map();

  const arrows = (section.match(/→/g) || []).length;
  if (arrows !== items.length) {
    problems.push(`§7 contains ${arrows} key entries, expected ${items.length}`);
  }

  for (const item of items) {
    const re = new RegExp(`(?:^|[^A-Za-z])${escapeRegExp(item.word)}\\s*→\\s*([a-e])\\)`, 'g');
    const found = [...section.matchAll(re)].map((m) => m[1]);
    if (found.length !== 1) {
      problems.push(`${item.id}: key entry found ${found.length} times in §7 (expected exactly 1)`);
      continue;
    }
    if (!LETTERS.includes(found[0])) {
      problems.push(`${item.id}: key entry does not point to a substantive option a–d`);
      continue;
    }
    letters.set(item.id, found[0]);
  }
  return { letters, problems };
}

/** Cells of a layout/table line: runs of text separated by 2+ spaces. */
function cellsOf(line) {
  return line
    .split(/\s{2,}/)
    .map((cell) => cell.trim())
    .filter(Boolean);
}

const WRAP_LOOKAHEAD_LINES = 4;

/**
 * Checks, in one layout-preserving extraction, that the key cell
 * "<word> → <letter>) <text>" carries the text of the option that letter
 * points to. Returns 'exact' (whole text in the cell), 'wrapped' (the
 * cell holds the start of the text and the rest is a cell of its own on
 * one of the next few lines — a table cell that wraps), or null.
 */
function keyCellStatus(lines, item, letter) {
  const optionText = item.options[letter];
  const cellRe = new RegExp(`(?:^|[^A-Za-z])${escapeRegExp(item.word)}\\s*→\\s*${letter}\\)`);
  for (let i = 0; i < lines.length; i += 1) {
    const match = cellRe.exec(lines[i]);
    if (!match) continue;
    const after = lines[i].slice(match.index + match[0].length).match(/^ ?(.*?)(?:\s{2,}|$)/)[1].trim();
    if (after === optionText) return 'exact';
    if (after && !optionText.startsWith(`${after} `)) return null;
    const remainder = optionText.slice(after.length).trim();
    const following = lines.slice(i + 1, i + 1 + WRAP_LOOKAHEAD_LINES);
    return following.some((line) => cellsOf(line).includes(remainder)) ? 'wrapped' : null;
  }
  return null;
}

/**
 * Checks that the key text printed in §7 is the text of the option the
 * key letter points to, using every available layout-preserving
 * extraction (an item passes if any extraction confirms it). Items whose
 * cell wraps onto another line are reported as 'wrapped' and listed in
 * the review report for a visual check.
 * Returns `{ status: Map(itemId → 'exact'|'wrapped'), problems }`.
 */
function verifyKeyTexts(texts, items, letters) {
  const extractions = texts.filter(Boolean).map((t) => keySection(t).split(/\r?\n/));
  const status = new Map();
  const problems = [];
  for (const item of items) {
    const letter = letters.get(item.id);
    if (!letter) continue;
    const results = extractions.map((lines) => keyCellStatus(lines, item, letter));
    if (results.includes('exact')) status.set(item.id, 'exact');
    else if (results.includes('wrapped')) status.set(item.id, 'wrapped');
    else problems.push(`${item.id}: the key text in §7 does not match the option its key letter points to`);
  }
  return { status, problems };
}

module.exports = {
  InstrumentSourceError,
  parseItems,
  parseComposition,
  hasBalancedKeyStatement,
  parseKeyLetters,
  verifyKeyTexts,
  normalizeSpace,
};
