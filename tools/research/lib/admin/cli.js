'use strict';

/**
 * Small helpers shared by the researcher command-line tools: argument
 * parsing (no dependency), bank loading, and the append-only audit log.
 */

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { BANK_ASSET_RELATIVE_PATH } = require('../constants');
const { assessPrivateOutputPath, appendPrivateLine } = require('../safeOutput');

const REPO_ROOT = path.join(__dirname, '..', '..', '..', '..');
const AUDIT_LOG_SUFFIX = '.private.jsonl';

/**
 * Parses `--name value`, `--flag` and repeatable `--name value` options.
 * [spec] maps option name → 'string' | 'boolean' | 'list'. Unknown options
 * are refused.
 */
function parseArgs(argv, spec) {
  const out = { _: [] };
  for (const [name, kind] of Object.entries(spec)) if (kind === 'list') out[name] = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith('--')) {
      out._.push(arg);
      continue;
    }
    const name = arg.slice(2).replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
    const kind = spec[name];
    if (!kind) throw new Error(`Unknown option ${arg}`);
    if (kind === 'boolean') {
      out[name] = true;
      continue;
    }
    const value = argv[++i];
    if (value === undefined || value.startsWith('--')) throw new Error(`${arg} needs a value`);
    if (kind === 'list') out[name].push(value);
    else out[name] = value;
  }
  return out;
}

/** The app-safe bank as committed, with LF line endings for a stable hash. */
function readBank(repoRoot = REPO_ROOT) {
  const raw = fs.readFileSync(path.join(repoRoot, ...BANK_ASSET_RELATIVE_PATH.split('/')), 'utf8');
  const bankJson = raw.replace(/\r\n/g, '\n');
  return {
    bank: JSON.parse(bankJson),
    bankJson,
    bankSha256: crypto.createHash('sha256').update(bankJson).digest('hex'),
  };
}

/**
 * Returns an `audit(entry)` function appending JSON lines to [logPath]
 * (outside the repository, Git working trees and OneDrive; suffix
 * `.private.jsonl`), or a no-op when no path is given.
 */
function openAuditLog(logPath, { repoRoot = REPO_ROOT, env = process.env } = {}) {
  if (!logPath) return () => {};
  const check = assessPrivateOutputPath(logPath, { repoRoot, requiredSuffix: AUDIT_LOG_SUFFIX, env, allowExisting: true });
  if (!check.ok) throw new Error(`Refusing audit log path: ${check.reasons.join('; ')}`);
  return (entry) => appendPrivateLine(check.resolved, JSON.stringify({ at: new Date().toISOString(), ...entry }));
}

module.exports = { parseArgs, readBank, openAuditLog, REPO_ROOT, AUDIT_LOG_SUFFIX };
