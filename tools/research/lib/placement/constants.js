'use strict';

/**
 * Fixed facts about the Placement Test instrument, from the researcher's
 * specification `Vocably_Spesifikasi_Placement_Test_v1.0.pdf` and its item
 * file `placement_items_v1.0.json` (PT-V1.0), advanced to PT-V1.1 by the
 * researcher's decisions recorded in `HANDOFF.md` (K2 scoring, no key in
 * the client, separate stage controls).
 *
 * - 5 bands (A1, A2, B1, B2, C1) × 10 items, fixed band order, items
 *   shuffled within a band (spec K3, §8.2).
 * - Options A–D are fixed (never shuffled); E "Saya tidak tahu" is always
 *   last and always scores 0 (K3, K7).
 *
 * Nothing in this file is (or may ever become) answer-key data.
 */

const PLACEMENT_INSTRUMENT_ID = 'vocably-placement';
const PLACEMENT_SOURCE_VERSION = 'PT-V1.0';
const PLACEMENT_VERSION = 'PT-V1.1';
const PLACEMENT_SCHEMA_VERSION = 1;

const PLACEMENT_BANDS = ['A1', 'A2', 'B1', 'B2', 'C1'];
const PLACEMENT_ITEMS_PER_BAND = 10;
const PLACEMENT_OPTION_IDS = ['A', 'B', 'C', 'D'];
const PLACEMENT_DONT_KNOW_ID = 'E';
const PLACEMENT_DONT_KNOW_TEXT = 'Saya tidak tahu';

/** K2 thresholds (spec §6.2 as amended by the researcher's K2 decision). */
const PLACEMENT_THRESHOLDS = Object.freeze({ mastered: 7, lowerBandMin: 6, maxLowerBandsAtMin: 1 });
const PLACEMENT_SCORING_POLICY = 'K2';

/** Repo-relative path of the generated, app-safe placement bank. */
const PLACEMENT_BANK_ASSET_RELATIVE_PATH = 'assets/placement/placement_bank_pt_v1_1.json';

module.exports = {
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
  PLACEMENT_BANK_ASSET_RELATIVE_PATH,
};
