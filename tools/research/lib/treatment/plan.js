'use strict';

/**
 * Treatment plan (research treatment, `DATA_MODEL.md` §6e): for every band,
 * the 20 pretest/posttest words of that band split into 4 sessions of 5.
 *
 * - The split is randomized ONCE per band (not per student) from a recorded
 *   seed, so it can be re-derived and checked: HMAC-SHA256(seed, band:i)
 *   drives a Fisher–Yates shuffle of the band's items in bank order; the
 *   shuffled list is cut into groups G1..G4 of 5.
 * - The researcher may choose the session order per band (`order`: session
 *   k uses group order[k-1]); every student of a band gets the same words
 *   in the same order.
 * - The plan file is written once and never overwritten; its Firestore copy
 *   (`researchTreatmentPlan/{planVersion}_{band}`) is create-only, so the
 *   allocation cannot change during the study. A new allocation needs a new
 *   plan version.
 *
 * The words are the public bank words (the app already bundles them); no
 * answer-key data is involved.
 */

const crypto = require('crypto');
const { BANDS, ITEMS_PER_BAND } = require('../constants');

const PLAN_SCHEMA_VERSION = 1;
const SESSIONS_PER_BAND = 4;
const WORDS_PER_SESSION = 5;
const PLAN_COLLECTION = 'researchTreatmentPlan';
const PLAN_VERSION_PATTERN = /^t[0-9]{1,3}$/;
const RANDOMIZATION_METHOD = 'fisher-yates; j = HMAC-SHA256(seed, "<band>:<i>") mod (i + 1), i from 19 down to 1; groups of 5 in shuffled order';

/** The app compares words with `normalizeWord` (lowercase + trim). */
const normalizeWord = (w) => String(w).trim().toLowerCase();

function shuffleIndex(seed, band, i) {
  const digest = crypto.createHmac('sha256', Buffer.from(seed, 'hex')).update(`${band}:${i}`).digest();
  return Number(digest.readBigUInt64BE(0) % BigInt(i + 1));
}

/** Deterministic shuffle of [items] for [band] from [seed] (hex). */
function shuffled(items, seed, band) {
  const out = items.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j = shuffleIndex(seed, band, i);
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

function bandItems(bank, band) {
  return (bank.items || []).filter((item) => item.band === band).sort((a, b) => a.number - b.number);
}

/** `"A2=2,1,3,4;B1=1,2,3,4"` or `{A2: [2,1,3,4]}` → `{band: [g1..g4]}` (identity by default). */
function parseOrder(order) {
  const out = Object.fromEntries(BANDS.map((b) => [b, [1, 2, 3, 4]]));
  if (!order) return out;
  const entries = typeof order === 'string'
    ? order.split(/[;\s]+/).filter(Boolean).map((part) => {
      const [band, list] = part.split('=');
      return [band, String(list || '').split(',').map(Number)];
    })
    : Object.entries(order);
  for (const [band, list] of entries) {
    if (!BANDS.includes(band)) throw new Error(`--order: unknown band "${band}"`);
    const sorted = list.slice().sort();
    if (list.length !== SESSIONS_PER_BAND || JSON.stringify(sorted) !== '[1,2,3,4]') {
      throw new Error(`--order for ${band} must be a permutation of 1,2,3,4`);
    }
    out[band] = list;
  }
  return out;
}

/**
 * Builds the plan from the committed bank. [seed] is a hex string (32+
 * bytes recommended; a random one is generated when omitted).
 */
function buildTreatmentPlan({ bank, bankSha256, planVersion, seed, order, createdAt = new Date().toISOString() }) {
  if (!PLAN_VERSION_PATTERN.test(planVersion || '')) throw new Error('planVersion must look like "t1" (letter t + digits)');
  const usedSeed = seed || crypto.randomBytes(32).toString('hex');
  if (!/^[0-9a-f]{32,128}$/.test(usedSeed)) throw new Error('--seed must be 32–128 lowercase hex characters');
  const sessionOrder = parseOrder(order);
  const bands = {};
  for (const band of BANDS) {
    const items = bandItems(bank, band);
    if (items.length !== ITEMS_PER_BAND) throw new Error(`band ${band} has ${items.length} items, expected ${ITEMS_PER_BAND}`);
    const shuffledItems = shuffled(items, usedSeed, band);
    const groups = [];
    for (let g = 0; g < SESSIONS_PER_BAND; g++) {
      groups.push(shuffledItems.slice(g * WORDS_PER_SESSION, (g + 1) * WORDS_PER_SESSION));
    }
    const sessions = {};
    sessionOrder[band].forEach((group, k) => {
      sessions[String(k + 1)] = groups[group - 1].map((item) => ({ itemId: item.id, word: normalizeWord(item.word) }));
    });
    bands[band] = { sessions };
  }
  return {
    schemaVersion: PLAN_SCHEMA_VERSION,
    planVersion,
    instrumentId: bank.instrumentId,
    instrumentVersion: bank.instrumentVersion,
    bankSha256,
    sessionsPerBand: SESSIONS_PER_BAND,
    wordsPerSession: WORDS_PER_SESSION,
    randomization: { method: RANDOMIZATION_METHOD, seed: usedSeed, sessionOrder, createdAt },
    bands,
  };
}

/** Canonical JSON of the allocation only (what the Firestore copy carries). */
function planSha256(plan) {
  const allocation = BANDS.map((band) => [band, plan.bands[band].sessions]);
  return crypto.createHash('sha256').update(JSON.stringify([plan.planVersion, plan.instrumentVersion, allocation])).digest('hex');
}

/**
 * Problems with [plan] against the committed [bank] (empty = valid):
 * same instrument version and bank hash, every band's 20 items exactly once
 * in 4 sessions of 5, words equal to the bank words, and — when [vocabByBand]
 * is given — every word present in the app's vocabulary bundle of that band
 * (the student app resolves target words from that bundle). Re-deriving the
 * allocation from the recorded seed must give the same plan.
 */
function validateTreatmentPlan(plan, { bank, bankSha256, vocabByBand = null }) {
  const problems = [];
  if (!plan || plan.schemaVersion !== PLAN_SCHEMA_VERSION) return ['unsupported plan schemaVersion'];
  if (!PLAN_VERSION_PATTERN.test(plan.planVersion || '')) problems.push('invalid planVersion');
  if (plan.instrumentVersion !== bank.instrumentVersion) problems.push('plan instrumentVersion differs from the committed bank');
  if (plan.bankSha256 !== bankSha256) problems.push('plan bankSha256 differs from the committed bank (rebuild the plan as a new version)');
  for (const band of BANDS) {
    const sessions = plan.bands && plan.bands[band] && plan.bands[band].sessions;
    if (!sessions || Object.keys(sessions).sort().join() !== '1,2,3,4') {
      problems.push(`${band}: needs sessions 1–4`);
      continue;
    }
    const byId = new Map(bandItems(bank, band).map((item) => [item.id, normalizeWord(item.word)]));
    const seen = new Set();
    for (const [k, entries] of Object.entries(sessions)) {
      if (!Array.isArray(entries) || entries.length !== WORDS_PER_SESSION) problems.push(`${band} session ${k}: needs ${WORDS_PER_SESSION} words`);
      for (const entry of entries || []) {
        if (!byId.has(entry.itemId)) problems.push(`${band} session ${k}: ${entry.itemId} is not a ${band} bank item`);
        else if (byId.get(entry.itemId) !== entry.word) problems.push(`${band} session ${k}: ${entry.itemId} word differs from the bank`);
        if (seen.has(entry.itemId)) problems.push(`${band}: ${entry.itemId} appears twice`);
        seen.add(entry.itemId);
        if (vocabByBand && !vocabByBand[band].has(entry.word)) {
          problems.push(`${band} session ${k}: ${entry.itemId} is not in the app's ${band} vocabulary bundle`);
        }
      }
    }
    if (seen.size !== ITEMS_PER_BAND) problems.push(`${band}: covers ${seen.size} of ${ITEMS_PER_BAND} items`);
  }
  if (!problems.length) {
    try {
      const again = buildTreatmentPlan({
        bank,
        bankSha256,
        planVersion: plan.planVersion,
        seed: plan.randomization.seed,
        order: plan.randomization.sessionOrder,
        createdAt: plan.randomization.createdAt,
      });
      if (planSha256(again) !== planSha256(plan)) problems.push('the allocation does not follow from the recorded seed and order');
    } catch (error) {
      problems.push(`cannot re-derive the allocation: ${error.message}`);
    }
  }
  return problems;
}

/** `researchTreatmentPlan/{planVersion}_{band}` documents the rules read. */
function buildPlanDocs(plan) {
  const hash = planSha256(plan);
  return BANDS.map((band) => {
    const sessions = plan.bands[band].sessions;
    return {
      id: `${plan.planVersion}_${band}`,
      data: {
        planVersion: plan.planVersion,
        instrumentVersion: plan.instrumentVersion,
        band,
        bankSha256: plan.bankSha256,
        planSha256: hash,
        sessions: Object.fromEntries(Object.entries(sessions).map(([k, list]) => [k, list.map((e) => e.word)])),
        itemIds: Object.fromEntries(Object.entries(sessions).map(([k, list]) => [k, list.map((e) => e.itemId)])),
      },
    };
  });
}

module.exports = {
  PLAN_SCHEMA_VERSION,
  SESSIONS_PER_BAND,
  WORDS_PER_SESSION,
  PLAN_COLLECTION,
  PLAN_VERSION_PATTERN,
  normalizeWord,
  buildTreatmentPlan,
  validateTreatmentPlan,
  planSha256,
  buildPlanDocs,
  parseOrder,
};
