'use strict';

const fs = require('fs');

/**
 * Resumable local cache of generated translations, keyed by
 * `word::pos` — the whole point of `SPEC.md`/`DATA_MODEL.md`'s "generate
 * once, reuse forever" translation flow. This is the thing that makes
 * `bin/translate.js` safe to interrupt (Ctrl+C, a crashed batch, an
 * overnight run that got cut off) and rerun later: entries already in
 * the cache are never regenerated, only entries still missing get sent
 * to the API.
 *
 * Deliberately a plain JSON file, not Firestore itself — this cache is
 * the pipeline's own resumability mechanism and exists independently of
 * whether Firestore has been seeded yet (`bin/seed_firestore.js` reads
 * this same cache rather than calling the API again).
 */
function cacheKey(word, pos) {
  return `${word}::${pos}`;
}

function loadCache(filePath) {
  if (!fs.existsSync(filePath)) return {};
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (e) {
    throw new Error(
      `Translation cache at ${filePath} exists but isn't valid JSON — ` +
        `refusing to overwrite it blindly. Inspect/fix or delete it ` +
        `manually first. (${e.message})`
    );
  }
}

function saveCache(filePath, cache) {
  fs.writeFileSync(filePath, JSON.stringify(cache, null, 2));
}

module.exports = { cacheKey, loadCache, saveCache };
