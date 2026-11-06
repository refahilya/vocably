'use strict';

/**
 * Trusted operations for the research treatment (`DATA_MODEL.md` §6e), run
 * with the Admin SDK. Same contract as `operations.js`: validate first,
 * refuse the whole request on any problem, dry run unless `apply`, never
 * delete, never overwrite a plan.
 *
 * - `seedTreatment` writes the create-only plan documents
 *   (`researchTreatmentPlan/{planVersion}_{band}`) and the study's treatment
 *   configuration (`researchStudy/current.treatment`: active plan version +
 *   make-up deadline in days). The plan version can be switched only while
 *   no research session set exists; the deadline can be adjusted any time.
 * - `recordTreatmentSession` repairs a missing completion record (the app
 *   writes it right after a session ends; a lost connection can leave it
 *   unwritten) — only from a learning session whose evidence is complete.
 */

const { AdminError, canonical, PARTICIPANTS } = require('./operations');
const { PLAN_COLLECTION, buildPlanDocs, validateTreatmentPlan } = require('../treatment/plan');

const STUDY = 'researchStudy';
const SETS = 'targetWordSets';
const SESSIONS = 'learningSessions';
const TREATMENT = 'researchTreatment';
const DEFAULT_MAKEUP_DAYS = 2;
const MAX_MAKEUP_DAYS = 14;
const MAX_REASON_LENGTH = 300;

function fv() {
  return require('firebase-admin/firestore');
}

async function researchSetsOf(db, planVersion) {
  return (await db.collection(SETS).where('research.planVersion', '==', planVersion).limit(1).get()).docs;
}

async function seedTreatment(db, { plan, bank, bankSha256, vocabByBand, makeupDeadlineDays = DEFAULT_MAKEUP_DAYS, apply = false }) {
  const problems = validateTreatmentPlan(plan, { bank, bankSha256, vocabByBand });
  const days = Number(makeupDeadlineDays);
  if (!Number.isInteger(days) || days < 1 || days > MAX_MAKEUP_DAYS) problems.push(`--makeup-days must be a whole number from 1 to ${MAX_MAKEUP_DAYS}`);
  if (problems.length) throw new AdminError(problems);

  const actions = [];
  const docs = buildPlanDocs(plan);
  for (const doc of docs) {
    const snap = await db.collection(PLAN_COLLECTION).doc(doc.id).get();
    if (!snap.exists) actions.push({ type: 'create', path: `${PLAN_COLLECTION}/${doc.id}` });
    else if (canonical(snap.data()) === canonical(doc.data)) actions.push({ type: 'unchanged', path: `${PLAN_COLLECTION}/${doc.id}` });
    else problems.push(`${PLAN_COLLECTION}/${doc.id} already exists with a different allocation (a plan is never overwritten; build a new version)`);
  }

  const studyRef = db.collection(STUDY).doc('current');
  const study = await studyRef.get();
  if (!study.exists) problems.push('researchStudy/current does not exist (set the study status first)');
  else if (study.get('status') === 'closed') problems.push('the study is closed');
  const current = study.exists ? study.get('treatment') || null : null;
  if (current && current.planVersion && current.planVersion !== plan.planVersion) {
    if ((await researchSetsOf(db, current.planVersion)).length) {
      problems.push(`plan ${current.planVersion} is already in use (research sessions were opened); it cannot be replaced`);
    }
  }
  if (problems.length) throw new AdminError(problems);

  const config = { planVersion: plan.planVersion, makeupDeadlineDays: days };
  const unchanged = current && current.planVersion === config.planVersion && current.makeupDeadlineDays === config.makeupDeadlineDays;
  actions.push({ type: unchanged ? 'unchanged' : 'update', path: `${STUDY}/current`, treatment: config, from: current });

  if (apply) {
    const batch = db.batch();
    for (const doc of docs) {
      if (actions.some((a) => a.type === 'create' && a.path === `${PLAN_COLLECTION}/${doc.id}`)) {
        batch.create(db.collection(PLAN_COLLECTION).doc(doc.id), doc.data);
      }
    }
    if (!unchanged) batch.update(studyRef, { treatment: config, updatedAt: fv().FieldValue.serverTimestamp() });
    await batch.commit();
  }
  return { actions, applied: apply };
}

function checkReason(reason) {
  const text = String(reason || '').trim();
  if (!text) throw new AdminError(['a --reason is required (it is kept in the audit log)']);
  if (text.length > MAX_REASON_LENGTH || /[\r\n]/.test(text)) throw new AdminError([`--reason must be a single line of at most ${MAX_REASON_LENGTH} characters`]);
  return text;
}

/**
 * Problems with learning session [s] (id [sessionId]) as the completion
 * evidence of official research session for [uid]; [set] is its session
 * set. Empty = complete evidence (`DATA_MODEL.md` §6e).
 */
function sessionEvidenceProblems(uid, sessionId, s, set) {
  const problems = [];
  if (!s) return [`${SESSIONS}/${sessionId} does not exist`];
  if (s.studentId !== uid) problems.push('the learning session belongs to another account');
  if (!Number.isInteger(s.researchSession)) problems.push('the learning session is not an official research session');
  if (!set) problems.push('its session set does not exist');
  else {
    const r = set.research || {};
    if (r.session !== s.researchSession) problems.push('the session number differs from its set');
    if (!(set.targetStudentIds || []).includes(uid)) problems.push('the account is not a target of its set');
    if (JSON.stringify(set.wordIds) !== JSON.stringify(s.wordIds)) problems.push('the words differ from its set');
  }
  if (s.currentPhase !== 'selesai' || !s.completedAt) problems.push('the learning session is not completed');
  if (Object.keys(s.clozeTestResult || {}).length !== (s.wordIds || []).length) problems.push('the cloze result does not cover every word');
  if (!(s.cowriteTranscript || []).length) problems.push('the co-write transcript is empty');
  return problems;
}

async function recordTreatmentSession(db, { uid, sessionId, reason, apply = false }) {
  const why = checkReason(reason);
  if (!sessionId) throw new AdminError(['--session <learningSessions document id> is required']);
  const participant = await db.collection(PARTICIPANTS).doc(uid).get();
  if (!participant.exists) throw new AdminError([`${uid}: not enrolled`]);
  const sSnap = await db.collection(SESSIONS).doc(sessionId).get();
  const s = sSnap.exists ? sSnap.data() : null;
  const setSnap = s && s.targetWordSetId ? await db.collection(SETS).doc(s.targetWordSetId).get() : null;
  const set = setSnap && setSnap.exists ? setSnap.data() : null;
  const problems = sessionEvidenceProblems(uid, sessionId, s, set);
  const ref = db.collection(TREATMENT).doc(uid);
  const existing = await ref.get();
  const key = s ? String(s.researchSession) : '';
  if (existing.exists && (existing.get('sessions') || {})[key]) problems.push(`session ${key} is already recorded`);
  if (problems.length) throw new AdminError(problems.map((p) => `${uid}: ${p}`));

  const action = { type: existing.exists ? 'update' : 'create', path: ref.path, session: s.researchSession, sessionId, reason: why };
  if (apply) {
    const { FieldValue } = fv();
    // Same entry shape as the app's, marked as written by the tooling.
    const entry = { sessionId, setId: s.targetWordSetId, kind: set.research.kind, recordedAt: FieldValue.serverTimestamp(), recordedBy: 'tooling' };
    await db.runTransaction(async (t) => {
      const fresh = await t.get(ref);
      if (fresh.exists && (fresh.get('sessions') || {})[key]) throw new AdminError([`${uid}: session ${key} was recorded concurrently; nothing written`]);
      const common = { lastRecorded: s.researchSession, updatedAt: FieldValue.serverTimestamp() };
      if (fresh.exists) t.update(ref, { [`sessions.${key}`]: entry, ...common });
      else t.create(ref, { studentId: uid, planVersion: set.research.planVersion, sessions: { [key]: entry }, ...common });
    });
  }
  return { actions: [action], applied: apply };
}

module.exports = {
  seedTreatment,
  recordTreatmentSession,
  sessionEvidenceProblems,
  STUDY,
  SETS,
  SESSIONS,
  TREATMENT,
  DEFAULT_MAKEUP_DAYS,
};
