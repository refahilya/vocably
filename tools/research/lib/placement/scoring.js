'use strict';

/**
 * Placement Test scoring (spec §6, PT-V1.1). Pure and deterministic; used
 * by the build (test vectors), the researcher export and the tests. The
 * Firestore rules implement the same K2 decision (`firestore.rules`,
 * `placementLevelIndex`) and the emulator tests check both agree.
 *
 * K2 (researcher-selected, NOT expert/supervisor-validated): band k is the
 * result when s[k] >= 7, every lower band has s[j] >= 6, and at most one
 * lower band has exactly 6. The result is the highest such band; when none
 * qualifies the result is A1 with belowA1Threshold (reported as A1*).
 */

const {
  PLACEMENT_BANDS,
  PLACEMENT_ITEMS_PER_BAND,
  PLACEMENT_DONT_KNOW_ID,
  PLACEMENT_THRESHOLDS,
} = require('./constants');

const { mastered, lowerBandMin, maxLowerBandsAtMin } = PLACEMENT_THRESHOLDS;

function checkScores(s) {
  if (!Array.isArray(s) || s.length !== PLACEMENT_BANDS.length) throw new Error('scores must be 5 band scores');
  for (const v of s) {
    if (!Number.isInteger(v) || v < 0 || v > PLACEMENT_ITEMS_PER_BAND) throw new Error('band scores must be integers 0–10');
  }
}

/** K2 level index: 0..4 (A1..C1), or -1 when no band qualifies (A1*). */
function k2LevelIndex(s) {
  checkScores(s);
  let level = -1;
  for (let k = 0; k < s.length; k++) {
    if (s[k] < mastered) continue;
    let ok = true;
    let atMin = 0;
    for (let j = 0; j < k; j++) {
      if (s[j] < lowerBandMin) ok = false;
      else if (s[j] < mastered) atMin++;
    }
    if (ok && atMin <= maxLowerBandsAtMin) level = k;
  }
  return level;
}

/** PT-V1.0 rule R1–R5 (any number of lower bands at 6). Kept only to trace the source test vectors. */
function k0LevelIndex(s) {
  checkScores(s);
  let level = -1;
  for (let k = 0; k < s.length; k++) {
    let ok = s[k] >= mastered;
    for (let j = 0; j < k; j++) if (s[j] < lowerBandMin) ok = false;
    if (ok) level = k;
  }
  return level;
}

/** Result fields stored on a scored attempt, from a level index. */
function resultFromIndex(level) {
  const below = level === -1;
  return {
    resultLevel: below ? 'A1' : PLACEMENT_BANDS[level],
    belowA1Threshold: below,
    pretestTargetBand: level === PLACEMENT_BANDS.length - 1 ? null : PLACEMENT_BANDS[Math.max(level, 0) + 1],
  };
}

/** Quality flags (spec §6.4) — recorded for the researcher only, never shown to the student. */
function scoreFlags(s, level) {
  const flags = [];
  if (level === -1) flags.push('below_a1_threshold');
  const next = level + 1;
  if (next < s.length && (s[next] === 5 || s[next] === 6)) flags.push('near_threshold');
  for (let k = Math.max(level, 0) + 1; k < s.length; k++) {
    if (s[k] >= mastered) {
      flags.push('inconsistent_profile');
      break;
    }
  }
  return flags;
}

/** Full decision for band scores [s] under [rule] ('K2' or the traced 'K0'). */
function decide(s, rule = 'K2') {
  const level = rule === 'K0' ? k0LevelIndex(s) : k2LevelIndex(s);
  return { ...resultFromIndex(level), flags: scoreFlags(s, level) };
}

/**
 * True when 6 or more consecutive answers in display order are the same
 * letter other than E. An E answer ("Saya tidak tahu") ends the current run.
 */
function suspiciousPattern(itemOrder, answers, runLength = 6) {
  let run = 0;
  let previous = null;
  for (const id of itemOrder) {
    const answer = answers[id];
    if (answer === PLACEMENT_DONT_KNOW_ID || answer === undefined) {
      run = 0;
      previous = null;
      continue;
    }
    run = answer === previous ? run + 1 : 1;
    previous = answer;
    if (run >= runLength) return true;
  }
  return false;
}

/** Band scores from stored answers and the private key (`{itemId: letter}`) + item bands. */
function bandScores(answers, key, bandOfItem) {
  const s = PLACEMENT_BANDS.map(() => 0);
  for (const [itemId, letter] of Object.entries(key)) {
    const band = PLACEMENT_BANDS.indexOf(bandOfItem[itemId]);
    if (band === -1) throw new Error(`${itemId}: unknown band`);
    if (answers[itemId] === letter) s[band]++;
  }
  return s;
}

module.exports = {
  k2LevelIndex,
  k0LevelIndex,
  resultFromIndex,
  scoreFlags,
  decide,
  suspiciousPattern,
  bandScores,
};
