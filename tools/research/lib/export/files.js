'use strict';

/**
 * Export file layout (stable column names — documented in
 * tools/research/README.md, "Export and scoring"), CSV encoding, and the
 * Firestore read for the export.
 *
 * Analysis files carry the pseudonymous researchId only. The
 * `operational_*` files carry UIDs and attempt IDs (needed to fix data
 * problems) and are kept separate so they are never shared with the
 * analysis data. No names, e-mails or credentials are ever read.
 */

const COLUMNS = {
  'analysis_paired.csv': [
    'research_id', 'band', 'cohort', 'pre_score', 'post_score', 'gain', 'pre_percent', 'post_percent',
    'n_gain', 'n_gain_note', 'pre_dont_know', 'post_dont_know',
  ],
  'analysis_attempts.csv': [
    'research_id', 'band', 'cohort', 'instrument_version', 'stage', 'attempt_number', 'status',
    'included_in_scoring', 'exclusion_reason', 'score', 'percent', 'count_B', 'count_S', 'count_T', 'count_K',
    'started_at', 'completed_at',
  ],
  'analysis_items.csv': [
    'research_id', 'band', 'stage', 'attempt_number', 'display_order', 'item_id', 'item_number', 'word',
    'selected_option_id', 'selected_option_text', 'display_position', 'code', 'score', 'answered_at',
  ],
  'analysis_exclusions.csv': ['research_id', 'band', 'cohort', 'stage', 'reason', 'detail'],
  'operational_identifiers.csv': ['research_id', 'uid'],
  'operational_problems.csv': ['category', 'reference', 'detail'],
  'operational_voided_attempts.csv': ['research_id', 'uid', 'stage', 'attempt_number', 'void_reason', 'voided_at'],
};

function csvCell(value) {
  const text = value === null || value === undefined ? '' : String(value);
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/** RFC 4180 CSV (CRLF), UTF-8, header = [columns]. */
function toCsv(columns, rows) {
  const lines = [columns.join(',')];
  for (const row of rows) lines.push(columns.map((c) => csvCell(row[c])).join(','));
  return `${lines.join('\r\n')}\r\n`;
}

/** Maps a buildExport() result to { fileName: csvText }. */
function exportFiles(result) {
  const rowsFor = {
    'analysis_paired.csv': result.pairedRows,
    'analysis_attempts.csv': result.attemptRows,
    'analysis_items.csv': result.itemRows,
    'analysis_exclusions.csv': result.exclusions,
    'operational_identifiers.csv': result.identifiers,
    'operational_problems.csv': result.problems,
    'operational_voided_attempts.csv': result.voidRows,
  };
  return Object.fromEntries(Object.entries(COLUMNS).map(([name, cols]) => [name, toCsv(cols, rowsFor[name])]));
}

function isoOrNull(value) {
  if (value && typeof value.toDate === 'function') return value.toDate().toISOString();
  return value === undefined ? null : value;
}

/** Plain-JSON copy with Firestore Timestamps as ISO strings. */
function plain(value) {
  if (value && typeof value.toDate === 'function') return isoOrNull(value);
  if (Array.isArray(value)) return value.map(plain);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, plain(v)]));
  return value;
}

/** Reads every participant and attempt (Admin SDK; read-only). */
async function fetchResearchData(db) {
  const [participants, attempts] = await Promise.all([
    db.collection('researchParticipants').get(),
    db.collection('researchAssessmentResults').get(),
  ]);
  return {
    participants: participants.docs.map((d) => ({ uid: d.id, data: plain(d.data()) })),
    attempts: attempts.docs.map((d) => ({ id: d.id, data: plain(d.data()) })),
  };
}

module.exports = { COLUMNS, toCsv, csvCell, exportFiles, fetchResearchData, plain };
