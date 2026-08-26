#!/usr/bin/env node
'use strict';

/**
 * Stage 3 of the vocab import pipeline: writes the canonical (translated)
 * vocabulary data to the real Firestore `vocabWords`/`topics` collections
 * via the Admin SDK.
 *
 * This script deliberately requires the DEVELOPER's own credentials —
 * never a hardcoded/embedded key, never run automatically as part of an
 * unattended pipeline. Uses Application Default Credentials, i.e.
 * whatever `GOOGLE_APPLICATION_CREDENTIALS` (a service-account JSON file
 * path) or another ADC mechanism already provides. If that isn't
 * configured, this script stops immediately with the exact fix instead
 * of a raw SDK stack trace.
 *
 * Safety gates:
 *   --dry-run   Read existing Firestore state + compute what WOULD
 *               happen (create/update/skip counts) without writing
 *               anything. Always run this first.
 *   --yes       Required in addition to actually committing writes —
 *               running with neither flag prints the same thing
 *               --dry-run would and exits, so a bare `node
 *               bin/seed_firestore.js` can never accidentally write.
 *
 * Usage:
 *   node bin/seed_firestore.js --dry-run
 *   node bin/seed_firestore.js --yes
 */

const fs = require('fs');
const path = require('path');

const { decideVocabWordAction, topicSlug } = require('../lib/seedDecision');

const ROOT = path.join(__dirname, '..');
const OUTPUT_DIR = path.join(ROOT, 'output');
const TRANSLATED_PATH = path.join(OUTPUT_DIR, 'canonical_vocab_translated.json');
const CANONICAL_PATH = path.join(OUTPUT_DIR, 'canonical_vocab.json');

const FIRESTORE_BATCH_LIMIT = 500;

function loadCanonicalData() {
  if (fs.existsSync(TRANSLATED_PATH)) {
    return JSON.parse(fs.readFileSync(TRANSLATED_PATH, 'utf8'));
  }
  if (fs.existsSync(CANONICAL_PATH)) {
    console.warn(
      `⚠ ${path.relative(ROOT, TRANSLATED_PATH)} not found — using ` +
        `${path.relative(ROOT, CANONICAL_PATH)} instead, which means every ` +
        'meaning will be written with translation: null. Run ' +
        '"node bin/translate.js" first if that is not what you want.'
    );
    return JSON.parse(fs.readFileSync(CANONICAL_PATH, 'utf8'));
  }
  throw new Error(
    `Missing canonical data. Run "node bin/merge.js" (and ideally ` +
      `"node bin/translate.js") first.`
  );
}

function chunk(array, size) {
  const out = [];
  for (let i = 0; i < array.length; i += size) out.push(array.slice(i, i + size));
  return out;
}

async function main() {
  const argv = process.argv.slice(2);
  const dryRun = argv.includes('--dry-run') || !argv.includes('--yes');

  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error(
      [
        'Missing credential: GOOGLE_APPLICATION_CREDENTIALS is not set.',
        '',
        'This script uses the Firebase Admin SDK, which needs a service-account',
        'key with write access to the "vocably-idn-en" Firestore project — the',
        'Firebase CLI login already present in this environment is a separate',
        'credential store and is NOT sufficient for the Admin SDK.',
        '',
        'To configure it:',
        '  1. In the Firebase console -> Project settings -> Service accounts,',
        '     generate a new private key (downloads a JSON file). Keep it out of',
        '     git (it is a secret) — do not place it inside the repo working tree',
        '     unless the path is also added to .gitignore.',
        '  2. Set the environment variable before running this script:',
        '       PowerShell:  $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\\path\\to\\key.json"',
        '       bash:        export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"',
        '  3. Re-run:  node bin/seed_firestore.js --dry-run',
        '     then, once you have reviewed the dry-run output:',
        '            node bin/seed_firestore.js --yes',
      ].join('\n')
    );
    process.exitCode = 1;
    return;
  }

  // Deferred require so the credential check above can run (and print
  // its message) even in environments where firebase-admin itself has
  // trouble loading without a credential present.
  const admin = require('firebase-admin');
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
  const db = admin.firestore();

  const documents = loadCanonicalData();
  console.log(`Loaded ${documents.length} canonical vocabulary documents.`);
  console.log(dryRun ? '=== DRY RUN (no writes will be made) ===' : '=== LIVE RUN — writes will be committed ===');

  const counts = { create: 0, update: 0, 'skip-unchanged': 0, 'skip-foreign': 0, error: 0 };
  const foreignSkips = [];
  const errors = [];
  const writesToCommit = []; // { ref, data, isCreate }

  for (const doc of documents) {
    try {
      const snapshot = await db.collection('vocabWords').doc(doc.word).get();
      const existing = snapshot.exists ? snapshot.data() : null;
      const decision = decideVocabWordAction(existing, doc);
      counts[decision.action]++;
      if (decision.action === 'skip-foreign') {
        foreignSkips.push({ word: doc.word, reason: decision.reason });
      } else if (decision.action === 'create' || decision.action === 'update') {
        writesToCommit.push({
          ref: db.collection('vocabWords').doc(doc.word),
          data: decision.data,
          isCreate: decision.action === 'create',
        });
      }
    } catch (err) {
      counts.error++;
      errors.push({ word: doc.word, message: err.message });
    }
  }

  // Topics master list — same create-only-if-missing idempotency, via a
  // slug docId (see `topicSlug` doc comment for why).
  const allTopics = new Set();
  for (const doc of documents) for (const t of doc.topics) allTopics.add(t);
  const topicWrites = [];
  for (const topicName of allTopics) {
    const ref = db.collection('topics').doc(topicSlug(topicName));
    const snapshot = await ref.get();
    if (!snapshot.exists) {
      topicWrites.push({ ref, name: topicName });
    }
  }

  console.log('\n--- vocabWords plan ---');
  console.log(`  create:          ${counts.create}`);
  console.log(`  update:          ${counts.update}`);
  console.log(`  skip (unchanged):${counts['skip-unchanged']}`);
  console.log(`  skip (foreign):  ${counts['skip-foreign']}`);
  console.log(`  errors:          ${counts.error}`);
  if (foreignSkips.length > 0) {
    console.log(`\n  Foreign documents skipped (never touched):`);
    for (const f of foreignSkips.slice(0, 20)) console.log(`    "${f.word}" — ${f.reason}`);
    if (foreignSkips.length > 20) console.log(`    ...and ${foreignSkips.length - 20} more.`);
  }
  if (errors.length > 0) {
    console.log(`\n  Errors reading existing documents:`);
    for (const e of errors.slice(0, 20)) console.log(`    "${e.word}" — ${e.message}`);
  }
  console.log(`\n--- topics plan ---`);
  console.log(`  new topics to create: ${topicWrites.length} / ${allTopics.size} total distinct topics`);

  if (dryRun) {
    console.log('\nDry run complete — no writes were made. Re-run with --yes to commit this plan.');
    return;
  }

  if (writesToCommit.length === 0 && topicWrites.length === 0) {
    console.log('\nNothing to write.');
    return;
  }

  console.log('\nCommitting writes...');
  const now = admin.firestore.FieldValue.serverTimestamp();

  for (const group of chunk(writesToCommit, FIRESTORE_BATCH_LIMIT)) {
    const batch = db.batch();
    for (const w of group) {
      if (w.isCreate) {
        batch.set(w.ref, { ...w.data, createdAt: now, updatedAt: now });
      } else {
        batch.set(w.ref, { ...w.data, updatedAt: now }, { merge: true });
      }
    }
    await batch.commit();
    console.log(`  committed a batch of ${group.length} vocabWords writes`);
  }

  for (const group of chunk(topicWrites, FIRESTORE_BATCH_LIMIT)) {
    const batch = db.batch();
    for (const t of group) {
      batch.set(t.ref, { name: t.name, createdBy: 'csvImport', createdAt: now });
    }
    await batch.commit();
    console.log(`  committed a batch of ${group.length} topics writes`);
  }

  console.log('\nDone.');
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exitCode = 1;
});
