'use strict';

/**
 * Offline scoring of the pretest/posttest — trusted researcher tooling only,
 * never the app. Implements exactly the instrument's rules
 * (`Rancangan_Instrumen_Pretest_Vocably.pdf` §4.6, §8, §9.1):
 * - per answer: B (key option) = 1; S (another option) = 0; T ("Saya tidak
 *   tahu kata ini") = 0; K (no answer / missing) = 0;
 * - score = number of B, 0–20; percentage = score ÷ 20 × 100;
 * - Gain = Post − Pre (may be negative);
 * - N-gain = (Post − Pre) ÷ (20 − Pre), NOT computed when Pre = 20 (left
 *   blank with an explicit note, never 0 or infinity);
 * - a participant without a valid completed pretest AND posttest is
 *   excluded from the paired analysis, with the reason reported.
 *
 * Attempt selection never guesses. For each participant and stage there
 * must be exactly one non-voided attempt, it must be the currently
 * authorized attempt number, and it must be structurally valid against the
 * bank; otherwise the stage is excluded with a reason. Voided attempts are
 * listed but never scored. No statistical analysis beyond these measures is
 * done here.
 *
 * Pure: no I/O. Timestamps arrive as ISO strings (or null).
 */

const { BANDS, ITEMS_PER_BAND, DONT_KNOW_ID, DONT_KNOW_TEXT } = require('../constants');
const { validateKeyAgainstBank } = require('../instrumentBuild');

const STAGES = ['preTest', 'postTest'];

/** Key problems (item IDs only, never key values). Empty = usable. */
function validateKey(key, bank, bankSha256) {
  const problems = [];
  if (!key || typeof key !== 'object' || !Array.isArray(key.entries)) return ['the key file has no entries list'];
  if (key.instrumentId !== bank.instrumentId) problems.push('key instrumentId does not match the bank');
  if (key.instrumentVersion !== bank.instrumentVersion) problems.push('key instrumentVersion does not match the bank');
  if (key.bankSha256 !== bankSha256) problems.push('key was built for a different bank (bankSha256 mismatch)');
  problems.push(...validateKeyAgainstBank(key, bank));
  const items = new Map(bank.items.map((item) => [item.id, item]));
  for (const entry of key.entries) {
    const item = items.get(entry.itemId);
    if (!item) continue;
    if (entry.band !== item.band) problems.push(`${entry.itemId}: key band does not match the bank`);
    const option = item.options.find((o) => o.id === entry.correctOptionId);
    if (option && entry.correctOptionText !== option.text) problems.push(`${entry.itemId}: key option text does not match the bank`);
  }
  return [...new Set(problems)];
}

function parseAttemptId(id) {
  const match = /^(.+)_(preTest|postTest)_([1-9]\d*)$/.exec(id);
  return match ? { uid: match[1], stage: match[2], n: Number(match[3]) } : null;
}

/** Structural problems of one attempt against the bank (empty = valid). */
function attemptStructureProblems(attempt, participant, bankByBand) {
  const problems = [];
  if (attempt.band !== participant.band) problems.push('band differs from the participant record');
  if (attempt.instrumentVersion !== participant.instrumentVersion) problems.push('instrumentVersion differs from the participant record');
  const items = bankByBand.get(attempt.band);
  if (!items) return [...problems, 'unknown band'];

  const order = attempt.itemOrder;
  if (!Array.isArray(order) || order.length !== ITEMS_PER_BAND || new Set(order).size !== ITEMS_PER_BAND || !order.every((id) => items.has(id))) {
    return [...problems, 'itemOrder is not exactly the band\'s 20 items'];
  }
  const optionOrder = attempt.optionOrder || {};
  if (Object.keys(optionOrder).length !== ITEMS_PER_BAND) problems.push('optionOrder does not have one entry per item');
  for (const id of order) {
    const ids = items.get(id).options.map((o) => o.id);
    const shown = optionOrder[id];
    if (!Array.isArray(shown) || shown.length !== 4 || new Set(shown).size !== 4 || !shown.every((o) => ids.includes(o))) {
      problems.push(`${id}: optionOrder is not a permutation of its 4 options`);
    }
  }
  for (const [itemId, r] of Object.entries(attempt.responses || {})) {
    if (!order.includes(itemId)) {
      problems.push(`${itemId}: answer for an item not in this attempt`);
      continue;
    }
    const item = items.get(itemId);
    if (!r || typeof r !== 'object') {
      problems.push(`${itemId}: malformed answer`);
    } else if (r.optionId === DONT_KNOW_ID) {
      if (r.displayPosition !== 5 || r.optionText !== DONT_KNOW_TEXT) problems.push(`${itemId}: malformed "tidak tahu" answer`);
    } else {
      const option = item.options.find((o) => o.id === r.optionId);
      if (!option) problems.push(`${itemId}: answer is not one of the item's options`);
      else {
        if (r.optionText !== option.text) problems.push(`${itemId}: answer text does not match the bank`);
        const shown = optionOrder[itemId];
        if (!Array.isArray(shown) || shown.indexOf(r.optionId) + 1 !== r.displayPosition) {
          problems.push(`${itemId}: displayPosition does not match the stored option order`);
        }
      }
    }
  }
  return problems;
}

function codeFor(response, keyOptionId) {
  if (!response) return 'K';
  if (response.optionId === DONT_KNOW_ID) return 'T';
  return response.optionId === keyOptionId ? 'B' : 'S';
}

function round4(x) {
  return Number.isFinite(x) ? x.toFixed(4) : '';
}

/**
 * Scores everything. [participants]: `[{ uid, data }]`; [attempts]:
 * `[{ id, data }]`; [cohort] optionally limits to one cohort.
 */
function buildExport({ bank, key, participants, attempts, cohort = null }) {
  const keyByItem = new Map(key.entries.map((e) => [e.itemId, e.correctOptionId]));
  const bankByBand = new Map(BANDS.map((band) => [band, new Map(bank.items.filter((i) => i.band === band).map((i) => [i.id, i]))]));
  const problems = []; // operational: may name UIDs / attempt IDs
  const exclusions = []; // analysis: researchId only
  const attemptRows = [];
  const itemRows = [];
  const pairedRows = [];
  const voidRows = [];
  const identifiers = [];

  // Participants: one record per uid, unique researchId.
  const byResearchId = new Map();
  for (const { uid, data } of participants) {
    const list = byResearchId.get(data.researchId) || [];
    list.push(uid);
    byResearchId.set(data.researchId, list);
  }
  const people = [];
  for (const { uid, data } of participants) {
    if (cohort && data.cohort !== cohort) continue;
    if (!data.researchId || byResearchId.get(data.researchId).length > 1) {
      problems.push({ category: 'duplicate_or_missing_research_id', reference: uid, detail: 'participant left out of every analysis file' });
      continue;
    }
    if (!BANDS.includes(data.band)) {
      problems.push({ category: 'invalid_participant', reference: uid, detail: 'unknown band' });
      continue;
    }
    if (data.instrumentVersion !== bank.instrumentVersion) {
      problems.push({
        category: 'instrument_version_mismatch',
        reference: uid,
        detail: `participant uses "${data.instrumentVersion}", this export scores "${bank.instrumentVersion}"; left out`,
      });
      continue;
    }
    people.push({ uid, p: data });
    identifiers.push({ research_id: data.researchId, uid });
  }
  const known = new Set(participants.map((p) => p.uid));

  // Attempts grouped by owner and stage.
  const grouped = new Map();
  for (const { id, data } of attempts) {
    const parsed = parseAttemptId(id);
    if (!parsed || data.studentId !== parsed.uid || data.stage !== parsed.stage || data.attemptNumber !== parsed.n) {
      problems.push({ category: 'attempt_id_mismatch', reference: id, detail: 'document ID does not match its owner/stage/number; not scored' });
      continue;
    }
    if (!known.has(parsed.uid)) {
      problems.push({ category: 'orphan_attempt', reference: id, detail: 'no participant record; not scored' });
      continue;
    }
    const k = `${parsed.uid}|${parsed.stage}`;
    if (!grouped.has(k)) grouped.set(k, []);
    grouped.get(k).push({ id, n: parsed.n, a: data });
  }

  for (const { uid, p } of people) {
    const rid = p.researchId;
    const selected = {};
    for (const stage of STAGES) {
      const list = (grouped.get(`${uid}|${stage}`) || []).sort((x, y) => x.n - y.n);
      const authorized = p.authorizedAttempts ? p.authorizedAttempts[stage] : undefined;
      const exclude = (reason, detail = '') => exclusions.push({ research_id: rid, band: p.band, cohort: p.cohort, stage, reason, detail });
      const live = list.filter((x) => x.a.status !== 'voided');
      let chosen = null;
      let reason = null;

      if (!Number.isInteger(authorized) || authorized < 0) reason = ['invalid_authorization_state', 'authorizedAttempts is malformed'];
      else if (list.some((x) => x.n > authorized)) reason = ['invalid_authorization_state', 'an attempt exists beyond the authorized number'];
      else if (live.length > 1) reason = ['conflicting_attempts', `${live.length} non-voided attempts (${live.map((x) => `#${x.n}`).join(', ')}); none chosen`];
      else if (live.length === 0) reason = [list.length ? 'only_voided_attempts' : 'no_attempt', ''];
      else if (live[0].n !== authorized) reason = ['attempt_not_currently_authorized', `attempt #${live[0].n}, authorized #${authorized}`];
      else chosen = live[0];

      for (const x of list) {
        const structure = x.a.status === 'voided' ? [] : attemptStructureProblems(x.a, p, bankByBand);
        const responses = x.a.responses || {};
        const codes = Array.isArray(x.a.itemOrder) ? x.a.itemOrder.map((id) => codeFor(responses[id], keyByItem.get(id))) : [];
        const count = (c) => codes.filter((v) => v === c).length;
        let included = false;
        let rowReason = '';
        if (x.a.status === 'voided') {
          rowReason = 'voided';
          voidRows.push({ research_id: rid, uid, stage, attempt_number: x.n, void_reason: x.a.voidReason || '', voided_at: x.a.voidedAt || '' });
        } else if (x !== chosen) {
          rowReason = reason ? reason[0] : 'not_selected';
        } else if (structure.length) {
          rowReason = 'invalid_record';
          reason = ['invalid_record', structure.join('; ')];
          chosen = null;
        } else if (x.a.status === 'in_progress') {
          rowReason = 'incomplete';
          reason = ['incomplete', `${Object.keys(responses).length}/20 answered`];
          chosen = null;
        } else if (x.a.status !== 'completed') {
          rowReason = 'invalid_record';
          reason = ['invalid_record', `unknown status "${x.a.status}"`];
          chosen = null;
        } else if (Object.keys(responses).length !== ITEMS_PER_BAND || count('K') !== 0) {
          rowReason = 'invalid_record';
          reason = ['invalid_record', 'completed without all 20 answers'];
          chosen = null;
        } else {
          included = true;
        }
        const score = included ? count('B') : null;
        attemptRows.push({
          research_id: rid,
          band: p.band,
          cohort: p.cohort,
          instrument_version: x.a.instrumentVersion,
          stage,
          attempt_number: x.n,
          status: x.a.status,
          included_in_scoring: included ? 'yes' : 'no',
          exclusion_reason: rowReason,
          score: score === null ? '' : score,
          percent: score === null ? '' : (score / ITEMS_PER_BAND) * 100,
          count_B: x.a.status === 'voided' || structure.length ? '' : count('B'),
          count_S: x.a.status === 'voided' || structure.length ? '' : count('S'),
          count_T: x.a.status === 'voided' || structure.length ? '' : count('T'),
          count_K: x.a.status === 'voided' || structure.length ? '' : count('K'),
          started_at: x.a.startedAt || '',
          completed_at: x.a.completedAt || '',
        });
        if (included) {
          const items = bankByBand.get(p.band);
          x.a.itemOrder.forEach((itemId, index) => {
            const r = responses[itemId];
            const item = items.get(itemId);
            const code = codeFor(r, keyByItem.get(itemId));
            itemRows.push({
              research_id: rid,
              band: p.band,
              stage,
              attempt_number: x.n,
              display_order: index + 1,
              item_id: itemId,
              item_number: item.number,
              word: item.word,
              selected_option_id: r.optionId,
              selected_option_text: r.optionText,
              display_position: r.displayPosition,
              code,
              score: code === 'B' ? 1 : 0,
              answered_at: r.answeredAt || '',
            });
          });
          selected[stage] = { score, dontKnow: count('T'), attempt: x };
        }
      }
      if (!selected[stage]) exclude(reason ? reason[0] : 'no_attempt', reason ? reason[1] : '');
    }

    const pre = selected.preTest;
    const post = selected.postTest;
    if (pre && post && post.attempt.a.startedAt && pre.attempt.a.completedAt && post.attempt.a.startedAt < pre.attempt.a.completedAt) {
      exclusions.push({ research_id: rid, band: p.band, cohort: p.cohort, stage: 'pair', reason: 'posttest_before_pretest', detail: 'posttest started before the pretest was completed' });
      continue;
    }
    if (pre && post) {
      const gain = post.score - pre.score;
      pairedRows.push({
        research_id: rid,
        band: p.band,
        cohort: p.cohort,
        pre_score: pre.score,
        post_score: post.score,
        gain,
        pre_percent: (pre.score / ITEMS_PER_BAND) * 100,
        post_percent: (post.score / ITEMS_PER_BAND) * 100,
        n_gain: pre.score === ITEMS_PER_BAND ? '' : round4(gain / (ITEMS_PER_BAND - pre.score)),
        n_gain_note: pre.score === ITEMS_PER_BAND ? 'not computed: pre = 20' : '',
        pre_dont_know: pre.dontKnow,
        post_dont_know: post.dontKnow,
      });
    } else {
      const missing = [!pre && 'pretest', !post && 'posttest'].filter(Boolean).join(' and ');
      exclusions.push({ research_id: rid, band: p.band, cohort: p.cohort, stage: 'pair', reason: 'excluded_from_paired_analysis', detail: `no valid completed ${missing}` });
    }
  }

  return {
    attemptRows,
    itemRows,
    pairedRows,
    exclusions,
    problems,
    voidRows,
    identifiers,
    summary: {
      participants: people.length,
      pairedIncluded: pairedRows.length,
      pairedExcluded: people.length - pairedRows.length,
      nGainNotComputed: pairedRows.filter((r) => r.n_gain === '').length,
      attempts: attemptRows.length,
      dataProblems: problems.length,
    },
  };
}

module.exports = { validateKey, buildExport, attemptStructureProblems, parseAttemptId, codeFor };
