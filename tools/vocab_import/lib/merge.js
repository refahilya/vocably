'use strict';

const { normalizeWord } = require('./normalize');

const CEFR_ORDER = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

function cefrRank(level) {
  const idx = CEFR_ORDER.indexOf(level);
  return idx === -1 ? Infinity : idx;
}

function lowestCefr(levels) {
  return levels.reduce((lowest, level) =>
    cefrRank(level) < cefrRank(lowest) ? level : lowest
  );
}

/**
 * Merges validated rows from both Oxford CSVs into one canonical
 * vocabulary document per normalized word — this is the pure,
 * side-effect-free heart of the import pipeline (no Firestore, no
 * OpenAI, no file I/O), so it's the part with real unit test coverage
 * (`test/merge.test.js`).
 *
 * `rows`: array of `{ word, cefrLevel, topics, pos, sourceFile }`, where
 * `topics`/`pos` are already-parsed string arrays (not raw JSON strings)
 * and `sourceFile` is `"oxford3000"` | `"oxford5000"` — the caller
 * (`bin/merge.js`) is responsible for CSV parsing, JSON-array parsing,
 * and tagging each row with which file it came from before calling this.
 *
 * Approved decisions this function encodes (`DATA_MODEL.md` §2):
 * - `cefrLevel` = the LOWEST level found across every contributing row
 *   for that normalized word, never discarding any meaning because of a
 *   level mismatch.
 * - `source` = `"oxford3000"` if the word appears in Oxford 3000 at all,
 *   else `"oxford5000"` — no new enum value invented for overlap words.
 * - `topics` = the union of every topic from every contributing row,
 *   de-duplicated, first-seen order preserved.
 * - `meanings` = one entry per distinct POS. A single CSV row's `pos`
 *   array (e.g. `["preposition", "adverb"]`) is treated as that many
 *   distinct meaning candidates, per this project's explicit
 *   instruction not to collapse a multi-POS row into one meaning.
 *
 * **Known, disclosed modeling gap this function surfaces rather than
 * hides:** the schema only has room for ONE meaning per POS
 * (`{pos, translation}` — no per-sense/context dimension). When the same
 * normalized word contributes the *same* POS from more than one source
 * row (e.g. "bank" as a noun for both "Money" and "Natural World" —
 * genuinely different senses, not a duplicate), this function keeps
 * only the first-encountered row as that meaning's translation-context
 * source and records the discarded alternative(s) in
 * `report.samePosCollisions` for manual developer review — it does NOT
 * invent a new schema dimension to hold both, since the approved
 * semantic model is explicitly just `pos` + `translation`.
 */
function mergeRows(rows) {
  // Stable priority: oxford3000 rows before oxford5000 rows, and within
  // a file, original row order — so "first-encountered" (for source
  // precedence, and for same-POS collision resolution) is deterministic
  // across reruns, not dependent on object-key iteration order.
  const ordered = [
    ...rows.filter((r) => r.sourceFile === 'oxford3000'),
    ...rows.filter((r) => r.sourceFile === 'oxford5000'),
  ];

  const groups = new Map(); // normalizedWord -> { rawWord, rows: [] }
  for (const row of ordered) {
    const normalized = normalizeWord(row.word);
    if (!groups.has(normalized)) {
      groups.set(normalized, { rawWord: row.word, rows: [] });
    }
    groups.get(normalized).rows.push(row);
  }

  const documents = [];
  const samePosCollisions = [];
  let crossFileOverlapCount = 0;
  let duplicateWordGroupCount = 0;

  for (const [normalized, group] of groups.entries()) {
    const rowsForWord = group.rows;
    if (rowsForWord.length > 1) duplicateWordGroupCount++;

    const sourceFiles = new Set(rowsForWord.map((r) => r.sourceFile));
    if (sourceFiles.has('oxford3000') && sourceFiles.has('oxford5000')) {
      crossFileOverlapCount++;
    }
    const source = sourceFiles.has('oxford3000') ? 'oxford3000' : 'oxford5000';

    const cefrLevel = lowestCefr(rowsForWord.map((r) => r.cefrLevel));

    const topics = [];
    const topicsSeen = new Set();
    for (const row of rowsForWord) {
      for (const topic of row.topics) {
        if (!topicsSeen.has(topic)) {
          topicsSeen.add(topic);
          topics.push(topic);
        }
      }
    }

    // Flatten each row's (possibly multi-valued) `pos` array into one
    // meaning-candidate per POS, then group by POS, first-encountered
    // wins.
    const meaningsByPos = new Map(); // pos -> { pos, contextTopics, cefrLevel, sourceFile }
    for (const row of rowsForWord) {
      for (const pos of row.pos) {
        if (meaningsByPos.has(pos)) {
          samePosCollisions.push({
            word: normalized,
            pos,
            kept: meaningsByPos.get(pos),
            discarded: {
              contextTopics: row.topics,
              cefrLevel: row.cefrLevel,
              sourceFile: row.sourceFile,
            },
          });
          continue;
        }
        meaningsByPos.set(pos, {
          pos,
          contextTopics: row.topics,
          cefrLevel: row.cefrLevel,
          sourceFile: row.sourceFile,
        });
      }
    }

    documents.push({
      word: normalized,
      cefrLevel,
      source,
      topics,
      meanings: [...meaningsByPos.values()].map((m) => ({
        pos: m.pos,
        // translation is filled in by the (separate) translation-
        // generation stage — never invented here.
        translation: null,
        // Not part of the final Firestore/bundle shape — kept only so
        // the translation-generation stage knows what context to ask
        // the model for. Stripped before writing to Firestore/bundle.
        _translationContext: {
          topics: m.contextTopics,
          cefrLevel: m.cefrLevel,
        },
      })),
    });
  }

  // Deterministic output order (helps diffing canonical_vocab.json
  // across reruns).
  documents.sort((a, b) => a.word.localeCompare(b.word));

  const cefrDistribution = {};
  for (const doc of documents) {
    cefrDistribution[doc.cefrLevel] = (cefrDistribution[doc.cefrLevel] || 0) + 1;
  }

  return {
    documents,
    report: {
      totalSourceRows: rows.length,
      uniqueWordCount: documents.length,
      duplicateWordGroupCount,
      crossFileOverlapCount,
      cefrDistribution,
      samePosCollisionCount: samePosCollisions.length,
      samePosCollisions,
    },
  };
}

module.exports = { mergeRows, lowestCefr, cefrRank, CEFR_ORDER };
