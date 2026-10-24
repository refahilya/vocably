'use strict';

/**
 * Fixed facts about the research instrument, taken from the authoritative
 * source document `Rancangan_Instrumen_Pretest_Vocably.pdf`:
 * - §3.1 / §3.4: 4 bands (A2, B1, B2, C1) × 20 items, 4 substantive
 *   options (a–d) + "Saya tidak tahu kata ini" (e) on every item.
 * - §3.2: in the reference order the key is balanced — a, b, c, d are
 *   each the key of exactly 5 items per band.
 *
 * Nothing in this file is (or may ever become) answer-key data.
 */

const INSTRUMENT_ID = 'vocably-pretest-posttest';
const INSTRUMENT_VERSION = 'v1';
const BANK_SCHEMA_VERSION = 1;

const BANDS = ['A2', 'B1', 'B2', 'C1'];
const ITEMS_PER_BAND = 20;
const LETTERS = ['a', 'b', 'c', 'd'];
const KEYS_PER_LETTER_PER_BAND = 5;

/** The fifth response choice — never a substantive option, never a key. */
const DONT_KNOW_ID = 'dont_know';
const DONT_KNOW_TEXT = 'Saya tidak tahu kata ini';

/** Source label (as printed in the PDF) → stored part-of-speech code. */
const POS_BY_LABEL = {
  'kata benda': 'noun',
  'kata kerja': 'verb',
  'kata sifat': 'adjective',
};
const POS_CODES = ['noun', 'verb', 'adjective'];

/** Filename suffixes the tool requires for its two private outputs. */
const PRIVATE_KEY_SUFFIX = '.private.json';
const PRIVATE_REPORT_SUFFIX = '.private.md';

/** Repo-relative path of the generated, app-safe bank. */
const BANK_ASSET_RELATIVE_PATH = 'assets/research/instrument_v1.json';

module.exports = {
  INSTRUMENT_ID,
  INSTRUMENT_VERSION,
  BANK_SCHEMA_VERSION,
  BANDS,
  ITEMS_PER_BAND,
  LETTERS,
  KEYS_PER_LETTER_PER_BAND,
  DONT_KNOW_ID,
  DONT_KNOW_TEXT,
  POS_BY_LABEL,
  POS_CODES,
  PRIVATE_KEY_SUFFIX,
  PRIVATE_REPORT_SUFFIX,
  BANK_ASSET_RELATIVE_PATH,
};
