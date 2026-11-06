'use strict';

/**
 * The research treatment plan (`lib/treatment/plan.js`, `DATA_MODEL.md`
 * §6e): randomized once from a recorded seed, 4 sessions × 5 words per
 * band, re-derivable, never silently changed. Uses the synthetic fixture
 * bank, plus one check of the committed plan against the committed bank.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const fixtures = require('./researchFixtures');
const { buildTreatmentPlan, validateTreatmentPlan, buildPlanDocs, planSha256, parseOrder } = require('../lib/treatment/plan');
const { BANDS } = require('../lib/constants');

const SEED = 'ab'.repeat(32);
const build = (extra = {}) => buildTreatmentPlan({ bank: fixtures.bank, bankSha256: fixtures.bankSha256, planVersion: 't1', seed: SEED, createdAt: '2026-11-03T00:00:00.000Z', ...extra });
const check = (plan) => validateTreatmentPlan(plan, { bank: fixtures.bank, bankSha256: fixtures.bankSha256 });

describe('treatment plan', () => {
  it('every band: its 20 items exactly once, in 4 sessions of 5', () => {
    const plan = build();
    for (const band of BANDS) {
      const sessions = plan.bands[band].sessions;
      assert.deepEqual(Object.keys(sessions), ['1', '2', '3', '4']);
      const ids = Object.values(sessions).flat().map((e) => e.itemId);
      assert.equal(ids.length, 20);
      assert.equal(new Set(ids).size, 20);
      assert.deepEqual([...ids].sort(), fixtures.bank.items.filter((i) => i.band === band).map((i) => i.id).sort());
      for (const list of Object.values(sessions)) assert.equal(list.length, 5);
    }
    assert.deepEqual(check(plan), []);
  });

  it('the same seed gives the same allocation; another seed a different one; the seed is recorded', () => {
    assert.equal(planSha256(build()), planSha256(build()));
    assert.notEqual(planSha256(build()), planSha256(build({ seed: 'cd'.repeat(32) })));
    assert.equal(build().randomization.seed, SEED);
    const random = buildTreatmentPlan({ bank: fixtures.bank, bankSha256: fixtures.bankSha256, planVersion: 't1' });
    assert.match(random.randomization.seed, /^[0-9a-f]{64}$/);
    assert.deepEqual(check(random), []);
  });

  it('the session order per band reorders the same groups (one order per band, not per student)', () => {
    const base = build();
    const reordered = build({ order: 'B1=2,1,4,3' });
    assert.deepEqual(reordered.bands.B1.sessions['1'], base.bands.B1.sessions['2']);
    assert.deepEqual(reordered.bands.B1.sessions['3'], base.bands.B1.sessions['4']);
    assert.deepEqual(reordered.bands.A2.sessions, base.bands.A2.sessions);
    assert.deepEqual(check(reordered), []);
    assert.throws(() => parseOrder('B1=1,1,2,3'), /permutation/);
    assert.throws(() => parseOrder('X9=1,2,3,4'), /unknown band/);
  });

  it('a tampered plan is refused (moved word, other bank, allocation not from the seed)', () => {
    const moved = build();
    const a = moved.bands.A2.sessions['1'].pop();
    moved.bands.A2.sessions['2'].push(a);
    assert.ok(check(moved).some((p) => /needs 5 words/.test(p)));

    const swapped = build();
    const [x, y] = [swapped.bands.A2.sessions['1'][0], swapped.bands.A2.sessions['2'][0]];
    swapped.bands.A2.sessions['1'][0] = y;
    swapped.bands.A2.sessions['2'][0] = x;
    assert.ok(check(swapped).some((p) => /does not follow from the recorded seed/.test(p)));

    assert.ok(check({ ...build(), bankSha256: '0'.repeat(64) }).some((p) => /bankSha256/.test(p)));
    assert.throws(() => build({ planVersion: 'v1' }), /planVersion/);
    assert.throws(() => build({ seed: 'xyz' }), /seed/);
  });

  it('Firestore documents carry only the words and item IDs per session', () => {
    const docs = buildPlanDocs(build());
    assert.deepEqual(docs.map((d) => d.id), ['t1_A2', 't1_B1', 't1_B2', 't1_C1']);
    const a2 = docs[0].data;
    assert.deepEqual(Object.keys(a2).sort(), ['band', 'bankSha256', 'instrumentVersion', 'itemIds', 'planSha256', 'planVersion', 'sessions']);
    assert.equal(a2.sessions['1'].length, 5);
    assert.equal(typeof a2.sessions['1'][0], 'string');
  });

  const readPlan = (version) =>
    JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'plans', `treatment_plan_${version}.json`), 'utf8'));

  it('the committed plan t2 matches the active (v2) bank and the app vocabulary bundles', () => {
    const { readBank } = require('../lib/admin/cli');
    const { readVocabByBand } = require('../bin/build_treatment_plan');
    const { bank, bankSha256 } = readBank();
    const plan = readPlan('t2');
    assert.equal(plan.instrumentVersion, bank.instrumentVersion);
    assert.deepEqual(validateTreatmentPlan(plan, { bank, bankSha256, vocabByBand: readVocabByBand() }), []);
  });

  it('the archived plan t1 still matches the v1 bank it was built from', () => {
    const { readVocabByBand } = require('../bin/build_treatment_plan');
    const raw = fs.readFileSync(path.join(__dirname, '..', '..', '..', 'assets', 'research', 'instrument_v1.json'), 'utf8');
    const bankSha256 = require('crypto').createHash('sha256').update(raw).digest('hex');
    assert.deepEqual(validateTreatmentPlan(readPlan('t1'), { bank: JSON.parse(raw), bankSha256, vocabByBand: readVocabByBand() }), []);
  });

  it('t2 keeps the t1 allocation: same seed, same session order, same words per session', () => {
    const t1 = readPlan('t1');
    const t2 = readPlan('t2');
    assert.equal(t2.randomization.seed, t1.randomization.seed);
    assert.deepEqual(t2.randomization.sessionOrder, t1.randomization.sessionOrder);
    assert.deepEqual(t2.bands, t1.bands);
  });
});
