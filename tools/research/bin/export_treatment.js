#!/usr/bin/env node
'use strict';

/**
 * Treatment-implementation (fidelity) export (trusted researcher tooling;
 * read-only). `DATA_MODEL.md` §6e.
 *
 *   node bin/export_treatment.js --out-dir <folder>
 *        (--emulator | --production --project <id> --confirm-project <id>) [--cohort study|pilot|test]
 *
 * - The output folder must already exist, outside this repository, any Git
 *   working tree and OneDrive. Files are created new; never overwritten.
 * - Reads participants, the active treatment plan, the official session
 *   sets, the participants' learning sessions, the completion records and
 *   the pretest/posttest timestamps. Co-write text is read but never written:
 *   only counts leave Firestore. Nothing is written to Firestore.
 */

const path = require('path');
const fs = require('fs');
const { resolveTarget, initAdmin, TargetError } = require('../lib/admin/target');
const { parseArgs, REPO_ROOT } = require('../lib/admin/cli');
const { assessPrivateOutputDir, writeNewPrivateFile } = require('../lib/safeOutput');
const { buildTreatmentExport, TREATMENT_COLUMNS } = require('../lib/export/treatment');
const { toCsv, plain } = require('../lib/export/files');

const SPEC = { outDir: 'string', cohort: 'string', emulator: 'boolean', production: 'boolean', project: 'string', confirmProject: 'string' };
const BANDS = ['A2', 'B1', 'B2', 'C1'];

async function readAll(db) {
  const study = (await db.collection('researchStudy').doc('current').get()).data() || {};
  const planVersion = (study.treatment || {}).planVersion || null;
  const participants = (await db.collection('researchParticipants').get()).docs.map((d) => ({ uid: d.id, data: plain(d.data()) }));
  const plans = planVersion
    ? (await db.collection('researchTreatmentPlan').where('planVersion', '==', planVersion).get()).docs.map((d) => plain(d.data()))
    : [];
  const sets = (await db.collection('targetWordSets').where('research.band', 'in', BANDS).get()).docs.map((d) => ({ id: d.id, data: plain(d.data()) }));
  const records = (await db.collection('researchTreatment').get()).docs.map((d) => ({ uid: d.id, data: plain(d.data()) }));
  const sessions = [];
  for (const p of participants) {
    const q = await db.collection('learningSessions').where('studentId', '==', p.uid).get();
    sessions.push(...q.docs.map((d) => ({ id: d.id, data: plain(d.data()) })));
  }
  // Official sessions of accounts that are not participants (a data problem).
  const official = await db.collection('learningSessions').where('researchSession', 'in', [1, 2, 3, 4]).get();
  const seen = new Set(sessions.map((s) => s.id));
  for (const d of official.docs) if (!seen.has(d.id)) sessions.push({ id: d.id, data: plain(d.data()) });
  const attempts = (await db.collection('researchAssessmentResults').get()).docs.map((d) => {
    const a = d.data();
    // Only status and timestamps are used; answers stay behind.
    return { id: d.id, data: plain({ status: a.status, startedAt: a.startedAt || null, completedAt: a.completedAt || null }) };
  });
  return { study, planVersion, participants, plans, sets, records, sessions, attempts };
}

async function run(argv, { log = console.log } = {}) {
  const args = parseArgs(argv, SPEC);
  const out = assessPrivateOutputDir(args.outDir, { repoRoot: REPO_ROOT });
  if (!out.ok) throw new Error(`Refusing the output folder: ${out.reasons.join('; ')}`);
  const names = [...Object.keys(TREATMENT_COLUMNS), 'treatment_manifest.json'];
  const clashes = names.filter((n) => fs.existsSync(path.join(out.resolved, n)));
  if (clashes.length) throw new Error(`Refusing to overwrite existing files: ${clashes.join(', ')}`);

  const target = resolveTarget(args, { repoRoot: REPO_ROOT });
  const { app, db } = initAdmin(target);
  let data;
  try {
    data = await readAll(db);
  } finally {
    await app.delete();
  }
  const result = buildTreatmentExport({ ...data, cohort: args.cohort || null });
  const rowsFor = {
    'treatment_sessions.csv': result.sessionRows,
    'treatment_attempts.csv': result.attemptRows,
    'treatment_exposure.csv': result.exposureRows,
    'treatment_summary.csv': result.summaryRows,
    'treatment_operational_problems.csv': result.problems,
  };
  for (const [name, cols] of Object.entries(TREATMENT_COLUMNS)) writeNewPrivateFile(path.join(out.resolved, name), toCsv(cols, rowsFor[name]));
  writeNewPrivateFile(
    path.join(out.resolved, 'treatment_manifest.json'),
    `${JSON.stringify({
      generatedAt: new Date().toISOString(),
      source: { mode: target.mode, projectId: target.projectId },
      planVersion: data.planVersion,
      makeupDeadlineDays: (data.study.treatment || {}).makeupDeadlineDays ?? null,
      cohortFilter: args.cohort || null,
      definitions: {
        completed: 'official session recorded in researchTreatment (learning session phase selesai, cloze for every word, non-empty co-write)',
        completed_after_window: 'completed after the session set closed (it may only START inside the window)',
        marked_present_regular: 'the researcher marked the student present in a regular opening of that session',
        exposure_period: 'before_pretest = started before the pretest was completed; during_treatment = between pretest completion and posttest start; after_posttest',
        location: 'not detectable by the app: supervision = researcher-opened, time-boxed window for students marked present + the attendance sheet',
      },
      counts: Object.fromEntries(Object.entries(rowsFor).map(([k, v]) => [k, v.length])),
      columns: TREATMENT_COLUMNS,
    }, null, 2)}\n`
  );
  log(`Treatment export written to ${out.resolved}: ${result.summaryRows.length} participant(s), ${result.problems.length} problem(s).`);
  return result;
}

if (require.main === module) {
  run(process.argv.slice(2)).catch((error) => {
    console.error(error instanceof TargetError ? error.message : `Error: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { run, readAll };
