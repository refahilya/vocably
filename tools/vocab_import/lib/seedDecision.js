'use strict';

/**
 * Pure decision logic for one `vocabWords/{docId}` write during
 * Firestore seeding — deliberately separated from `bin/seed_firestore.js`
 * (which does the actual network I/O) so this can be fully unit-tested
 * without a live Firestore connection or credentials.
 *
 * `existingDoc`: the current Firestore document data for this normalized
 * word, or `null`/`undefined` if it doesn't exist yet.
 * `canonicalDoc`: this word's entry from `output/canonical_vocab_translated.json`
 * (already has `meanings[].translation` filled in where available).
 *
 * Returns `{ action: 'create' | 'update' | 'skip-unchanged' | 'skip-foreign', data?, reason? }`.
 */
function decideVocabWordAction(existingDoc, canonicalDoc) {
  if (!existingDoc) {
    const meanings = canonicalDoc.meanings.map((m) => ({
      pos: m.pos,
      translation: m.translation,
    }));
    return {
      action: 'create',
      data: {
        word: canonicalDoc.word,
        meanings,
        // DATA_MODEL.md §2: "turunan otomatis dari meanings[].pos" —
        // Firestore has no computed fields, so it must actually be
        // persisted (VocabWord.toMap() does the same on the Dart side).
        // Found missing here during the Milestone 4 browse-bug
        // investigation — not the cause of that bug (VocabWord.fromFirestore
        // never reads it back), but a real doc/impl mismatch worth closing.
        posList: meanings.map((m) => m.pos),
        cefrLevel: canonicalDoc.cefrLevel,
        topics: canonicalDoc.topics,
        source: canonicalDoc.source,
      },
    };
  }

  // `FIRESTORE IMPORT` requirements: never overwrite teacher-authored
  // data, and never guess at data this importer didn't create.
  if (existingDoc.source !== 'oxford3000' && existingDoc.source !== 'oxford5000') {
    return {
      action: 'skip-foreign',
      reason:
        `existing document has source="${existingDoc.source}" ` +
        '(not one this importer owns) — the importer never touches ' +
        'teacher-authored or otherwise foreign vocabulary documents.',
    };
  }

  // A prior run of this same importer created this doc — safe to
  // reconcile with the latest canonical data. Preserve any translation
  // the existing document already has for a POS where the new run
  // doesn't have one yet (defensive: a partially-completed translation
  // stage should never regress an existing non-null translation to
  // null).
  const existingByPos = new Map(
    (existingDoc.meanings || []).map((m) => [m.pos, m])
  );
  const mergedMeanings = canonicalDoc.meanings.map((m) => {
    const existingMeaning = existingByPos.get(m.pos);
    const translation =
      m.translation !== null
        ? m.translation
        : existingMeaning?.translation ?? null;
    return { pos: m.pos, translation };
  });

  const mergedData = {
    word: canonicalDoc.word,
    meanings: mergedMeanings,
    posList: mergedMeanings.map((m) => m.pos),
    cefrLevel: canonicalDoc.cefrLevel,
    topics: canonicalDoc.topics,
    source: canonicalDoc.source,
  };

  if (isEquivalent(existingDoc, mergedData)) {
    return { action: 'skip-unchanged' };
  }

  return { action: 'update', data: mergedData };
}

function isEquivalent(a, b) {
  return (
    a.word === b.word &&
    a.cefrLevel === b.cefrLevel &&
    a.source === b.source &&
    arraysEqual(a.topics, b.topics) &&
    arraysEqual(a.posList, b.posList) &&
    meaningsEqual(a.meanings, b.meanings)
  );
}

function arraysEqual(a, b) {
  const arrA = a || [];
  const arrB = b || [];
  return arrA.length === arrB.length && arrA.every((v, i) => v === arrB[i]);
}

function meaningsEqual(a, b) {
  const arrA = a || [];
  const arrB = b || [];
  if (arrA.length !== arrB.length) return false;
  return arrA.every(
    (m, i) => m.pos === arrB[i].pos && m.translation === arrB[i].translation
  );
}

/** Deterministic docId for the `topics` master-list collection — no
 * normalization rule is documented for topic names (unlike
 * `normalizeWord()` for `vocabWords`), so this importer picks a simple
 * slug so reruns are idempotent. Flagged in `DATA_MODEL.md` as a
 * clarification, not a silent invention. */
function topicSlug(name) {
  return name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

module.exports = { decideVocabWordAction, topicSlug };
