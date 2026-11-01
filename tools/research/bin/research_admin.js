#!/usr/bin/env node
'use strict';

/**
 * Researcher administration for the research collections.
 *
 *   node bin/research_admin.js <command> (--emulator | --production --project <id> --confirm-project <id>)
 *        [--apply] [--log <file.private.jsonl>] [command options]
 *
 * Pretest/posttest:
 *   seed-instrument                         write researchInstrument/{v1}_{band} from the app-safe bank
 *   enrol      --csv <file>                 create participant records (uid,researchId,band,cohort)
 *   authorize  --stage preTest|postTest (--uid <uid>... | --cohort <c>) [--confirm-session4-completed]
 *              [--acknowledge-placement-policy]
 *   void       --uid <uid> --stage <s> --reason "<text>" [--allow-completed]
 *   retake     --uid <uid> --stage <s> --reason "<text>"
 *   status     [--uid <uid>]               read-only overview
 *
 * Placement Test (PT-V1.1) and study lifecycle:
 *   seed-placement     --key <file.private.json>   placementInstrument/placementKey/placementConfig
 *   learning-placement --open | --close           ordinary (learning-only) placement for every account
 *   study              --status setup|active|closed
 *   stage              --stage placement|preTest|postTest (--open [--close-at <iso>] | --close)
 *   review             --uid <uid> (--open | --close --outcome confirmed|not_confirmed) --reason "<text>"
 *   placement-void     --uid <uid> --category technical|integrity --reason "<text>"
 *   placement-retake   --uid <uid> --reason "<text>"          (after a technical void only)
 *   placement-restore  --uid <uid> --reason "<text>"          (corrects an erroneous void; same attempt)
 *   assign-band        --uid <uid> --band A2|B1|B2|C1 --basis "<text>" --reason "<text>"
 *
 * Safety: nothing is written without --apply (dry run by default). With
 * --production, --apply also needs --log. Nothing is ever deleted or
 * overwritten; see lib/admin/operations.js, lib/admin/placementOperations.js
 * and tools/research/README.md.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { resolveTarget, initAdmin, TargetError } = require('../lib/admin/target');
const { parseArgs, readBank, openAuditLog, REPO_ROOT } = require('../lib/admin/cli');
const { parseParticipantsCsv } = require('../lib/admin/participantsCsv');
const ops = require('../lib/admin/operations');
const pops = require('../lib/admin/placementOperations');
const { PLACEMENT_BANK_ASSET_RELATIVE_PATH } = require('../lib/placement/constants');

const SPEC = {
  emulator: 'boolean',
  production: 'boolean',
  project: 'string',
  confirmProject: 'string',
  apply: 'boolean',
  log: 'string',
  csv: 'string',
  stage: 'string',
  uid: 'list',
  cohort: 'string',
  confirmSession4Completed: 'boolean',
  acknowledgePlacementPolicy: 'boolean',
  reason: 'string',
  allowCompleted: 'boolean',
  key: 'string',
  open: 'boolean',
  close: 'boolean',
  closeAt: 'string',
  status: 'string',
  outcome: 'string',
  category: 'string',
  band: 'string',
  basis: 'string',
};

const SINGLE_UID = ['void', 'retake', 'review', 'placement-void', 'placement-retake', 'placement-restore', 'assign-band'];

/** The committed app-safe placement bank, with LF line endings for a stable hash. */
function readPlacementBank() {
  const raw = fs.readFileSync(path.join(REPO_ROOT, ...PLACEMENT_BANK_ASSET_RELATIVE_PATH.split('/')), 'utf8');
  const bankJson = raw.replace(/\r\n/g, '\n');
  return { bank: JSON.parse(bankJson), bankSha256: crypto.createHash('sha256').update(bankJson).digest('hex') };
}

function printResult(command, result, apply) {
  console.log(`${command}: ${apply ? 'APPLIED' : 'DRY RUN (nothing written; add --apply to write)'}`);
  for (const action of result.actions) console.log(`  ${JSON.stringify(action)}`);
  for (const skip of result.skipped || []) console.log(`  skipped ${JSON.stringify(skip)}`);
}

async function run(argv) {
  const args = parseArgs(argv, SPEC);
  const [command] = args._;
  if (!command || args._.length > 1) throw new Error('Usage: research_admin.js <command> [options] (see the header of this file)');

  const target = resolveTarget(args, { repoRoot: REPO_ROOT });
  if (target.mode === 'production' && args.apply && !args.log) {
    throw new Error('--production --apply needs --log <file.private.jsonl> outside the repository and OneDrive.');
  }
  if (SINGLE_UID.includes(command) && args.uid.length !== 1) {
    throw new Error(`${command} needs exactly one --uid`);
  }
  if (command === 'status' && args.uid.length > 1) throw new Error('status takes at most one --uid');
  const audit = openAuditLog(args.log);
  const { app, db } = initAdmin(target);
  const apply = Boolean(args.apply);
  const base = { target: { mode: target.mode, projectId: target.projectId }, command, apply };
  const uid = args.uid[0];

  try {
    let result;
    switch (command) {
      case 'seed-instrument': {
        const { bank, bankJson } = readBank();
        result = await ops.seedInstrument(db, { bank, bankJson, apply });
        break;
      }
      case 'enrol': {
        if (!args.csv) throw new Error('enrol needs --csv <file>');
        const { rows, problems } = parseParticipantsCsv(fs.readFileSync(args.csv, 'utf8'));
        if (problems.length) throw new ops.AdminError(problems);
        result = await ops.enrolParticipants(db, { rows, apply });
        break;
      }
      case 'authorize':
        result = await ops.authorizeStage(db, {
          uids: args.uid,
          cohort: args.cohort,
          stage: args.stage,
          confirmSession4: Boolean(args.confirmSession4Completed),
          acknowledgePlacementPolicy: Boolean(args.acknowledgePlacementPolicy),
          apply,
        });
        break;
      case 'void':
        result = await ops.voidAttempt(db, { uid, stage: args.stage, reason: args.reason, allowCompleted: Boolean(args.allowCompleted), apply });
        break;
      case 'retake':
        result = await ops.authorizeRetake(db, { uid, stage: args.stage, reason: args.reason, apply });
        break;
      case 'seed-placement': {
        if (!args.key) throw new Error('seed-placement needs --key <file.private.json>');
        const { bank, bankSha256 } = readPlacementBank();
        const keyFile = JSON.parse(fs.readFileSync(args.key, 'utf8'));
        result = await pops.seedPlacement(db, { bank, bankSha256, keyFile, apply });
        break;
      }
      case 'learning-placement':
        if (Boolean(args.open) === Boolean(args.close)) throw new Error('learning-placement needs exactly one of --open or --close');
        result = await pops.setLearningPlacement(db, { open: Boolean(args.open), apply });
        break;
      case 'study':
        result = await pops.setStudyStatus(db, { status: args.status, apply });
        break;
      case 'stage':
        result = await pops.setStageWindow(db, { stage: args.stage, open: args.open, close: args.close, closeAt: args.closeAt, apply });
        break;
      case 'review':
        result = await pops.setReview(db, { uid, open: args.open, close: args.close, outcome: args.outcome, reason: args.reason, apply });
        break;
      case 'placement-void':
        result = await pops.voidPlacement(db, { uid, category: args.category, reason: args.reason, apply });
        break;
      case 'placement-retake':
        result = await pops.retakePlacement(db, { uid, reason: args.reason, apply });
        break;
      case 'placement-restore':
        result = await pops.restorePlacement(db, { uid, reason: args.reason, apply });
        break;
      case 'assign-band':
        result = await pops.assignManualBand(db, { uid, band: args.band, basis: args.basis, reason: args.reason, apply });
        break;
      case 'status': {
        const rows = await ops.stageStatus(db, { uid });
        for (const row of rows) {
          const fmt = (s) =>
            `${s.authorized}${s.attempts.length ? ` [${s.attempts.map((a) => `#${a.n} ${a.status} ${a.answered}/20`).join(', ')}]` : ''}`;
          const placement = row.placement ? ` ${ops.formatPlacementStatus(row.placement)}` : '';
          const review = row.reviewStatus === 'pending' ? ' (review pending)' : '';
          console.log(
            `${row.researchId}\t${row.uid}\t${row.band ?? '-'}\t${row.status}${review}\t${row.cohort}${placement}\tpre=${fmt(row.stages.preTest)}\tpost=${fmt(row.stages.postTest)}`
          );
        }
        console.log(`${rows.length} participant(s)`);
        return;
      }
      default:
        throw new Error(`Unknown command "${command}"`);
    }
    printResult(command, result, apply);
    audit({ ...base, outcome: 'ok', actions: result.actions, skipped: result.skipped || [] });
  } catch (error) {
    audit({ ...base, outcome: 'refused', problems: error.problems || [error.message] });
    throw error;
  } finally {
    await app.delete();
  }
}

if (require.main === module) {
  run(process.argv.slice(2)).catch((error) => {
    console.error(error instanceof TargetError || error instanceof ops.AdminError ? error.message : `Error: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { run };
