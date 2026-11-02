'use strict';

/**
 * Strict parser for the researcher's enrolment CSV.
 *
 * Header, exactly and in this order — one of:
 *   `email,researchId,cohort`   (the student's sign-in e-mail; the tooling
 *                                looks the UID up in Firebase Auth)
 *   `uid,researchId,cohort`     (the student's Firebase Auth UID)
 * - email:      a plain e-mail address (no quotes, commas or spaces).
 * - uid:        letters, digits, `_`, `-`; 6–128.
 * - researchId: the pseudonymous study ID used in every export
 *               (letters, digits, `_`, `-`; 2–32; starts with a letter or
 *               digit, so a spreadsheet never reads it as a formula).
 *               Never a name or e-mail.
 * - cohort:     study, pilot or test.
 *
 * There is no band column: every research band comes from the participant's
 * research Placement Test (`DATA_MODEL.md` §6b). Anything else is rejected:
 * missing or extra columns, quotes, empty fields, duplicate accounts or
 * research IDs, unknown cohorts. The whole file is refused if any row is
 * invalid; problems name the line number only, never echo a field value
 * that could be personal data.
 */

const ID_COLUMNS = ['email', 'uid'];
const HEADERS = ID_COLUMNS.map((id) => [id, 'researchId', 'cohort']);
const COHORTS = ['study', 'pilot', 'test'];
const UID_RE = /^[A-Za-z0-9_-]{6,128}$/;
const EMAIL_RE = /^[^\s@,"]{1,64}@[^\s@,"]{1,253}\.[^\s@,".]{2,63}$/;
const RESEARCH_ID_RE = /^[A-Za-z0-9][A-Za-z0-9_-]{1,31}$/;

function parseParticipantsCsv(text) {
  const problems = [];
  const rows = [];
  const lines = String(text).replace(/^﻿/, '').split(/\r?\n/);
  while (lines.length && lines[lines.length - 1].trim() === '') lines.pop();

  if (!lines.length) return { rows, problems: ['the file is empty'] };
  const header = lines[0].split(',').map((h) => h.trim()).join(',');
  const idColumn = ID_COLUMNS.find((_, i) => HEADERS[i].join(',') === header);
  if (!idColumn) {
    return { rows, problems: [`line 1: the header must be exactly "${HEADERS[0].join(',')}" or "${HEADERS[1].join(',')}" (no band column: bands come from the research Placement Test)`] };
  }

  const seenIds = new Set();
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
    if (cells.length !== 3) {
      problems.push(`line ${lineNo}: expected 3 columns, found ${cells.length}`);
      continue;
    }
    const [rawId, researchId, cohort] = cells;
    const id = idColumn === 'email' ? rawId.toLowerCase() : rawId;
    const before = problems.length;
    if (idColumn === 'email' ? !EMAIL_RE.test(id) : !UID_RE.test(id)) problems.push(`line ${lineNo}: invalid ${idColumn}`);
    if (!RESEARCH_ID_RE.test(researchId)) problems.push(`line ${lineNo}: invalid researchId`);
    if (!COHORTS.includes(cohort)) problems.push(`line ${lineNo}: cohort must be one of ${COHORTS.join(', ')}`);
    if (seenIds.has(id)) problems.push(`line ${lineNo}: duplicate ${idColumn}`);
    if (seenResearchIds.has(researchId)) problems.push(`line ${lineNo}: duplicate researchId`);
    seenIds.add(id);
    seenResearchIds.add(researchId);
    if (problems.length === before) rows.push({ line: lineNo, [idColumn]: id, researchId, cohort });
  }
  if (!problems.length && !rows.length) problems.push('the file has no participant rows');
  return { rows: problems.length ? [] : rows, problems };
}

module.exports = { parseParticipantsCsv, HEADERS, COHORTS, UID_RE, EMAIL_RE, RESEARCH_ID_RE };
