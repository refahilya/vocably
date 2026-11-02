'use strict';

/**
 * Trusted researcher operations for the Placement Test and the study
 * lifecycle (`DATA_MODEL.md` §6, §6b), run with the Admin SDK (which
 * bypasses the security rules). Same conventions as operations.js:
 * validate everything first, return the planned `actions`, write only with
 * `apply`, never delete, re-check inside a transaction when writing.
 *
 * Policy boundaries (see `HANDOFF.md`):
 * - Signals (quality flags, lifecycle counts) never trigger anything here.
 * - An integrity (cheating-related) void needs a CONFIRMED human review
 *   first, and never allows a replacement research attempt.
 * - A technical void may be followed by a retake (new attempt number).
 * - `restore` corrects an erroneous void of the SAME attempt; it never
 *   creates an attempt.
 * - A manual band is recorded with its basis and reason and leaves the
 *   participant `conditional`: pretest/posttest stay blocked until the
 *   conditional-inclusion criteria are decided (unresolved policy).
 * - Reasons are kept in `researchReviews` (no client can read it) and in
 *   the local audit log — never on documents the student can read.
 */

const { AdminError, canonical, PARTICIPANTS, PROGRESS } = require('./operations');
const { validatePlacementKey } = require('../placement/build');
const { PLACEMENT_BANDS } = require('../placement/constants');

const PLACEMENT_ATTEMPTS = 'placementAttempts';
const PLACEMENT_INSTRUMENT = 'placementInstrument';
const PLACEMENT_KEY = 'placementKey';
const PLACEMENT_CONFIG = 'placementConfig';
const STUDY = 'researchStudy';
const REVIEWS = 'researchReviews';
const CURRENT = 'current';
const STAGES = ['placement', 'preTest', 'postTest'];
const RESEARCH_BANDS = ['A2', 'B1', 'B2', 'C1'];
const VOID_CATEGORIES = ['technical', 'integrity'];
const MAX_TEXT = 300;
/** "Open until closed" — the same far-future idea as kNoEndDate. */
const OPEN_ENDED_CLOSE = '9999-12-31T23:59:59.000Z';

function fv() {
  return require('firebase-admin/firestore');
}

function checkText(value, name) {
  const text = String(value || '').trim();
  if (!text) throw new AdminError([`a --${name} is required (it is kept in researchReviews and the audit log)`]);
  if (text.length > MAX_TEXT || /[\r\n]/.test(text)) throw new AdminError([`--${name} must be a single line of at most ${MAX_TEXT} characters`]);
  return text;
}

const researchAttemptId = (uid, n) => `${uid}_research_${n}`;

/** Public + private instrument documents for the rules. */
function placementDocs(bank, bankSha256, keyFile) {
  const bandItems = Object.fromEntries(PLACEMENT_BANDS.map((b) => [b, bank.items.filter((i) => i.band === b).map((i) => i.id)]));
  const key = Object.fromEntries(
    PLACEMENT_BANDS.map((b) => [b, Object.fromEntries(bandItems[b].map((id) => [id, keyFile.key[id]]))])
  );
  return [
    { collection: PLACEMENT_INSTRUMENT, id: bank.instrumentVersion, data: { instrumentVersion: bank.instrumentVersion, bankSha256, bandItems } },
    { collection: PLACEMENT_KEY, id: bank.instrumentVersion, data: { instrumentVersion: bank.instrumentVersion, bankSha256, key } },
  ];
}

/**
 * Seeds `placementInstrument/{v}`, `placementKey/{v}` (from the private key
 * file) and, when missing, `placementConfig/current` (learning placement
 * closed). Never overwrites a different document; never prints the key.
 */
async function seedPlacement(db, { bank, bankSha256, keyFile, apply = false }) {
  const problems = validatePlacementKey(keyFile, bank, bankSha256);
  if (problems.length) throw new AdminError(problems);
  const actions = [];
  const writes = [];
  for (const doc of placementDocs(bank, bankSha256, keyFile)) {
    const ref = db.collection(doc.collection).doc(doc.id);
    const snap = await ref.get();
    const path = `${doc.collection}/${doc.id}`;
    if (!snap.exists) {
      actions.push({ type: 'create', path });
      writes.push([ref, doc.data]);
    } else if (canonical(snap.data()) === canonical(doc.data)) actions.push({ type: 'unchanged', path });
    else problems.push(`${path} already exists with different content (never overwritten)`);
  }
  const configRef = db.collection(PLACEMENT_CONFIG).doc(CURRENT);
  const config = await configRef.get();
  if (!config.exists) {
    actions.push({ type: 'create', path: `${PLACEMENT_CONFIG}/${CURRENT}`, instrumentVersion: bank.instrumentVersion, learningOpen: false });
    writes.push([
      configRef,
      { instrumentVersion: bank.instrumentVersion, bankSha256, scoringPolicy: bank.scoringPolicy, learningOpen: false, updatedAt: fv().FieldValue.serverTimestamp() },
    ]);
  } else if (config.get('instrumentVersion') !== bank.instrumentVersion || config.get('bankSha256') !== bankSha256) {
    problems.push(`${PLACEMENT_CONFIG}/${CURRENT} names another instrument version or bank; a version change is not supported by this command`);
  } else actions.push({ type: 'unchanged', path: `${PLACEMENT_CONFIG}/${CURRENT}` });
  if (problems.length) throw new AdminError(problems);
  if (apply && writes.length) {
    const batch = db.batch();
    for (const [ref, data] of writes) batch.create(ref, data);
    await batch.commit();
  }
  return { actions, applied: apply };
}

/** Opens or closes ordinary (learning-only) placement for every account. */
async function setLearningPlacement(db, { open, apply = false }) {
  const ref = db.collection(PLACEMENT_CONFIG).doc(CURRENT);
  const snap = await ref.get();
  if (!snap.exists) throw new AdminError(['placementConfig/current does not exist (run seed-placement first)']);
  const actions = [{ type: snap.get('learningOpen') === open ? 'unchanged' : 'update', path: ref.path, learningOpen: open }];
  if (apply && actions[0].type === 'update') await ref.update({ learningOpen: open, updatedAt: fv().FieldValue.serverTimestamp() });
  return { actions, applied: apply };
}

/** setup → active → closed (final). Closing freezes every unfinished research attempt (rules). */
async function setStudyStatus(db, { status, apply = false }) {
  if (!['setup', 'active', 'closed'].includes(status)) throw new AdminError(['--status must be setup, active or closed']);
  const ref = db.collection(STUDY).doc(CURRENT);
  const snap = await ref.get();
  const from = snap.exists ? snap.get('status') : null;
  const allowed = { null: ['setup', 'active'], setup: ['active'], active: ['closed'], closed: [] };
  if (from === status) return { actions: [{ type: 'unchanged', path: ref.path, status }], applied: apply };
  if (!allowed[String(from)].includes(status)) {
    throw new AdminError([`study status ${from || '(none)'} → ${status} is not allowed (closed is final)`]);
  }
  const action = { type: snap.exists ? 'update' : 'create', path: ref.path, from, status };
  if (apply) {
    const { FieldValue } = fv();
    await db.runTransaction(async (t) => {
      const fresh = await t.get(ref);
      if ((fresh.exists ? fresh.get('status') : null) !== from) throw new AdminError(['study status changed concurrently; nothing written']);
      const data = { status, updatedAt: FieldValue.serverTimestamp(), ...(status === 'closed' ? { closedAt: FieldValue.serverTimestamp() } : {}) };
      if (fresh.exists) t.update(ref, data);
      else t.create(ref, { ...data, stages: {}, closedAt: null });
    });
  }
  return { actions: [action], applied: apply };
}

/**
 * Opens (openAt = server now, closeAt = [closeAt] or open-ended) or closes
 * (closeAt = server now) one stage window. Server timestamps only.
 */
async function setStageWindow(db, { stage, open, close, closeAt, apply = false }) {
  if (!STAGES.includes(stage)) throw new AdminError([`--stage must be one of ${STAGES.join(', ')}`]);
  if (Boolean(open) === Boolean(close)) throw new AdminError(['choose exactly one of --open or --close']);
  const ref = db.collection(STUDY).doc(CURRENT);
  const snap = await ref.get();
  if (!snap.exists) throw new AdminError(['researchStudy/current does not exist (set the study status first)']);
  if (snap.get('status') === 'closed') throw new AdminError(['the study is closed; stage windows can no longer change']);
  const current = (snap.get('stages') || {})[stage] || null;
  const { FieldValue, Timestamp } = fv();
  let update;
  let action;
  if (open) {
    let end = OPEN_ENDED_CLOSE;
    if (closeAt) {
      const parsed = new Date(closeAt);
      if (Number.isNaN(parsed.getTime()) || parsed.getTime() <= Date.now()) throw new AdminError(['--close-at must be a future ISO date-time']);
      end = parsed.toISOString();
    }
    update = { [`stages.${stage}`]: { openAt: FieldValue.serverTimestamp(), closeAt: Timestamp.fromDate(new Date(end)) } };
    action = { type: 'open', path: ref.path, stage, closeAt: end };
  } else {
    if (!current || !current.closeAt || current.closeAt.toMillis() <= Date.now()) {
      throw new AdminError([`the ${stage} window is not open`]);
    }
    update = { [`stages.${stage}.closeAt`]: FieldValue.serverTimestamp() };
    action = { type: 'close', path: ref.path, stage };
  }
  if (apply) await ref.update({ ...update, updatedAt: FieldValue.serverTimestamp() });
  return { actions: [action], applied: apply };
}

async function participantAndAttempt(db, uid) {
  const pRef = db.collection(PARTICIPANTS).doc(uid);
  const pSnap = await pRef.get();
  if (!pSnap.exists) throw new AdminError([`${uid}: not enrolled`]);
  const p = pSnap.data();
  const n = p.authorizedAttempts && p.authorizedAttempts.placement;
  if (!(n >= 1)) throw new AdminError([`${uid}: no research placement attempt is authorized for this participant`]);
  const aRef = db.collection(PLACEMENT_ATTEMPTS).doc(researchAttemptId(uid, n));
  const aSnap = await aRef.get();
  return { pRef, pSnap, p, n, aRef, aSnap };
}

function reviewRecord(uid, type, fields) {
  return { uid, stage: 'placement', type, at: fv().FieldValue.serverTimestamp(), ...fields };
}

/** Participant fields restored from a scored attempt's result (automatic band or C1 exclusion). */
function bandFromResult(a) {
  return a.pretestTargetBand
    ? { band: a.pretestTargetBand, bandSource: 'placement_test', status: 'enrolled', exclusionReason: null }
    : { band: null, bandSource: null, status: 'excluded', exclusionReason: 'placement_c1' };
}

/** Opens or closes a human review case. Signals alone never open one automatically. */
async function setReview(db, { uid, open, close, outcome, reason, apply = false }) {
  if (Boolean(open) === Boolean(close)) throw new AdminError(['choose exactly one of --open or --close']);
  const why = checkText(reason, 'reason');
  const pRef = db.collection(PARTICIPANTS).doc(uid);
  const pSnap = await pRef.get();
  if (!pSnap.exists) throw new AdminError([`${uid}: not enrolled`]);
  const state = pSnap.get('reviewStatus') || null;
  let next;
  if (open) {
    if (state === 'pending') throw new AdminError([`${uid}: a review is already pending`]);
    next = 'pending';
  } else {
    if (state !== 'pending') throw new AdminError([`${uid}: no review is pending`]);
    if (!['confirmed', 'not_confirmed'].includes(outcome)) throw new AdminError(['--outcome must be confirmed or not_confirmed']);
    next = outcome;
  }
  const action = { type: open ? 'review_open' : 'review_close', path: pRef.path, from: state, reviewStatus: next, reason: why };
  if (apply) {
    await db.runTransaction(async (t) => {
      const fresh = await t.get(pRef);
      if ((fresh.get('reviewStatus') || null) !== state) throw new AdminError([`${uid}: changed concurrently; nothing written`]);
      t.update(pRef, { reviewStatus: next, updatedAt: fv().FieldValue.serverTimestamp() });
      t.create(db.collection(REVIEWS).doc(), reviewRecord(uid, action.type, { reviewStatus: next, reason: why }));
    });
  }
  return { actions: [action], applied: apply };
}

/**
 * Voids the participant's current research placement attempt. `technical`
 * allows a retake; `integrity` needs a confirmed review and never allows a
 * replacement attempt. A band that came from the attempt is revoked
 * (recorded in bandHistory). Refused once the pretest is authorized.
 */
async function voidPlacement(db, { uid, category, reason, apply = false }) {
  if (!VOID_CATEGORIES.includes(category)) throw new AdminError([`--category must be one of ${VOID_CATEGORIES.join(', ')}`]);
  const why = checkText(reason, 'reason');
  const { pRef, p, n, aRef, aSnap } = await participantAndAttempt(db, uid);
  const problems = [];
  if (!aSnap.exists) problems.push(`${uid}: placement attempt ${n} was never started (nothing to void)`);
  const status = aSnap.exists ? aSnap.get('status') : null;
  if (status === 'voided') problems.push(`${uid}: placement attempt ${n} is already voided`);
  if (category === 'integrity' && p.reviewStatus !== 'confirmed') {
    problems.push(`${uid}: an integrity void needs a confirmed human review first (review --open, then --close --outcome confirmed)`);
  }
  if ((p.authorizedAttempts.preTest || 0) > 0) problems.push(`${uid}: the pretest is already authorized; voiding the placement now is refused`);
  if (problems.length) throw new AdminError(problems);

  const revokes = p.placementAttemptId === aRef.id;
  const nextStatus = category === 'integrity' ? 'awaiting_manual_band' : 'awaiting_placement';
  const action = { type: 'void', path: aRef.path, category, previousStatus: status, participantStatus: nextStatus, revokesBand: revokes, reason: why };
  if (apply) {
    const { FieldValue, Timestamp } = fv();
    await db.runTransaction(async (t) => {
      const [fa, fp, fm] = [await t.get(aRef), await t.get(pRef), await t.get(db.collection(PROGRESS).doc(aRef.id))];
      if (fa.get('status') !== status || fp.get('authorizedAttempts.placement') !== n) {
        throw new AdminError([`${uid}: changed concurrently; nothing written`]);
      }
      t.update(aRef, { status: 'voided', voidCategory: category, voidedFromStatus: status, voidedAt: FieldValue.serverTimestamp() });
      if (fm.exists) t.update(fm.ref, { status: 'voided', updatedAt: FieldValue.serverTimestamp() });
      const pUpdate = { status: nextStatus, updatedAt: FieldValue.serverTimestamp() };
      if (revokes) {
        Object.assign(pUpdate, {
          band: null,
          bandSource: null,
          exclusionReason: null,
          placementAttemptId: null,
          bandHistory: FieldValue.arrayUnion({ change: 'revoked', band: fp.get('band'), bandSource: fp.get('bandSource'), attemptId: aRef.id, at: Timestamp.now() }),
        });
      }
      t.update(pRef, pUpdate);
      t.create(db.collection(REVIEWS).doc(), reviewRecord(uid, 'void', { attemptId: aRef.id, category, reason: why }));
    });
  }
  return { actions: [action], applied: apply };
}

/** Authorizes attempt n+1 after a TECHNICAL void of attempt n. */
async function retakePlacement(db, { uid, reason, apply = false }) {
  const why = checkText(reason, 'reason');
  const { pRef, p, n, aSnap } = await participantAndAttempt(db, uid);
  const problems = [];
  if (!aSnap.exists || aSnap.get('status') !== 'voided') problems.push(`${uid}: void placement attempt ${n} first (retakes never replace a live attempt)`);
  else if (aSnap.get('voidCategory') !== 'technical') problems.push(`${uid}: attempt ${n} was voided for integrity; no replacement research attempt is allowed`);
  if (p.status !== 'awaiting_placement') problems.push(`${uid}: participant status is ${p.status}, not awaiting_placement`);
  if (problems.length) throw new AdminError(problems);
  const action = { type: 'retake', path: pRef.path, stage: 'placement', fromAttempt: n, toAttempt: n + 1, reason: why };
  if (apply) {
    await db.runTransaction(async (t) => {
      const fresh = await t.get(pRef);
      if (fresh.get('authorizedAttempts.placement') !== n) throw new AdminError([`${uid}: changed concurrently; nothing written`]);
      t.update(pRef, { 'authorizedAttempts.placement': n + 1, updatedAt: fv().FieldValue.serverTimestamp() });
      t.create(db.collection(REVIEWS).doc(), reviewRecord(uid, 'retake', { fromAttempt: n, toAttempt: n + 1, reason: why }));
    });
  }
  return { actions: [action], applied: apply };
}

/**
 * Administrative correction of an ERRONEOUS void: the same attempt returns
 * to the status it had, and a scored attempt's result becomes the band
 * source again. No attempt is created. Refused after a retake or a manual band.
 */
async function restorePlacement(db, { uid, reason, apply = false }) {
  const why = checkText(reason, 'reason');
  const { pRef, p, n, aRef, aSnap } = await participantAndAttempt(db, uid);
  const problems = [];
  if (!aSnap.exists || aSnap.get('status') !== 'voided') problems.push(`${uid}: placement attempt ${n} is not voided`);
  if (p.band != null || p.bandSource === 'manual_review') problems.push(`${uid}: a band is already recorded; restoring is refused`);
  if ((p.authorizedAttempts.preTest || 0) > 0) problems.push(`${uid}: the pretest is already authorized; restoring is refused`);
  if (problems.length) throw new AdminError(problems);
  const a = aSnap.data();
  const back = a.voidedFromStatus;
  const pUpdate = back === 'scored' ? { ...bandFromResult(a), placementAttemptId: aRef.id } : { status: 'awaiting_placement' };
  const action = { type: 'restore', path: aRef.path, status: back, participant: pUpdate, reason: why };
  if (apply) {
    const { FieldValue, Timestamp } = fv();
    await db.runTransaction(async (t) => {
      const [fa, fp, fm] = [await t.get(aRef), await t.get(pRef), await t.get(db.collection(PROGRESS).doc(aRef.id))];
      if (fa.get('status') !== 'voided' || fp.get('authorizedAttempts.placement') !== n || fp.get('band') != null) {
        throw new AdminError([`${uid}: changed concurrently; nothing written`]);
      }
      if (fm.exists) t.update(fm.ref, { status: back, updatedAt: FieldValue.serverTimestamp() });
      t.update(aRef, { status: back, voidCategory: FieldValue.delete(), voidedFromStatus: FieldValue.delete(), voidedAt: FieldValue.delete(), restoredAt: FieldValue.serverTimestamp() });
      const update = { ...pUpdate, updatedAt: FieldValue.serverTimestamp() };
      if (back === 'scored') {
        update.bandHistory = FieldValue.arrayUnion({ change: 'restored', band: pUpdate.band, bandSource: pUpdate.bandSource, attemptId: aRef.id, at: Timestamp.now() });
      }
      t.update(pRef, update);
      t.create(db.collection(REVIEWS).doc(), reviewRecord(uid, 'restore', { attemptId: aRef.id, reason: why }));
    });
  }
  return { actions: [action], applied: apply };
}

/**
 * Records a researcher-assigned band after an integrity void. The
 * participant becomes `conditional`: research stages stay blocked until the
 * conditional-inclusion criteria are decided (unresolved policy).
 */
async function assignManualBand(db, { uid, band, basis, reason, apply = false }) {
  if (!RESEARCH_BANDS.includes(band)) throw new AdminError([`--band must be one of ${RESEARCH_BANDS.join(', ')}`]);
  const why = checkText(reason, 'reason');
  const evidence = checkText(basis, 'basis');
  const { pRef, p, n, aSnap } = await participantAndAttempt(db, uid);
  const problems = [];
  if (p.status !== 'awaiting_manual_band') problems.push(`${uid}: participant status is ${p.status}, not awaiting_manual_band`);
  if (!aSnap.exists || aSnap.get('status') !== 'voided' || aSnap.get('voidCategory') !== 'integrity') {
    problems.push(`${uid}: a manual band follows only an integrity void of placement attempt ${n}`);
  }
  if (problems.length) throw new AdminError(problems);
  const action = { type: 'manual_band', path: pRef.path, band, participantStatus: 'conditional', basis: evidence, reason: why };
  if (apply) {
    const { FieldValue, Timestamp } = fv();
    await db.runTransaction(async (t) => {
      const fresh = await t.get(pRef);
      if (fresh.get('status') !== 'awaiting_manual_band' || fresh.get('band') != null) throw new AdminError([`${uid}: changed concurrently; nothing written`]);
      t.update(pRef, {
        band,
        bandSource: 'manual_review',
        status: 'conditional',
        updatedAt: FieldValue.serverTimestamp(),
        bandHistory: FieldValue.arrayUnion({ change: 'manual', band, bandSource: 'manual_review', at: Timestamp.now() }),
      });
      t.create(db.collection(REVIEWS).doc(), reviewRecord(uid, 'manual_band', { band, basis: evidence, reason: why }));
    });
  }
  return { actions: [action], applied: apply };
}

module.exports = {
  seedPlacement,
  setLearningPlacement,
  setStudyStatus,
  setStageWindow,
  setReview,
  voidPlacement,
  retakePlacement,
  restorePlacement,
  assignManualBand,
  placementDocs,
  PLACEMENT_ATTEMPTS,
  PLACEMENT_INSTRUMENT,
  PLACEMENT_KEY,
  PLACEMENT_CONFIG,
  STUDY,
  REVIEWS,
  OPEN_ENDED_CLOSE,
};
