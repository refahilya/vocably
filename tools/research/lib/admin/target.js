'use strict';

/**
 * Chooses where researcher tooling connects, and refuses anything ambiguous.
 *
 * - `--emulator` (the default for development): requires
 *   FIRESTORE_EMULATOR_HOST to point at a loopback host and a `demo-*`
 *   project, which Firebase treats as offline-only. No credentials are used.
 * - `--production`: requires `--project <id>` and `--confirm-project <same id>`,
 *   a non-demo project, GOOGLE_APPLICATION_CREDENTIALS pointing at an
 *   existing service-account file outside this repository, any Git working
 *   tree and OneDrive, and NO emulator variables (so a half-configured shell
 *   can never mix the two).
 * - Neither flag, or both: refused.
 *
 * Writes additionally need `--apply` (see bin/research_admin.js); without it
 * every command is a dry run.
 */

const fs = require('fs');
const path = require('path');
const { assessPrivateOutputPath } = require('../safeOutput');

const DEFAULT_EMULATOR_PROJECT = 'demo-vocably-test';
const LOOPBACK_HOST_RE = /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/;

class TargetError extends Error {}

function resolveTarget({ emulator, production, project, confirmProject }, { env = process.env, repoRoot }) {
  if (Boolean(emulator) === Boolean(production)) {
    throw new TargetError('Choose exactly one target: --emulator or --production.');
  }

  if (emulator) {
    const host = env.FIRESTORE_EMULATOR_HOST || '';
    if (!LOOPBACK_HOST_RE.test(host)) {
      throw new TargetError(
        'FIRESTORE_EMULATOR_HOST must point at a local emulator (e.g. 127.0.0.1:8080). Start it with `npm run emulators`.'
      );
    }
    const authHost = env.FIREBASE_AUTH_EMULATOR_HOST;
    if (authHost && !LOOPBACK_HOST_RE.test(authHost)) {
      throw new TargetError('FIREBASE_AUTH_EMULATOR_HOST must point at a local emulator.');
    }
    const projectId = project || env.GCLOUD_PROJECT || DEFAULT_EMULATOR_PROJECT;
    if (!projectId.startsWith('demo-')) {
      throw new TargetError(`Emulator runs must use a demo-* project (got "${projectId}").`);
    }
    return { mode: 'emulator', projectId, firestoreHost: host, authHost: authHost || null };
  }

  for (const name of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
    if (env[name]) throw new TargetError(`Refusing --production while ${name} is set. Unset it first.`);
  }
  if (!project || project.startsWith('demo-')) {
    throw new TargetError('--production needs --project with the real (non-demo) project ID.');
  }
  if (confirmProject !== project) {
    throw new TargetError('--production needs --confirm-project repeating the same project ID.');
  }
  const credentials = env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credentials || !fs.existsSync(credentials)) {
    throw new TargetError('--production needs GOOGLE_APPLICATION_CREDENTIALS pointing at your service-account file.');
  }
  const location = assessPrivateOutputPath(credentials, {
    repoRoot,
    requiredSuffix: path.extname(credentials).toLowerCase() || '.json',
    env,
    allowExisting: true,
  });
  if (!location.ok) {
    throw new TargetError(`Refusing the service-account file location: ${location.reasons.join('; ')}.`);
  }
  return { mode: 'production', projectId: project };
}

/** Initializes a dedicated Admin app for [target]; returns `{ app, db, auth }`. */
function initAdmin(target, name = `research-admin-${Date.now()}-${Math.random()}`) {
  const { initializeApp, applicationDefault } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  const { getAuth } = require('firebase-admin/auth');
  const options =
    target.mode === 'emulator'
      ? { projectId: target.projectId }
      : { projectId: target.projectId, credential: applicationDefault() };
  const app = initializeApp(options, name);
  return { app, db: getFirestore(app), auth: getAuth(app) };
}

module.exports = { resolveTarget, initAdmin, TargetError, DEFAULT_EMULATOR_PROJECT };
