'use strict';

/**
 * Guards for the two private outputs (answer key, comparison report),
 * both of which contain correct answers. A path is refused when it:
 * - was not supplied explicitly (no default path exists anywhere);
 * - lacks the required filename suffix (`.private.json` / `.private.md`,
 *   which `.gitignore` also ignores as a second line of defence);
 * - has a parent directory that does not exist (the tool never creates
 *   directories for private files — you choose and create the folder);
 * - lies inside the Vocably repository, inside any Git working tree, or
 *   inside a OneDrive-synchronised folder;
 * - already exists (the tool never overwrites a key or report).
 */

const fs = require('fs');
const path = require('path');

const ONEDRIVE_SEGMENT_RE = /^onedrive(\s*-.*)?$/i;
const ONEDRIVE_ENV_VARS = ['OneDrive', 'OneDriveConsumer', 'OneDriveCommercial'];

function comparable(p, platform) {
  const normalized = path.resolve(p);
  return platform === 'win32' ? normalized.toLowerCase() : normalized;
}

function isInside(child, parent, platform) {
  const rel = path.relative(comparable(parent, platform), comparable(child, platform));
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

function realpathOrSelf(p) {
  try {
    return fs.realpathSync.native(p);
  } catch {
    return path.resolve(p);
  }
}

function findGitWorkTree(startDir) {
  let dir = startDir;
  for (;;) {
    if (fs.existsSync(path.join(dir, '.git'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

/**
 * Returns `{ ok, resolved, reasons }` for a proposed private output path.
 * [env] and [platform] are injectable for tests.
 */
function assessPrivateOutputPath(
  target,
  { repoRoot, requiredSuffix, env = process.env, platform = process.platform }
) {
  const reasons = [];
  if (!target || !String(target).trim()) {
    return { ok: false, resolved: null, reasons: ['no output path was supplied'] };
  }

  const resolved = path.resolve(String(target));
  if (!resolved.toLowerCase().endsWith(requiredSuffix)) {
    reasons.push(`the filename must end with "${requiredSuffix}"`);
  }

  const parent = path.dirname(resolved);
  const parentExists = fs.existsSync(parent) && fs.statSync(parent).isDirectory();
  if (!parentExists) {
    reasons.push(`the folder ${parent} does not exist (create it yourself first)`);
  }
  const realTarget = path.join(parentExists ? realpathOrSelf(parent) : parent, path.basename(resolved));
  const candidates = [resolved, realTarget];

  const repoRoots = [repoRoot, realpathOrSelf(repoRoot)];
  if (candidates.some((c) => repoRoots.some((r) => isInside(c, r, platform)))) {
    reasons.push('it is inside the Vocably repository');
  }

  const oneDriveRoots = ONEDRIVE_ENV_VARS.map((name) => env[name]).filter((v) => v && String(v).trim());
  const inOneDrive =
    candidates.some((c) => oneDriveRoots.some((r) => isInside(c, r, platform))) ||
    candidates.some((c) => path.dirname(c).split(/[\\/]/).some((seg) => ONEDRIVE_SEGMENT_RE.test(seg)));
  if (inOneDrive) reasons.push('it is inside a OneDrive-synchronised folder');

  if (parentExists) {
    const workTree = findGitWorkTree(realpathOrSelf(parent));
    if (workTree) reasons.push(`it is inside a Git working tree (${workTree})`);
  }

  if (fs.existsSync(resolved)) reasons.push('the file already exists (refusing to overwrite)');

  return { ok: reasons.length === 0, resolved, reasons };
}

/** Writes [contents] only if [filePath] does not exist yet (`wx`), owner-only where supported. */
function writeNewPrivateFile(filePath, contents) {
  fs.writeFileSync(filePath, contents, { flag: 'wx', mode: 0o600 });
}

module.exports = { assessPrivateOutputPath, writeNewPrivateFile };
