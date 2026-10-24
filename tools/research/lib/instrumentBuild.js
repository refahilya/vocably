'use strict';

/**
 * Validates parsed instrument data and builds two separate artifacts:
 * - the app-safe bank (`assets/research/instrument_v1.json`): items and
 *   options only, with opaque option IDs and NO answer key; and
 * - the private answer key: item ID → correct opaque option ID.
 *
 * Validation errors name item IDs and counts only — never a key letter or
 * key text — so they are safe to print.
 */

const crypto = require('crypto');

const {
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
} = require('./constants');

class InstrumentValidationError extends Error {
  constructor(problems) {
    super(`Instrument validation failed:\n- ${problems.join('\n- ')}`);
    this.name = 'InstrumentValidationError';
    this.problems = problems;
  }
}

function sha256(text) {
  return crypto.createHash('sha256').update(text).digest('hex');
}

function itemId(band, number) {
  return `${band}-${String(number).padStart(2, '0')}`;
}

/**
 * Stable, opaque option ID: a hash of (instrument version, item ID,
 * option text). Deterministic, so rebuilding from the same PDF yields the
 * same IDs; independent of the option's letter and of whether it is the
 * key, so the ID discloses neither.
 */
function optionId(version, id, text) {
  return `opt_${sha256(`${version}|${id}|${text}`).slice(0, 12)}`;
}

function normalizeForCompare(text) {
  return text.replace(/\s+/g, ' ').trim().toLowerCase();
}

/** Assigns item IDs (`A2-01` …) to parsed items. */
function withItemIds(parsedItems) {
  return parsedItems.map((item) => ({ ...item, id: itemId(item.band, item.number) }));
}

/** Every problem with the parsed source, as a list (empty = valid). */
function validateSource({ items, keyLetters, composition }) {
  const problems = [];

  if (items.length !== BANDS.length * ITEMS_PER_BAND) {
    problems.push(`Expected ${BANDS.length * ITEMS_PER_BAND} items, found ${items.length}`);
  }

  const ids = new Set();
  const words = new Set();
  for (const item of items) {
    if (ids.has(item.id)) problems.push(`Duplicate item ID ${item.id}`);
    ids.add(item.id);
    const word = normalizeForCompare(item.word);
    if (words.has(word)) problems.push(`Duplicate target word "${item.word}" (${item.id})`);
    words.add(word);
    if (!POS_BY_LABEL[item.posLabel]) problems.push(`${item.id}: unknown part of speech "${item.posLabel}"`);
    if (item.dontKnowText !== DONT_KNOW_TEXT) problems.push(`${item.id}: option e) is not "${DONT_KNOW_TEXT}"`);

    const optionKeys = Object.keys(item.options || {});
    if (optionKeys.length !== LETTERS.length || !LETTERS.every((l) => optionKeys.includes(l))) {
      problems.push(`${item.id}: expected exactly 4 substantive options a–d`);
      continue;
    }
    const seen = new Set();
    for (const letter of LETTERS) {
      const text = item.options[letter];
      if (typeof text !== 'string' || !text.trim()) {
        problems.push(`${item.id}: option ${letter}) is empty`);
        continue;
      }
      const norm = normalizeForCompare(text);
      if (norm === normalizeForCompare(DONT_KNOW_TEXT)) {
        problems.push(`${item.id}: option ${letter}) duplicates the "tidak tahu" choice`);
      }
      if (seen.has(norm)) problems.push(`${item.id}: duplicate option text "${text}"`);
      seen.add(norm);
    }
  }

  for (const band of BANDS) {
    const bandItems = items.filter((item) => item.band === band);
    if (bandItems.length !== ITEMS_PER_BAND) {
      problems.push(`Band ${band}: expected ${ITEMS_PER_BAND} items, found ${bandItems.length}`);
    }

    const optionOwners = new Map();
    for (const item of bandItems) {
      for (const letter of LETTERS) {
        const text = item.options?.[letter];
        if (typeof text !== 'string') continue;
        const norm = normalizeForCompare(text);
        const owner = optionOwners.get(norm);
        if (owner && owner !== item.id) {
          problems.push(`Band ${band}: option text "${text}" appears in both ${owner} and ${item.id}`);
        }
        optionOwners.set(norm, item.id);
      }
    }

    const posCounts = countPos(bandItems);
    const documented = composition?.[band];
    if (!documented) {
      problems.push(`Band ${band}: no documented part-of-speech composition`);
    } else {
      for (const pos of POS_CODES) {
        if (posCounts[pos] !== documented[pos]) {
          problems.push(
            `Band ${band}: ${pos} count is ${posCounts[pos]}, the PDF's §3.4 documents ${documented[pos]}`
          );
        }
      }
      if (documented.total !== ITEMS_PER_BAND) {
        problems.push(`Band ${band}: §3.4 composition totals ${documented.total}, expected ${ITEMS_PER_BAND}`);
      }
    }

    const letterCounts = Object.fromEntries(LETTERS.map((l) => [l, 0]));
    for (const item of bandItems) {
      const letter = keyLetters.get(item.id);
      if (!letter) problems.push(`${item.id}: no key letter`);
      else if (!LETTERS.includes(letter)) problems.push(`${item.id}: key does not point to a–d`);
      else letterCounts[letter] += 1;
    }
    if (!LETTERS.every((l) => letterCounts[l] === KEYS_PER_LETTER_PER_BAND)) {
      problems.push(
        `Band ${band}: key letters are not balanced ${KEYS_PER_LETTER_PER_BAND}/${KEYS_PER_LETTER_PER_BAND}/` +
          `${KEYS_PER_LETTER_PER_BAND}/${KEYS_PER_LETTER_PER_BAND} as §3.2 of the PDF requires`
      );
    }
  }

  return problems;
}

function countPos(items) {
  const counts = Object.fromEntries(POS_CODES.map((p) => [p, 0]));
  for (const item of items) {
    const pos = POS_BY_LABEL[item.posLabel];
    if (pos) counts[pos] += 1;
  }
  return counts;
}

/**
 * Field names that must never appear anywhere in the app-safe bank.
 * Shared with the tests so the build and the test suite check the same thing.
 */
const FORBIDDEN_BANK_FIELD_RE = /correct|answer|key|letter|score|isright|solution/i;

function findForbiddenFields(value, trail = '$') {
  const hits = [];
  if (Array.isArray(value)) {
    value.forEach((entry, i) => hits.push(...findForbiddenFields(entry, `${trail}[${i}]`)));
  } else if (value && typeof value === 'object') {
    for (const [field, entry] of Object.entries(value)) {
      if (FORBIDDEN_BANK_FIELD_RE.test(field)) hits.push(`${trail}.${field}`);
      hits.push(...findForbiddenFields(entry, `${trail}.${field}`));
    }
  }
  return hits;
}

/**
 * Validates and builds `{ bank, bankJson, key, summary }`. Throws
 * [InstrumentValidationError] listing every problem when the source is
 * incomplete or inconsistent.
 */
function buildInstrument({ items, keyLetters, composition, source, version = INSTRUMENT_VERSION }) {
  const problems = validateSource({ items, keyLetters, composition });

  const optionIds = new Set();
  const bankItems = items.map((item) => ({
    id: item.id,
    band: item.band,
    number: item.number,
    word: item.word,
    pos: POS_BY_LABEL[item.posLabel],
    posLabel: item.posLabel,
    options: LETTERS.map((letter) => {
      const id = optionId(version, item.id, item.options[letter]);
      if (optionIds.has(id) || id === DONT_KNOW_ID) problems.push(`${item.id}: option ID collision`);
      optionIds.add(id);
      return { id, text: item.options[letter] };
    }),
  }));

  if (problems.length) throw new InstrumentValidationError(problems);

  const bank = {
    schemaVersion: BANK_SCHEMA_VERSION,
    instrumentId: INSTRUMENT_ID,
    instrumentVersion: version,
    status:
      'Instrument design complete. Expert validation and the non-respondent pilot are pending; ' +
      'the instrument is not yet validated or shown to be reliable.',
    source: {
      title: 'Rancangan Instrumen Pretest–Posttest Kosakata (Vocably)',
      fileName: source.fileName,
      sha256: source.sha256,
    },
    bands: BANDS,
    itemsPerBand: ITEMS_PER_BAND,
    optionOrder:
      'Options are stored in the source reference order. Item order and the order of the four ' +
      'substantive options are shuffled at runtime (independently for pretest and posttest); ' +
      'the "tidak tahu" choice is always shown last.',
    dontKnowOption: { id: DONT_KNOW_ID, text: DONT_KNOW_TEXT },
    items: bankItems,
  };

  const forbidden = findForbiddenFields(bank);
  if (forbidden.length) {
    throw new InstrumentValidationError([`App-safe bank contains forbidden fields: ${forbidden.join(', ')}`]);
  }

  const bankJson = `${JSON.stringify(bank, null, 2)}\n`;

  const key = {
    warning:
      'PRIVATE research answer key. Never commit, stage, upload, bundle into the app, or share. ' +
      'Store outside every repository and outside OneDrive.',
    instrumentId: INSTRUMENT_ID,
    instrumentVersion: version,
    source: { fileName: source.fileName, sha256: source.sha256 },
    bankSha256: sha256(bankJson),
    entries: bankItems.map((bankItem, index) => {
      const letter = keyLetters.get(bankItem.id);
      const option = bankItem.options[LETTERS.indexOf(letter)];
      return {
        itemId: bankItem.id,
        band: bankItem.band,
        word: bankItem.word,
        correctOptionId: option.id,
        referenceLetter: letter,
        correctOptionText: items[index].options[letter],
      };
    }),
  };

  const summary = {
    totalItems: bankItems.length,
    perBand: Object.fromEntries(BANDS.map((b) => [b, bankItems.filter((i) => i.band === b).length])),
    posPerBand: Object.fromEntries(BANDS.map((b) => [b, countPos(items.filter((i) => i.band === b))])),
    optionIds: optionIds.size,
  };

  return { bank, bankJson, key, summary };
}

/**
 * Checks that a key artifact is complete and consistent with a bank:
 * every item has exactly one entry whose `correctOptionId` is one of that
 * item's four substantive options (never the "tidak tahu" choice).
 * Returns a list of problems naming item IDs only.
 */
function validateKeyAgainstBank(key, bank) {
  const problems = [];
  const entries = new Map();
  for (const entry of key.entries || []) {
    if (entries.has(entry.itemId)) problems.push(`${entry.itemId}: more than one key entry`);
    entries.set(entry.itemId, entry);
  }
  for (const item of bank.items) {
    const entry = entries.get(item.id);
    if (!entry) {
      problems.push(`${item.id}: no key entry`);
      continue;
    }
    if (entry.correctOptionId === bank.dontKnowOption.id) {
      problems.push(`${item.id}: key points to the "tidak tahu" choice`);
    } else if (!item.options.some((option) => option.id === entry.correctOptionId)) {
      problems.push(`${item.id}: key does not point to one of the item's four options`);
    }
  }
  for (const id of entries.keys()) {
    if (!bank.items.some((item) => item.id === id)) problems.push(`${id}: key entry for an unknown item`);
  }
  return problems;
}

module.exports = {
  InstrumentValidationError,
  sha256,
  itemId,
  optionId,
  withItemIds,
  validateSource,
  buildInstrument,
  findForbiddenFields,
  FORBIDDEN_BANK_FIELD_RE,
  validateKeyAgainstBank,
};
