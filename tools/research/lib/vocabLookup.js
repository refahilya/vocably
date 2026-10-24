'use strict';

/**
 * Checks each instrument target word against the app's vocabulary bundles
 * (`assets/vocab/vocab_{level}.json`, `DATA_MODEL.md` §11). Lookup uses the
 * same normalisation as `normalizeWord()` in `lib/utils/` (trim +
 * lowercase). Discrepancies are reported for manual review, not fixed.
 */

const fs = require('fs');
const path = require('path');

const LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1'];

function normalizeWord(word) {
  return String(word).trim().toLowerCase();
}

function loadBundles(vocabDir) {
  const bundles = {};
  for (const level of LEVELS) {
    const file = path.join(vocabDir, `vocab_${level.toLowerCase()}.json`);
    const entries = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : [];
    bundles[level] = new Map(entries.map((entry) => [normalizeWord(entry.word), entry]));
  }
  return bundles;
}

/**
 * Returns one result per item:
 * `{ id, word, band, status: 'found'|'otherLevel'|'missing', levels, posMatches, bundlePos }`.
 */
function checkVocabulary(items, bundles) {
  return items.map((item) => {
    const key = normalizeWord(item.word);
    const levels = LEVELS.filter((level) => bundles[level]?.has(key));
    const entry = bundles[item.band]?.get(key);
    const bundlePos = entry ? entry.posList || [] : [];
    return {
      id: item.id,
      word: item.word,
      band: item.band,
      status: entry ? 'found' : levels.length ? 'otherLevel' : 'missing',
      levels,
      bundlePos,
      posMatches: entry ? bundlePos.includes(item.pos) : null,
    };
  });
}

module.exports = { loadBundles, checkVocabulary, normalizeWord };
