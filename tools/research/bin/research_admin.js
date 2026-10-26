#!/usr/bin/env node
'use strict';

/**
 * Researcher administration for the pretest/posttest collections.
 *
 *   node bin/research_admin.js <command> (--emulator | --production --project <id> --confirm-project <id>)
 *        [--apply] [--log <file.private.jsonl>] [command options]
 *
 * Commands:
 *   seed-instrument                         write researchInstrument/{v1}_{band} from the app-safe bank
 *   enrol      --csv <file>                 create participant records (uid,researchId,band,cohort)
 *   authorize  --stage preTest|postTest (--uid <uid>... | --cohort <c>) [--confirm-session4-completed]
 *   void       --uid <uid> --stage <s> --reason "<text>" [--allow-completed]
 *   retake     --uid <uid> --stage <s> --reason "<text>"
 *   status     [--uid <uid>]               read-only overview
 *
 * Safety: nothing is written without --apply (dry run by default). With
 * --production, --apply also needs --log. Nothing is ever deleted or
 * overwritten; see lib/admin/operations.js and tools/research/README.md.
 */

const fs = require('fs');
const { resolveTarget, initAdmin, TargetError } = require('../lib/admin/target');
const { parseArgs, readBank, openAuditLog, REPO_ROOT } = require('../lib/admin/cli');
const { parseParticipantsCsv } = require('../lib/admin/participantsCsv');
const ops = require('../lib/admin/operations');

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
  reason: 'string',
  allowCompleted: 'boolean',
};

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
  if (['void', 'retake'].includes(command) && args.uid.length !== 1) {
    throw new Error(`${command} needs exactly one --uid`);
  }
  if (command === 'status' && args.uid.length > 1) throw new Error('status takes at most one --uid');
  const audit = openAuditLog(args.log);
  const { app, db } = initAdmin(target);
  const apply = Boolean(args.apply);
  const base = { target: { mode: target.mode, projectId: target.projectId }, command, apply };

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
          apply,
        });
        break;
      case 'void':
        result = await ops.voidAttempt(db, {
          uid: args.uid[0],
          stage: args.stage,
          reason: args.reason,
          allowCompleted: Boolean(args.allowCompleted),
          apply,
        });
        break;
      case 'retake':
        result = await ops.authorizeRetake(db, { uid: args.uid[0], stage: args.stage, reason: args.reason, apply });
        break;
      case 'status': {
        const rows = await ops.stageStatus(db, { uid: args.uid[0] });
        for (const row of rows) {
          const fmt = (s) =>
            `${s.authorized}${s.attempts.length ? ` [${s.attempts.map((a) => `#${a.n} ${a.status} ${a.answered}/20`).join(', ')}]` : ''}`;
          console.log(`${row.researchId}\t${row.uid}\t${row.band}\t${row.cohort}\tpre=${fmt(row.stages.preTest)}\tpost=${fmt(row.stages.postTest)}`);
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
