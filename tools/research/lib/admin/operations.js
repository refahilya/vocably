'use strict';

/**
 * Trusted researcher operations on the research collections
 * (`DATA_MODEL.md` §6b), run with the Admin SDK (which bypasses the
 * security rules — the rules deliberately give clients no way to do any of
 * this).
 *
 * Every operation:
 * - validates everything first and refuses the whole request on any
 *   problem (AdminError lists them; item/line/uid references only);
 * - returns the planned `actions`, and writes only when `apply` is true;
 * - never deletes and never overwrites an existing participant, bank
 *   document or attempt. Voiding keeps every answer; a retake is a new
 *   attempt number, never a reset;
 * - re-checks the state inside a transaction when it writes, so a
 *   concurrent change makes it fail instead of acting on stale data.
 *
 * Posttest authorization is a researcher-controlled gate: the tooling can
 * check the pretest is completed, but it cannot verify that treatment
 * session 4 happened (no session tracking exists yet). It therefore
 * requires the researcher's explicit `confirmSession4` attestation and
 * says so in the result for the audit log.
 */

const { BANDS, ITEMS_PER_BAND, INSTRUMENT_VERSION } = require('../constants');
const { buildInstrumentDocs } = require('../instrumentDocs');
const { findForbiddenFields } = require('../instrumentBuild');

const PARTICIPANTS = 'researchParticipants';
const ATTEMPTS = 'researchAssessmentResults';
const INSTRUMENT = 'researchInstrument';
const STAGES = ['preTest', 'postTest'];
const MAX_REASON_LENGTH = 300;

class AdminError extends Error {
  constructor(problems) {
    super(`Refused:\n- ${problems.join('\n- ')}`);
    this.problems = problems;
  }
}

function serverTimestamp() {
  return require('firebase-admin/firestore').FieldValue.serverTimestamp();
}

const attemptId = (uid, stage, n) => `${uid}_${stage}_${n}`;

/** Key-order-independent JSON, for comparing stored documents. */
function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value)
      .sort()
      .map((k) => `${JSON.stringify(k)}:${canonical(value[k])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
}

function checkStage(stage) {
  if (!STAGES.includes(stage)) throw new AdminError([`stage must be one of ${STAGES.join(', ')}`]);
}

function checkReason(reason) {
  const text = String(reason || '').trim();
  if (!text) throw new AdminError(['a --reason is required (it is kept with the record and the audit log)']);
  if (text.length > MAX_REASON_LENGTH || /[\r\n]/.test(text)) {
    throw new AdminError([`--reason must be a single line of at most ${MAX_REASON_LENGTH} characters`]);
  }
  return text;
}

function bankProblems(bank) {
  const problems = [];
  if (bank.instrumentVersion !== INSTRUMENT_VERSION) problems.push('unexpected instrumentVersion');
  if (JSON.stringify(bank.bands) !== JSON.stringify(BANDS)) problems.push('unexpected bands');
  for (const band of BANDS) {
    const items = (bank.items || []).filter((item) => item.band === band);
    if (items.length !== ITEMS_PER_BAND) problems.push(`band ${band} has ${items.length} items`);
    for (const item of items) {
      if (!Array.isArray(item.options) || item.options.length !== 4) problems.push(`${item.id}: needs 4 options`);
    }
  }
  const forbidden = findForbiddenFields(bank);
  if (forbidden.length) problems.push(`key-like fields present: ${forbidden.join(', ')}`);
  return problems;
}

/** Writes the public `researchInstrument/{version}_{band}` documents the rules read. */
async function seedInstrument(db, { bank, bankJson, apply = false }) {
  const problems = bankProblems(bank);
  if (problems.length) throw new AdminError(problems);
  const docs = buildInstrumentDocs(bank, bankJson);
  const actions = [];
  for (const doc of docs) {
    const snap = await db.collection(INSTRUMENT).doc(doc.id).get();
    if (!snap.exists) actions.push({ type: 'create', path: `${INSTRUMENT}/${doc.id}` });
    else if (canonical(snap.data()) === canonical(doc.data)) actions.push({ type: 'unchanged', path: `${INSTRUMENT}/${doc.id}` });
    else problems.push(`${INSTRUMENT}/${doc.id} already exists with different content (never overwritten)`);
  }
  if (problems.length) throw new AdminError(problems);
  if (apply) {
    const batch = db.batch();
    for (const doc of docs) {
      if (actions.some((a) => a.type === 'create' && a.path.endsWith(doc.id))) {
        batch.create(db.collection(INSTRUMENT).doc(doc.id), doc.data);
      }
    }
    await batch.commit();
  }
  return { actions, applied: apply };
}

/** Creates participant records for already-registered student accounts. */
async function enrolParticipants(db, { rows, instrumentVersion = INSTRUMENT_VERSION, apply = false }) {
  const problems = [];
  const existing = await db.collection(PARTICIPANTS).get();
  const takenResearchIds = new Set(existing.docs.map((d) => d.get('researchId')));
  const enrolled = new Set(existing.docs.map((d) => d.id));

  for (const row of rows) {
    if (enrolled.has(row.uid)) problems.push(`line ${row.line}: already enrolled (enrolment never overwrites)`);
    if (takenResearchIds.has(row.researchId)) problems.push(`line ${row.line}: researchId already used by another participant`);
    const user = await db.collection('users').doc(row.uid).get();
    if (!user.exists) problems.push(`line ${row.line}: no users/{uid} profile for this account`);
    else if (user.get('role') !== 'siswa') problems.push(`line ${row.line}: the account is not a student (role must be "siswa")`);
  }
  if (problems.length) throw new AdminError(problems);

  const actions = rows.map((row) => ({
    type: 'create',
    path: `${PARTICIPANTS}/${row.uid}`,
    researchId: row.researchId,
    band: row.band,
    cohort: row.cohort,
  }));
  if (apply) {
    const batch = db.batch();
    for (const row of rows) {
      batch.create(db.collection(PARTICIPANTS).doc(row.uid), {
        researchId: row.researchId,
        band: row.band,
        bandSource: 'researcher_assigned',
        instrumentVersion,
        authorizedAttempts: { preTest: 0, postTest: 0 },
        cohort: row.cohort,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }
    await batch.commit();
  }
  return { actions, applied: apply };
}

async function pretestCompleted(db, uid, participant) {
  const n = participant.authorizedAttempts.preTest;
  if (!(n >= 1)) return false;
  const snap = await db.collection(ATTEMPTS).doc(attemptId(uid, 'preTest', n)).get();
  return snap.exists && snap.get('status') === 'completed';
}

/**
 * First authorization of a stage (0 → 1) for the given [uids], or for every
 * participant of [cohort]. With a cohort, participants that aren't eligible
 * are listed in `skipped` with the reason; with explicit UIDs, any
 * ineligible UID refuses the whole request.
 */
async function authorizeStage(db, { uids, cohort, stage, confirmSession4 = false, apply = false }) {
  checkStage(stage);
  if (Boolean(uids && uids.length) === Boolean(cohort)) {
    throw new AdminError(['select participants with --uid (repeatable) or --cohort, not both']);
  }
  if (stage === 'postTest' && !confirmSession4) {
    throw new AdminError([
      'opening the posttest needs --confirm-session4-completed: the tooling cannot verify treatment session 4, so the researcher must attest it',
    ]);
  }

  const problems = [];
  const skipped = [];
  let docs;
  if (cohort) {
    docs = (await db.collection(PARTICIPANTS).where('cohort', '==', cohort).get()).docs;
  } else {
    docs = [];
    for (const uid of uids) {
      const snap = await db.collection(PARTICIPANTS).doc(uid).get();
      if (!snap.exists) problems.push(`${uid}: not enrolled`);
      else docs.push(snap);
    }
  }

  const eligible = [];
  for (const snap of docs) {
    const p = snap.data();
    const reject = (why) => (cohort ? skipped.push({ uid: snap.id, researchId: p.researchId, reason: why }) : problems.push(`${snap.id}: ${why}`));
    if (p.authorizedAttempts[stage] !== 0) {
      reject(`${stage} already authorized (attempt ${p.authorizedAttempts[stage]}); use retake for another attempt`);
      continue;
    }
    const bankDoc = await db.collection(INSTRUMENT).doc(`${p.instrumentVersion}_${p.band}`).get();
    if (!bankDoc.exists) {
      problems.push(`${INSTRUMENT}/${p.instrumentVersion}_${p.band} is not seeded (run seed-instrument first)`);
      continue;
    }
    if (stage === 'postTest' && !(await pretestCompleted(db, snap.id, p))) {
      reject('pretest not completed');
      continue;
    }
    eligible.push(snap);
  }
  if (problems.length) throw new AdminError([...new Set(problems)]);

  const actions = eligible.map((snap) => ({
    type: 'authorize',
    path: `${PARTICIPANTS}/${snap.id}`,
    researchId: snap.get('researchId'),
    stage,
    attemptNumber: 1,
    ...(stage === 'postTest' ? { attestation: 'researcher confirmed treatment session 4 completed' } : {}),
  }));
  if (apply && eligible.length) {
    await db.runTransaction(async (t) => {
      const fresh = await Promise.all(eligible.map((snap) => t.get(snap.ref)));
      for (const snap of fresh) {
        if (snap.get(`authorizedAttempts.${stage}`) !== 0) throw new AdminError([`${snap.id}: changed concurrently; nothing written`]);
      }
      for (const snap of fresh) {
        t.update(snap.ref, { [`authorizedAttempts.${stage}`]: 1, updatedAt: serverTimestamp() });
      }
    });
  }
  return { actions, skipped, applied: apply };
}

async function currentAttempt(db, uid, stage) {
  const pSnap = await db.collection(PARTICIPANTS).doc(uid).get();
  if (!pSnap.exists) throw new AdminError([`${uid}: not enrolled`]);
  const p = pSnap.data();
  const n = p.authorizedAttempts[stage];
  if (!(n >= 1)) throw new AdminError([`${uid}: ${stage} is not authorized`]);
  const ref = db.collection(ATTEMPTS).doc(attemptId(uid, stage, n));
  const snap = await ref.get();
  return { pSnap, p, n, ref, snap };
}

/**
 * Marks the currently authorized attempt of [stage] as voided (technical
 * interruption or another invalidating incident). All answers are kept.
 * A completed attempt is voided only with [allowCompleted].
 */
async function voidAttempt(db, { uid, stage, reason, allowCompleted = false, apply = false }) {
  checkStage(stage);
  const why = checkReason(reason);
  const { p, n, ref, snap } = await currentAttempt(db, uid, stage);
  const problems = [];
  if (!snap.exists) problems.push(`${uid}: attempt ${n} of ${stage} was never started (nothing to void)`);
  const status = snap.exists ? snap.get('status') : null;
  if (status === 'voided') problems.push(`${uid}: attempt ${n} of ${stage} is already voided`);
  if (status === 'completed' && !allowCompleted) {
    problems.push(`${uid}: attempt ${n} of ${stage} is completed; voiding it needs --allow-completed`);
  }
  if (stage === 'preTest' && p.authorizedAttempts.postTest > 0) {
    problems.push(`${uid}: the posttest is already authorized; voiding the pretest now is refused`);
  }
  if (problems.length) throw new AdminError(problems);

  const answered = Object.keys(snap.get('responses') || {}).length;
  const action = { type: 'void', path: ref.path, previousStatus: status, answered, reason: why };
  if (apply) {
    await db.runTransaction(async (t) => {
      const fresh = await t.get(ref);
      if (fresh.get('status') !== status) throw new AdminError([`${uid}: attempt changed concurrently; nothing written`]);
      t.update(ref, { status: 'voided', voidReason: why, voidedAt: serverTimestamp() });
    });
  }
  return { actions: [action], applied: apply };
}

/** Authorizes attempt n+1 of [stage] after the current attempt n was voided. */
async function authorizeRetake(db, { uid, stage, reason, apply = false }) {
  checkStage(stage);
  const why = checkReason(reason);
  const { pSnap, p, n, snap } = await currentAttempt(db, uid, stage);
  const problems = [];
  if (!snap.exists) problems.push(`${uid}: attempt ${n} of ${stage} was never started; no retake is needed`);
  else if (snap.get('status') !== 'voided') problems.push(`${uid}: void attempt ${n} of ${stage} first (retakes never replace a live attempt)`);
  if (stage === 'preTest' && p.authorizedAttempts.postTest > 0) {
    problems.push(`${uid}: the posttest is already authorized; a pretest retake is refused`);
  }
  if (problems.length) throw new AdminError(problems);

  const action = { type: 'retake', path: pSnap.ref.path, stage, fromAttempt: n, toAttempt: n + 1, reason: why };
  if (apply) {
    await db.runTransaction(async (t) => {
      const fresh = await t.get(pSnap.ref);
      if (fresh.get(`authorizedAttempts.${stage}`) !== n) throw new AdminError([`${uid}: changed concurrently; nothing written`]);
      t.update(pSnap.ref, { [`authorizedAttempts.${stage}`]: n + 1, updatedAt: serverTimestamp() });
    });
  }
  return { actions: [action], applied: apply };
}

/** Per-participant overview: authorization and every attempt's status and answer count. */
async function stageStatus(db, { uid } = {}) {
  const docs = uid
    ? [await db.collection(PARTICIPANTS).doc(uid).get()].filter((s) => s.exists)
    : (await db.collection(PARTICIPANTS).get()).docs;
  const rows = [];
  for (const snap of docs) {
    const p = snap.data();
    const row = { uid: snap.id, researchId: p.researchId, band: p.band, cohort: p.cohort, stages: {} };
    for (const stage of STAGES) {
      const authorized = p.authorizedAttempts[stage];
      const attempts = [];
      for (let n = 1; n <= authorized; n++) {
        const a = await db.collection(ATTEMPTS).doc(attemptId(snap.id, stage, n)).get();
        attempts.push(
          a.exists
            ? { n, status: a.get('status'), answered: Object.keys(a.get('responses') || {}).length }
            : { n, status: 'not_started', answered: 0 }
        );
      }
      row.stages[stage] = { authorized, attempts };
    }
    rows.push(row);
  }
  return rows.sort((a, b) => String(a.researchId).localeCompare(String(b.researchId)));
}

module.exports = {
  AdminError,
  seedInstrument,
  enrolParticipants,
  authorizeStage,
  voidAttempt,
  authorizeRetake,
  stageStatus,
  canonical,
  PARTICIPANTS,
  ATTEMPTS,
  INSTRUMENT,
};
