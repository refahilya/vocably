'use strict';

/**
 * One-time registration (and revocation) of the single researcher operator
 * who may use the Researcher Panel in the app (`DATA_MODEL.md` §6d). Run
 * with the Admin SDK; the security rules give no client any way to write
 * `researchOperators`, so this is the only path to the panel.
 *
 * Grant checks, all before writing:
 * - the e-mail belongs to an existing Firebase Auth account;
 * - its `users/{uid}` profile exists with role `guru` (the panel lives in
 *   the guru app; roles are immutable, so it stays guru);
 * - it is not a research participant;
 * - no OTHER account is an active operator (one operator, by decision).
 * Revoking sets `active: false`; the rules re-read the record on every
 * operator request, so revocation takes effect on the next request.
 * Operations print UIDs, never other personal data.
 */

const { AdminError, PARTICIPANTS } = require('./operations');

const OPERATORS = 'researchOperators';

function fv() {
  return require('firebase-admin/firestore').FieldValue;
}

async function accountFor(auth, email) {
  const address = String(email || '').trim().toLowerCase();
  if (!address) throw new AdminError(['operator needs --email <the researcher account e-mail>']);
  try {
    return { uid: (await auth.getUserByEmail(address)).uid, email: address };
  } catch {
    throw new AdminError(['no Firebase Auth account has this e-mail (sign up in the app first)']);
  }
}

/** Registers [email]'s account as the (only) active researcher operator. */
async function grantOperator(db, auth, { email, apply = false }) {
  const { uid, email: address } = await accountFor(auth, email);
  const problems = [];
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists) problems.push(`${uid}: no users/{uid} profile (finish sign-up in the app first)`);
  else if (user.get('role') !== 'guru') problems.push(`${uid}: the account is not a guru account (the panel is part of the guru app)`);
  if ((await db.collection(PARTICIPANTS).doc(uid).get()).exists) problems.push(`${uid}: a research participant cannot be the operator`);
  const active = await db.collection(OPERATORS).where('active', '==', true).get();
  const others = active.docs.filter((d) => d.id !== uid).map((d) => d.id);
  if (others.length) problems.push(`another account is already the active operator (${others.join(', ')}); revoke it first`);
  if (problems.length) throw new AdminError(problems);

  const ref = db.collection(OPERATORS).doc(uid);
  const current = await ref.get();
  if (current.exists && current.get('active') === true) {
    return { actions: [{ type: 'unchanged', path: ref.path, uid, active: true }], applied: apply };
  }
  const action = { type: current.exists ? 'reactivate' : 'create', path: ref.path, uid, active: true };
  if (apply) {
    await db.runTransaction(async (t) => {
      const fresh = await t.get(ref);
      if (fresh.exists !== current.exists || (fresh.exists && fresh.get('active') === true)) {
        throw new AdminError([`${uid}: changed concurrently; nothing written`]);
      }
      t.set(ref, { email: address, active: true, grantedAt: fv().serverTimestamp(), revokedAt: null });
    });
  }
  return { actions: [action], applied: apply };
}

/** Revokes the operator role of [email]'s account (kept as a record). */
async function revokeOperator(db, auth, { email, apply = false }) {
  const { uid } = await accountFor(auth, email);
  const ref = db.collection(OPERATORS).doc(uid);
  const current = await ref.get();
  if (!current.exists) throw new AdminError([`${uid}: this account is not an operator`]);
  if (current.get('active') !== true) return { actions: [{ type: 'unchanged', path: ref.path, uid, active: false }], applied: apply };
  const action = { type: 'revoke', path: ref.path, uid, active: false };
  if (apply) await ref.update({ active: false, revokedAt: fv().serverTimestamp() });
  return { actions: [action], applied: apply };
}

module.exports = { grantOperator, revokeOperator, OPERATORS };
