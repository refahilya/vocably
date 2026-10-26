'use strict';

/**
 * Synthetic research data for the export/scoring and admin tests.
 *
 * The "key" here is FABRICATED (option index (number − 1) mod 4 of each
 * item) — it is not the real answer key, which tests never read. Answers
 * are generated from it so scores are known exactly.
 */

const { readBank } = require('../lib/admin/cli');
const { DONT_KNOW_ID, DONT_KNOW_TEXT } = require('../lib/constants');

const { bank, bankJson, bankSha256 } = readBank();
const itemsOf = (band) => bank.items.filter((item) => item.band === band);

function syntheticKey(overrides = {}) {
  return {
    warning: 'synthetic test key',
    instrumentId: bank.instrumentId,
    instrumentVersion: bank.instrumentVersion,
    bankSha256,
    entries: bank.items.map((item) => {
      const option = item.options[(item.number - 1) % 4];
      return { itemId: item.id, band: item.band, word: item.word, correctOptionId: option.id, referenceLetter: 'x', correctOptionText: option.text };
    }),
    ...overrides,
  };
}

const keyOption = (item) => item.options[(item.number - 1) % 4];
const wrongOption = (item) => item.options[item.number % 4];

/** Reversed item order, options rotated by one (deterministic stand-in for a shuffle). */
function orderFor(band) {
  const items = itemsOf(band).slice().reverse();
  return {
    itemOrder: items.map((i) => i.id),
    optionOrder: Object.fromEntries(items.map((i) => {
      const ids = i.options.map((o) => o.id);
      return [i.id, [...ids.slice(1), ids[0]]];
    })),
  };
}

function response(item, optionOrder, kind) {
  if (kind === 'T') return { optionId: DONT_KNOW_ID, optionText: DONT_KNOW_TEXT, displayPosition: 5, answeredAt: '2026-10-25T01:00:00.000Z' };
  const option = kind === 'B' ? keyOption(item) : wrongOption(item);
  return { optionId: option.id, optionText: option.text, displayPosition: optionOrder[item.id].indexOf(option.id) + 1, answeredAt: '2026-10-25T01:00:00.000Z' };
}

/**
 * An attempt document whose answers are, in item order: [correct] B, then
 * [dontKnow] T, then S for the rest up to [answered] items (default 20).
 */
function attempt({ uid, stage = 'preTest', n = 1, band = 'A2', status = 'completed', correct = 0, dontKnow = 0, answered = 20, startedAt = '2026-10-20T01:00:00.000Z', completedAt, extra = {} }) {
  const { itemOrder, optionOrder } = orderFor(band);
  const byId = new Map(itemsOf(band).map((i) => [i.id, i]));
  const responses = {};
  itemOrder.slice(0, answered).forEach((id, index) => {
    const kind = index < correct ? 'B' : index < correct + dontKnow ? 'T' : 'S';
    responses[id] = response(byId.get(id), optionOrder, kind);
  });
  return {
    id: `${uid}_${stage}_${n}`,
    data: {
      studentId: uid,
      stage,
      attemptNumber: n,
      band,
      instrumentVersion: 'v1',
      itemOrder,
      optionOrder,
      responses,
      lastAnsweredItemId: answered ? itemOrder[answered - 1] : null,
      status,
      startedAt,
      updatedAt: startedAt,
      completedAt: status === 'completed' ? completedAt || startedAt.replace('01:00', '02:00') : null,
      ...extra,
    },
  };
}

function participant({ uid, researchId = `R-${uid}`, band = 'A2', pre = 1, post = 1, cohort = 'study' }) {
  return {
    uid,
    data: { researchId, band, bandSource: 'researcher_assigned', instrumentVersion: 'v1', authorizedAttempts: { preTest: pre, postTest: post }, cohort },
  };
}

module.exports = { bank, bankJson, bankSha256, itemsOf, syntheticKey, keyOption, wrongOption, orderFor, attempt, participant };
