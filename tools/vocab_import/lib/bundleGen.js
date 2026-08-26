'use strict';

const ALL_LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

/**
 * Pure transform: canonical (translated) vocabulary documents ->
 * per-level bundle arrays, matching the exact 5-field shape
 * `VocabBundleEntry`/`DATA_MODEL.md` §11.2 expect: `word`, `meanings`
 * (`{pos, translation}`), `posList` (derived), `cefrLevel`, `topics`.
 * Never includes Firestore-only metadata (`source`, `addedByTeacherId`,
 * `createdAt`/`updatedAt`, or this pipeline's own `_translationContext`).
 *
 * Returns `{ levels: {A1: [...], ...}, emptyLevels: [...] }` — only
 * levels that actually have at least one document are meant to become a
 * real `vocab_{level}.json` file (`C2 may legitimately be absent`); the
 * caller decides what to do with `emptyLevels`.
 */
function buildBundles(documents) {
  const levels = {};
  for (const level of ALL_LEVELS) levels[level] = [];

  for (const doc of documents) {
    const meanings = doc.meanings.map((m) => ({
      pos: m.pos,
      translation: m.translation,
    }));
    const entry = {
      word: doc.word,
      meanings,
      posList: meanings.map((m) => m.pos),
      cefrLevel: doc.cefrLevel,
      topics: doc.topics,
    };
    if (!levels[doc.cefrLevel]) levels[doc.cefrLevel] = [];
    levels[doc.cefrLevel].push(entry);
  }

  for (const level of Object.keys(levels)) {
    levels[level].sort((a, b) => a.word.localeCompare(b.word));
  }

  const emptyLevels = ALL_LEVELS.filter((level) => levels[level].length === 0);

  return { levels, emptyLevels };
}

module.exports = { buildBundles, ALL_LEVELS };
