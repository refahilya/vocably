'use strict';

/**
 * Strict parser for the researcher's enrolment CSV.
 *
 * Header, exactly and in this order: `uid,researchId,band,cohort`
 * - uid:        the student's Firebase Auth UID (letters, digits, `_`, `-`; 6–128).
 * - researchId: the pseudonymous study ID used in every export
 *               (letters, digits, `_`, `-`; 2–32; starts with a letter or
 *               digit, so a spreadsheet never reads it as a formula).
 *               Never a name or e-mail.
 * - band:       A2, B1, B2 or C1 — assigned by the researcher.
 * - cohort:     study, pilot or test.
 *
 * Anything else is rejected: missing or extra columns, quotes, empty
 * fields, duplicate UIDs or research IDs, unknown bands or cohorts. The
 * whole file is refused if any row is invalid; problems name the line
 * number only, never echo a field value that could be personal data.
 */

const { BANDS } = require('../constants');

const HEADER = ['uid', 'researchId', 'band', 'cohort'];
const COHORTS = ['study', 'pilot', 'test'];
const UID_RE = /^[A-Za-z0-9_-]{6,128}$/;
const RESEARCH_ID_RE = /^[A-Za-z0-9][A-Za-z0-9_-]{1,31}$/;

function parseParticipantsCsv(text) {
  const problems = [];
  const rows = [];
  const lines = String(text).replace(/^\uFEFF/, '').split(/\r?\n/);
  while (lines.length && lines[lines.length - 1].trim() === '') lines.pop();

  if (!lines.length) return { rows, problems: ['the file is empty'] };
  const header = lines[0].split(',').map((h) => h.trim());
  if (header.join(',') !== HEADER.join(',')) {
    return { rows, problems: [`line 1: the header must be exactly "${HEADER.join(',')}"`] };
  }

  const seenUids = new Set();
  const seenResearchIds = new Set();
  for (let i = 1; i < lines.length; i++) {
    const lineNo = i + 1;
    const line = lines[i];
    if (line.trim() === '') {
      problems.push(`line ${lineNo}: empty line`);
      continue;
    }
    if (line.includes('"')) {
      problems.push(`line ${lineNo}: quotes are not supported`);
      continue;
    }
    const cells = line.split(',').map((c) => c.trim());
    if (cells.length !== HEADER.length) {
      problems.push(`line ${lineNo}: expected ${HEADER.length} columns, found ${cells.length}`);
      continue;
    }
    const [uid, researchId, band, cohort] = cells;
    const before = problems.length;
    if (!UID_RE.test(uid)) problems.push(`line ${lineNo}: invalid uid`);
    if (!RESEARCH_ID_RE.test(researchId)) problems.push(`line ${lineNo}: invalid researchId`);
    if (!BANDS.includes(band)) problems.push(`line ${lineNo}: band must be one of ${BANDS.join(', ')}`);
    if (!COHORTS.includes(cohort)) problems.push(`line ${lineNo}: cohort must be one of ${COHORTS.join(', ')}`);
    if (seenUids.has(uid)) problems.push(`line ${lineNo}: duplicate uid`);
    if (seenResearchIds.has(researchId)) problems.push(`line ${lineNo}: duplicate researchId`);
    seenUids.add(uid);
    seenResearchIds.add(researchId);
    if (problems.length === before) rows.push({ line: lineNo, uid, researchId, band, cohort });
  }
  if (!problems.length && !rows.length) problems.push('the file has no participant rows');
  return { rows: problems.length ? [] : rows, problems };
}

module.exports = { parseParticipantsCsv, HEADER, COHORTS, UID_RE, RESEARCH_ID_RE };
