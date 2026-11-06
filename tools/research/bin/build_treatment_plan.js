#!/usr/bin/env node
'use strict';

/**
 * Builds the research treatment plan (`DATA_MODEL.md` §6e) from the
 * committed pretest/posttest bank: per band, its 20 words split into 4
 * sessions of 5, randomized once from a recorded seed.
 *
 *   node bin/build_treatment_plan.js --version t1 [--seed <hex>] [--order "A2=2,1,3,4;B1=1,2,3,4"] [--out <file>]
 *   node bin/build_treatment_plan.js --check <file>
 *
 * - Without --seed a random 32-byte seed is generated and recorded in the
 *   plan, so the allocation can be re-derived and checked later.
 * - --order sets the session order per band (session k uses random group
 *   order[k-1]); the default keeps the random group order.
 * - The output file is never overwritten (default
 *   tools/research/plans/treatment_plan_<version>.json). A different
 *   allocation needs a new version.
 * - --check validates an existing plan against the committed bank and the
 *   app's vocabulary bundles (prints problems only, never the plan).
 */

const fs = require('fs');
const path = require('path');
const { parseArgs, readBank, REPO_ROOT } = require('../lib/admin/cli');
const { BANDS } = require('../lib/constants');
const { buildTreatmentPlan, validateTreatmentPlan, planSha256 } = require('../lib/treatment/plan');

const SPEC = { version: 'string', seed: 'string', order: 'string', out: 'string', check: 'string' };

/** The app's vocabulary bundle words per band (what the student app resolves). */
function readVocabByBand(repoRoot = REPO_ROOT) {
  return Object.fromEntries(
    BANDS.map((band) => {
      const file = path.join(repoRoot, 'assets', 'vocab', `vocab_${band.toLowerCase()}.json`);
      return [band, new Set(JSON.parse(fs.readFileSync(file, 'utf8')).map((entry) => entry.word))];
    })
  );
}

function defaultPlanPath(version) {
  return path.join(__dirname, '..', 'plans', `treatment_plan_${version}.json`);
}

function run(argv, { log = console.log } = {}) {
  const args = parseArgs(argv, SPEC);
  const { bank, bankSha256 } = readBank();
  const vocabByBand = readVocabByBand();

  if (args.check) {
    const plan = JSON.parse(fs.readFileSync(args.check, 'utf8'));
    const problems = validateTreatmentPlan(plan, { bank, bankSha256, vocabByBand });
    if (problems.length) throw new Error(`The plan is not valid:\n- ${problems.join('\n- ')}`);
    log(`Plan OK: ${plan.planVersion}, instrument ${plan.instrumentVersion}, planSha256 ${planSha256(plan)}.`);
    return plan;
  }

  if (!args.version) throw new Error('--version <t1|t2|…> is required');
  const out = path.resolve(args.out || defaultPlanPath(args.version));
  if (fs.existsSync(out)) throw new Error(`Refusing to overwrite ${out}: a plan is built once (use a new --version for a new allocation).`);
  const plan = buildTreatmentPlan({ bank, bankSha256, planVersion: args.version, seed: args.seed, order: args.order });
  const problems = validateTreatmentPlan(plan, { bank, bankSha256, vocabByBand });
  if (problems.length) throw new Error(`The built plan is not valid:\n- ${problems.join('\n- ')}`);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, `${JSON.stringify(plan, null, 2)}\n`, { flag: 'wx' });
  log(`Wrote ${path.relative(REPO_ROOT, out)} (plan ${plan.planVersion}, planSha256 ${planSha256(plan)}).`);
  return plan;
}

if (require.main === module) {
  try {
    run(process.argv.slice(2));
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

module.exports = { run, readVocabByBand, defaultPlanPath };
