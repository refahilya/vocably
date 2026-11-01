'use strict';

/**
 * Offline Placement Test export (research attempts only; learning-only
 * attempts are not research data and are never exported). Band scores,
 * total and quality flags (incl. suspicious_pattern, where E interrupts a
 * run) are derived HERE from the frozen answers and the private key — the
 * app and Firestore never store them. The stored result is re-checked
 * against an offline K2 recomputation.
 */

const { PLACEMENT_BANDS } = require('../placement/constants');
const { bandScores, decide, suspiciousPattern } = require('../placement/scoring');

const PLACEMENT_COLUMNS = {
  'placement_attempts.csv': [
    'research_id', 'cohort', 'participant_status', 'band', 'band_source', 'attempt_number', 'status', 'void_category',
    'result_level', 'below_a1_threshold', 'target_band', 'offline_check',
    's_A1', 's_A2', 's_B1', 's_B2', 's_C1', 'total', 'flags', 'suspicious_pattern',
    'answered', 'tab_switch_count', 'started_at', 'submitted_at', 'scored_at', 'duration_sec',
  ],
  'placement_items.csv': ['research_id', 'attempt_number', 'display_order', 'item_id', 'band', 'answer', 'correct'],
  'placement_operational_problems.csv': ['category', 'reference', 'detail'],
};

function seconds(a, b) {
  if (!a || !b) return '';
  return Math.round((Date.parse(b) - Date.parse(a)) / 1000);
}

/** [participants]: `[{uid, data}]`; [attempts]: `[{id, data}]` (plain JSON). */
function buildPlacementExport({ bank, keyFile, participants, attempts, cohort = null }) {
  const bandOf = Object.fromEntries(bank.items.map((i) => [i.id, i.band]));
  const key = keyFile.key;
  const people = new Map(participants.filter((p) => !cohort || p.data.cohort === cohort).map((p) => [p.uid, p.data]));
  const attemptRows = [];
  const itemRows = [];
  const problems = [];

  for (const { id, data } of attempts) {
    if (data.context !== 'research') continue;
    const m = /^(.+)_research_(\d+)$/.exec(id);
    if (!m || m[1] !== data.studentId || Number(m[2]) !== data.attemptNumber) {
      problems.push({ category: 'attempt_id_mismatch', reference: id, detail: 'document ID does not match owner/number; not exported' });
      continue;
    }
    const p = people.get(data.studentId);
    if (!p) {
      if (!cohort) problems.push({ category: 'orphan_attempt', reference: id, detail: 'no participant record; not exported' });
      continue;
    }
    const answers = data.answers || {};
    const order = data.itemOrder || [];
    const complete = Object.keys(answers).length === 50;
    const scoredStatus = data.status === 'scored' || (data.status === 'voided' && data.voidedFromStatus === 'scored');
    const row = {
      research_id: p.researchId,
      cohort: p.cohort,
      participant_status: p.status || 'enrolled',
      band: p.band ?? '',
      band_source: p.bandSource ?? '',
      attempt_number: data.attemptNumber,
      status: data.status === 'in_progress' ? 'in_progress (incomplete)' : data.status,
      void_category: data.voidCategory ?? '',
      result_level: data.resultLevel ?? '',
      below_a1_threshold: data.belowA1Threshold ?? '',
      target_band: data.pretestTargetBand ?? '',
      answered: Object.keys(answers).length,
      tab_switch_count: data.tabSwitchCount ?? 0,
      started_at: data.startedAt ?? '',
      submitted_at: data.submittedAt ?? '',
      scored_at: data.scoredAt ?? '',
      duration_sec: seconds(data.startedAt, data.submittedAt),
      offline_check: '',
    };
    if (complete) {
      const s = bandScores(answers, key, bandOf);
      const d = decide(s);
      PLACEMENT_BANDS.forEach((b, k) => { row[`s_${b}`] = s[k]; });
      row.total = s.reduce((x, y) => x + y, 0);
      row.flags = d.flags.join(';');
      row.suspicious_pattern = suspiciousPattern(order, answers) ? 'yes' : 'no';
      if (scoredStatus) {
        const same = d.resultLevel === data.resultLevel && d.belowA1Threshold === data.belowA1Threshold && d.pretestTargetBand === (data.pretestTargetBand ?? null);
        row.offline_check = same ? 'match' : 'MISMATCH';
        if (!same) problems.push({ category: 'result_mismatch', reference: id, detail: 'stored result differs from the offline K2 recomputation' });
      }
    }
    attemptRows.push(row);
    order.forEach((itemId, index) => {
      if (!(itemId in answers)) return;
      itemRows.push({
        research_id: p.researchId,
        attempt_number: data.attemptNumber,
        display_order: index + 1,
        item_id: itemId,
        band: bandOf[itemId] || '',
        answer: answers[itemId],
        correct: answers[itemId] === key[itemId] ? 1 : 0,
      });
    });
  }
  attemptRows.sort((a, b) => String(a.research_id).localeCompare(String(b.research_id)) || a.attempt_number - b.attempt_number);
  return { attemptRows, itemRows, problems };
}

module.exports = { buildPlacementExport, PLACEMENT_COLUMNS };
