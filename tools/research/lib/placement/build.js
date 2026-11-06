'use strict';

/**
 * Validates the researcher's placement item file (PT-V1.0 source,
 * `placement_items_v1.0.json`, which CONTAINS the answer key) and builds:
 * - the app-safe PT-V1.1 bank (`assets/placement/…`): items, sentences and
 *   options only — no key, no reserves, no test vectors;
 * - the private key `{itemId: letter}`, written only to an explicit path
 *   outside the repository (see bin/build_placement.js).
 *
 * The item content is copied verbatim; nothing is invented, paraphrased or
 * re-generated. PT-V1.1 changes metadata only (version, K2 policy, pool
 * check) — see `tools/research/README.md` "Placement Test".
 */

const crypto = require('crypto');
const { findForbiddenFields } = require('../instrumentBuild');
const { decide } = require('./scoring');
const {
  PLACEMENT_INSTRUMENT_ID,
  PLACEMENT_SOURCE_VERSION,
  PLACEMENT_VERSION,
  PLACEMENT_SCHEMA_VERSION,
  PLACEMENT_BANDS,
  PLACEMENT_ITEMS_PER_BAND,
  PLACEMENT_OPTION_IDS,
  PLACEMENT_DONT_KNOW_ID,
  PLACEMENT_DONT_KNOW_TEXT,
  PLACEMENT_THRESHOLDS,
  PLACEMENT_SCORING_POLICY,
} = require('./constants');

/**
 * Source test vectors whose K2 result differs from the PT-V1.0 rule — the
 * only one the researcher's K2 decision changes. Any other difference means
 * the source changed and must be reviewed.
 */
const EXPECTED_K2_CHANGES = ['7,6,6,6,7'];

const MARKER_RE = /\[\[([^\]|]+)\|([^\]]+)\]\]/g;

class PlacementValidationError extends Error {
  constructor(problems) {
    super(`Placement instrument validation failed:\n- ${problems.join('\n- ')}`);
    this.name = 'PlacementValidationError';
    this.problems = problems;
  }
}

const sha256 = (text) => crypto.createHash('sha256').update(text).digest('hex');
const normalizeWord = (word) => String(word).trim().toLowerCase();
/** Items are `pt-a1-01` …; reserves (never in the bank) are `pt-res-a2-1` …. */
function itemProblems(item, where, { reserve = false } = {}) {
  const problems = [];
  const bandIndex = PLACEMENT_BANDS.indexOf(item.band);
  if (bandIndex === -1) return [`${where}: unknown band`];
  const match = (reserve ? /^pt-res-([a-c][12])-(\d)$/ : /^pt-([a-c][12])-(\d{2})$/).exec(item.id || '');
  const shape = reserve ? `pt-res-${item.band.toLowerCase()}-N` : `pt-${item.band.toLowerCase()}-NN`;
  if (!match || match[1] !== item.band.toLowerCase()) problems.push(`${where}: id must be ${shape}`);
  if (!item.word || normalizeWord(item.word) !== item.normalizedWord) problems.push(`${where}: normalizedWord must be normalizeWord(word)`);
  if (item.csvLevel !== item.band) problems.push(`${where}: csvLevel differs from band`);
  const ids = Object.keys(item.options || {});
  if (ids.join() !== PLACEMENT_OPTION_IDS.join()) problems.push(`${where}: options must be exactly A, B, C, D`);
  const texts = ids.map((id) => String(item.options[id] || '').trim());
  if (texts.some((t) => !t)) problems.push(`${where}: empty option`);
  if (new Set(texts.map((t) => t.toLowerCase())).size !== texts.length) problems.push(`${where}: duplicate option text`);
  if (!PLACEMENT_OPTION_IDS.includes(item.key)) problems.push(`${where}: key must be one of A–D`);
  const markers = [...String(item.sentenceMarkup || '').matchAll(MARKER_RE)];
  if (markers.length !== 1) {
    problems.push(`${where}: sentenceMarkup needs exactly one [[word|form]] marker`);
  } else {
    const [, base, form] = markers[0];
    if (normalizeWord(base) !== item.normalizedWord) problems.push(`${where}: marker word differs from the item word`);
    if (form !== item.targetForm) problems.push(`${where}: marker form differs from targetForm`);
    const plain = item.sentenceMarkup.replace(MARKER_RE, (_, __, f) => f);
    if (plain !== item.sentence) problems.push(`${where}: sentenceMarkup without the marker differs from sentence`);
  }
  return problems;
}

/**
 * Every problem with [source] (the parsed item file) and its pool
 * separation from [pretestBank] (`assets/research/instrument_<version>.json`).
 */
function validatePlacementSource(source, pretestBank) {
  const problems = [];
  if (source.instrumentVersion !== PLACEMENT_SOURCE_VERSION) problems.push(`instrumentVersion must be ${PLACEMENT_SOURCE_VERSION}`);
  if (JSON.stringify(source.bands) !== JSON.stringify(PLACEMENT_BANDS)) problems.push('bands must be A1, A2, B1, B2, C1');
  const t = source.thresholds || {};
  if (t.mastered !== PLACEMENT_THRESHOLDS.mastered || t.lowerBandMin !== PLACEMENT_THRESHOLDS.lowerBandMin || t.itemsPerBand !== PLACEMENT_ITEMS_PER_BAND) {
    problems.push('thresholds must be mastered 7, lowerBandMin 6, itemsPerBand 10');
  }

  const items = Array.isArray(source.items) ? source.items : [];
  const reserves = Array.isArray(source.reserves) ? source.reserves : [];
  if (items.length !== PLACEMENT_BANDS.length * PLACEMENT_ITEMS_PER_BAND) problems.push(`expected 50 items, found ${items.length}`);
  for (const band of PLACEMENT_BANDS) {
    const n = items.filter((i) => i.band === band).length;
    if (n !== PLACEMENT_ITEMS_PER_BAND) problems.push(`band ${band} has ${n} items`);
  }
  items.forEach((item, i) => problems.push(...itemProblems(item, item.id || `items[${i}]`)));
  reserves.forEach((item, i) => problems.push(...itemProblems(item, `reserve ${item.id || i}`, { reserve: true })));

  const all = [...items, ...reserves];
  const seenIds = new Set();
  const seenWords = new Set();
  for (const item of all) {
    if (seenIds.has(item.id)) problems.push(`${item.id}: duplicate id`);
    if (seenWords.has(item.normalizedWord)) problems.push(`${item.id}: duplicate word within the placement pool`);
    seenIds.add(item.id);
    seenWords.add(item.normalizedWord);
  }

  // K4 / §10: no placement word (item or reserve) may be a pretest/posttest word.
  const pretestWords = new Set((pretestBank.items || []).map((i) => normalizeWord(i.word)));
  for (const item of all) {
    if (pretestWords.has(item.normalizedWord)) problems.push(`${item.id}: word is also a pretest/posttest word`);
  }

  // The source vectors follow PT-V1.0 R1–R5; they must still match it exactly,
  // and K2 may change only the documented vector(s).
  const changed = [];
  for (const v of source.testVectors || []) {
    const k0 = decide(v.s, 'K0');
    const same =
      k0.resultLevel === v.resultLevel &&
      k0.belowA1Threshold === v.belowA1Threshold &&
      k0.pretestTargetBand === v.pretestTargetBand &&
      JSON.stringify(k0.flags) === JSON.stringify(v.flags);
    if (!same) problems.push(`test vector ${v.s.join(',')} does not match the PT-V1.0 rule`);
    const k2 = decide(v.s, 'K2');
    if (k2.resultLevel !== k0.resultLevel || k2.belowA1Threshold !== k0.belowA1Threshold) changed.push(v.s.join(','));
  }
  if (!(source.testVectors || []).length) problems.push('no test vectors');
  if (changed.join('|') !== EXPECTED_K2_CHANGES.join('|')) {
    problems.push(`K2 changes test vectors [${changed.join('] [')}], expected [${EXPECTED_K2_CHANGES.join('] [')}]`);
  }
  return { problems, pretestWordCount: pretestWords.size, placementWordCount: all.length };
}

/** `{ bank, bankJson, bankSha256, key, summary }`; throws PlacementValidationError on any problem. */
function buildPlacement({ source, sourceJson, pretestBank }) {
  const { problems, pretestWordCount, placementWordCount } = validatePlacementSource(source, pretestBank);
  if (problems.length) throw new PlacementValidationError(problems);

  const ordered = PLACEMENT_BANDS.flatMap((band) =>
    source.items.filter((i) => i.band === band).sort((a, b) => a.id.localeCompare(b.id))
  );
  const bank = {
    schemaVersion: PLACEMENT_SCHEMA_VERSION,
    instrumentId: PLACEMENT_INSTRUMENT_ID,
    instrumentVersion: PLACEMENT_VERSION,
    status: 'Researcher instrument. K2 decision rule selected by the researcher; not empirically or expert validated.',
    source: { version: PLACEMENT_SOURCE_VERSION, sha256: sha256(sourceJson.replace(/\r\n/g, '\n')) },
    bands: PLACEMENT_BANDS,
    itemsPerBand: PLACEMENT_ITEMS_PER_BAND,
    thresholds: PLACEMENT_THRESHOLDS,
    scoringPolicy: PLACEMENT_SCORING_POLICY,
    dontKnowOption: { id: PLACEMENT_DONT_KNOW_ID, text: PLACEMENT_DONT_KNOW_TEXT },
    items: ordered.map((item) => ({
      id: item.id,
      band: item.band,
      number: Number(item.id.slice(-2)),
      word: item.word,
      sentence: item.sentence,
      sentenceMarkup: item.sentenceMarkup,
      options: PLACEMENT_OPTION_IDS.map((id) => ({ id, text: item.options[id] })),
    })),
  };
  const forbidden = findForbiddenFields(bank);
  if (forbidden.length) throw new PlacementValidationError([`key-like fields in the app bank: ${forbidden.join(', ')}`]);
  const bankJson = `${JSON.stringify(bank, null, 2)}\n`;
  const bankSha256 = sha256(bankJson);
  const key = Object.fromEntries(ordered.map((item) => [item.id, item.key]));
  return {
    bank,
    bankJson,
    bankSha256,
    key,
    summary: {
      items: ordered.length,
      reservesChecked: (source.reserves || []).length,
      placementWordsChecked: placementWordCount,
      pretestWordsCompared: pretestWordCount,
      overlap: 0,
      testVectors: source.testVectors.length,
      k2ChangedVectors: EXPECTED_K2_CHANGES,
    },
  };
}

/** The private key file contents (`*.private.json`). */
function privateKeyFile({ bankSha256, key }) {
  return `${JSON.stringify(
    {
      warning: 'PRIVATE placement answer key — never commit, never copy into the repository, OneDrive or Firestore exports.',
      instrumentId: PLACEMENT_INSTRUMENT_ID,
      instrumentVersion: PLACEMENT_VERSION,
      bankSha256,
      key,
    },
    null,
    2
  )}\n`;
}

/** Problems with a private key file against the bank (item IDs only, never letters). */
function validatePlacementKey(keyFile, bank, bankSha256) {
  const problems = [];
  if (keyFile.instrumentVersion !== bank.instrumentVersion) problems.push('key instrumentVersion differs from the bank');
  if (keyFile.bankSha256 !== bankSha256) problems.push('key bankSha256 differs from the bank');
  const key = keyFile.key || {};
  const ids = bank.items.map((i) => i.id);
  for (const id of ids) if (!PLACEMENT_OPTION_IDS.includes(key[id])) problems.push(`${id}: missing or invalid key entry`);
  for (const id of Object.keys(key)) if (!ids.includes(id)) problems.push(`${id}: key entry for an unknown item`);
  return problems;
}

module.exports = {
  validatePlacementSource,
  buildPlacement,
  privateKeyFile,
  validatePlacementKey,
  PlacementValidationError,
  EXPECTED_K2_CHANGES,
  normalizeWord,
};
