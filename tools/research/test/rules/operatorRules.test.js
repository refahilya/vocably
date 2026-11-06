'use strict';

/**
 * Firestore security-rules tests for the Researcher Panel (`DATA_MODEL.md`
 * §6d): the operator record, stage windows, pretest/posttest authorization
 * (with the session-4 attestation and the placement-band acknowledgement),
 * technical void + retake, the audit log, the roster and the progress
 * mirror — and that students, ordinary guru accounts and revoked operators
 * can do none of it.
 *
 * The write shapes come from `test/fixtures/operator_client_payloads.json`,
 * which the Flutter test `test/research_panel_payloads_test.dart` checks
 * against the app's own payload builders, so this file exercises exactly
 * what the panel sends. Runs only inside `npm run test:rules`.
 */

const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const projectId = process.env.GCLOUD_PROJECT || '';
const RUN = /^(127\.0\.0\.1|localhost):\d+$/.test(emulatorHost) && projectId.startsWith('demo-');

const REPO_ROOT = path.join(__dirname, '..', '..', '..', '..');
const payloads = require('../fixtures/operator_client_payloads.json');
const TS = payloads.serverTimestampMarker;

describe('Researcher Panel rules (emulator)', { skip: !RUN && 'not inside the Firestore emulator (npm run test:rules)' }, () => {
  let rut;
  let fsdk;
  let env;
  let fixtures;

  const OP = 'opResearcher1';
  const GURU = 'guruBiasa001';
  const DAY = 24 * 60 * 60 * 1000;

  const db = (uid) => (uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore());
  const trusted = (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
  const tsAgo = (ms) => fsdk.Timestamp.fromMillis(Date.now() - ms);
  const tsLater = (ms) => fsdk.Timestamp.fromMillis(Date.now() + ms);

  /** Fixture values → SDK values: the timestamp marker and `{"$timestampMillisFromNow": n}`. */
  function materialize(v) {
    if (v === TS) return fsdk.serverTimestamp();
    if (Array.isArray(v)) return v.map(materialize);
    if (v && typeof v === 'object') {
      if ('$timestampMillisFromNow' in v) return tsLater(v.$timestampMillisFromNow);
      if ('$timestamp' in v) return fsdk.Timestamp.fromDate(new Date(v.$timestamp));
      return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, materialize(x)]));
    }
    return v;
  }

  /** `{{uid}}`-style placeholders in fixture strings. */
  function fill(value, vars) {
    if (typeof value === 'string' && /^\{\{\w+\}\}$/.test(value)) return vars[value.slice(2, -2)];
    if (typeof value === 'string') return value.replace(/\{\{(\w+)\}\}/g, (_, k) => String(vars[k]));
    if (Array.isArray(value)) return value.map((x) => fill(x, vars));
    if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, x]) => [fill(k, vars), fill(x, vars)]));
    return value;
  }

  /**
   * Commits one panel batch from the fixture: each write is
   * `{op: set|update, path: "col/id", data}`; update keys may be dotted
   * field paths (as the Dart `update()` map uses them).
   */
  function panelBatch(uid, name, vars, mutate = (w) => w) {
    const database = db(uid);
    const batch = fsdk.writeBatch(database);
    for (const raw of payloads.batches[name]) {
      const w = mutate(fill(raw, vars));
      if (!w) continue;
      const [col, id] = w.path.split('/');
      const ref = fsdk.doc(database, col, id);
      const data = materialize(w.data);
      if (w.op === 'set') batch.set(ref, data);
      else batch.update(ref, data);
    }
    return batch.commit();
  }

  async function seedUser(uid, role = 'siswa') {
    await trusted((t) => fsdk.setDoc(fsdk.doc(t, 'users', uid), { uid, email: `${uid}@example.test`, name: uid, role, createdAt: fsdk.Timestamp.now() }));
  }

  async function seedOperator(uid = OP, active = true) {
    await seedUser(uid, 'guru');
    await trusted((t) => fsdk.setDoc(fsdk.doc(t, 'researchOperators', uid), { email: `${uid}@example.test`, active, grantedAt: fsdk.Timestamp.now(), revokedAt: null }));
  }

  async function seedStudy({ status = 'active', stages } = {}) {
    const open = { openAt: tsAgo(DAY), closeAt: tsLater(DAY) };
    await trusted((t) =>
      fsdk.setDoc(fsdk.doc(t, 'researchStudy', 'current'), {
        status, closedAt: null, updatedAt: fsdk.Timestamp.now(),
        stages: stages || { placement: open, preTest: open, postTest: open },
      })
    );
  }

  async function seedBank() {
    const { buildInstrumentDocs } = require('../../lib/instrumentDocs');
    await trusted(async (t) => {
      for (const d of buildInstrumentDocs(fixtures.bank, fixtures.bankJson)) await fsdk.setDoc(fsdk.doc(t, 'researchInstrument', d.id), d.data);
    });
  }

  /** A participant banded by the research Placement Test (the only band source the tooling now creates). */
  async function seedParticipant(uid, { band = 'A2', pre = 0, post = 0, status = 'enrolled', bandSource = 'placement_test', extra = {} } = {}) {
    await seedUser(uid);
    await trusted((t) =>
      fsdk.setDoc(fsdk.doc(t, 'researchParticipants', uid), {
        researchId: `R-${uid}`, band: status === 'awaiting_placement' ? null : band, bandSource: status === 'awaiting_placement' ? null : bandSource,
        status, exclusionReason: null, placementAttemptId: status === 'awaiting_placement' ? null : `${uid}_research_1`,
        reviewStatus: null, instrumentVersion: 'v1',
        authorizedAttempts: { placement: 1, preTest: pre, postTest: post }, cohort: 'study',
        createdAt: fsdk.Timestamp.now(), updatedAt: fsdk.Timestamp.now(), ...extra,
      })
    );
  }

  async function seedAttempt(uid, { stage = 'preTest', n = 1, band = 'A2', status = 'in_progress', answered = 5 } = {}) {
    const a = fixtures.attempt({ uid, stage, n, band, status, answered });
    await trusted((t) => fsdk.setDoc(fsdk.doc(t, 'researchAssessmentResults', a.id), { ...a.data, startedAt: tsAgo(3600e3), updatedAt: tsAgo(1000), completedAt: status === 'completed' ? tsAgo(1000) : null }));
    return a.id;
  }

  /** The treatment completion record with sessions 1..[count] (`DATA_MODEL.md` §6e). */
  async function seedTreatment(uid, count) {
    const sessions = {};
    for (let n = 1; n <= count; n++) sessions[String(n)] = { sessionId: `ls${n}`, setId: `rt_t1_A2_s${n}_o1`, kind: 'regular', recordedAt: fsdk.Timestamp.now() };
    await trusted((t) => fsdk.setDoc(fsdk.doc(t, 'researchTreatment', uid), { studentId: uid, planVersion: 't1', sessions, lastRecorded: count, updatedAt: fsdk.Timestamp.now() }));
  }

  const getData = async (col, id) => {
    let data;
    await trusted(async (t) => {
      data = (await fsdk.getDoc(fsdk.doc(t, col, id))).data();
    });
    return data;
  };

  before(async () => {
    rut = require('@firebase/rules-unit-testing');
    fsdk = require('firebase/firestore');
    fixtures = require('../researchFixtures');
    env = await rut.initializeTestEnvironment({ projectId, firestore: { rules: fs.readFileSync(path.join(REPO_ROOT, 'firestore.rules'), 'utf8') } });
  });
  after(async () => {
    await env.cleanup();
  });
  beforeEach(async () => {
    await env.clearFirestore();
    await seedOperator();
    await seedUser(GURU, 'guru');
    await seedBank();
  });

  describe('operator record', () => {
    it('only the owner can read it; nobody can write it or list operators', async () => {
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db(OP), 'researchOperators', OP)));
      await rut.assertFails(fsdk.getDoc(fsdk.doc(db(GURU), 'researchOperators', OP)));
      await rut.assertFails(fsdk.getDocs(fsdk.collection(db(OP), 'researchOperators')));
      // Self-promotion and self-reactivation are impossible.
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db(GURU), 'researchOperators', GURU), { email: 'x', active: true, grantedAt: fsdk.serverTimestamp(), revokedAt: null }));
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(db(OP), 'researchOperators', OP), { active: true }));
      await rut.assertFails(fsdk.deleteDoc(fsdk.doc(db(OP), 'researchOperators', OP)));
    });
  });

  describe('read access', () => {
    beforeEach(async () => {
      await seedStudy();
      await seedParticipant('stuA00001');
      await trusted((t) => fsdk.setDoc(fsdk.doc(t, 'researchRoster', 'stuA00001'), { researchId: 'R-stuA00001', name: 'Siswa A', cohort: 'study', createdAt: fsdk.Timestamp.now() }));
      await seedAttempt('stuA00001');
    });

    it('the operator lists participants, roster, progress and audit log — never attempts, keys or reviews', async () => {
      const o = db(OP);
      await rut.assertSucceeds(fsdk.getDocs(fsdk.collection(o, 'researchParticipants')));
      await rut.assertSucceeds(fsdk.getDocs(fsdk.collection(o, 'researchRoster')));
      await rut.assertSucceeds(fsdk.getDocs(fsdk.collection(o, 'researchProgress')));
      await rut.assertSucceeds(fsdk.getDocs(fsdk.collection(o, 'researchAuditLog')));
      await rut.assertFails(fsdk.getDoc(fsdk.doc(o, 'researchAssessmentResults', 'stuA00001_preTest_1')));
      await rut.assertFails(fsdk.getDocs(fsdk.collection(o, 'researchAssessmentResults')));
      await rut.assertFails(fsdk.getDocs(fsdk.collection(o, 'placementAttempts')));
      await rut.assertFails(fsdk.getDoc(fsdk.doc(o, 'placementKey', 'PT-V1.1')));
      await rut.assertFails(fsdk.getDoc(fsdk.doc(o, 'researchInstrument', 'v1_A2')));
      await rut.assertFails(fsdk.getDocs(fsdk.collection(o, 'researchReviews')));
      await rut.assertFails(fsdk.getDoc(fsdk.doc(o, 'users', 'stuA00001')));
    });

    it('ordinary guru, students, revoked operators and signed-out users read none of it', async () => {
      await seedOperator('opRevoked01', false);
      for (const uid of [GURU, 'stuA00001', 'opRevoked01', null]) {
        const c = db(uid);
        await rut.assertFails(fsdk.getDocs(fsdk.collection(c, 'researchParticipants')));
        await rut.assertFails(fsdk.getDocs(fsdk.collection(c, 'researchRoster')));
        await rut.assertFails(fsdk.getDocs(fsdk.collection(c, 'researchProgress')));
        await rut.assertFails(fsdk.getDocs(fsdk.collection(c, 'researchAuditLog')));
        await rut.assertFails(fsdk.getDoc(fsdk.doc(c, 'researchRoster', 'stuA00001')));
      }
      // A student still reads their own participant record.
      await rut.assertSucceeds(fsdk.getDoc(fsdk.doc(db('stuA00001'), 'researchParticipants', 'stuA00001')));
    });
  });

  describe('stage windows', () => {
    const closed = () => ({ openAt: tsAgo(2 * DAY), closeAt: tsAgo(DAY) });
    const open = () => ({ openAt: tsAgo(DAY), closeAt: tsLater(DAY) });

    it('the operator opens a closed stage (open-ended or timed) and closes an open one, each with its audit entry', async () => {
      await seedStudy({ stages: { placement: closed(), preTest: closed() } });
      await rut.assertSucceeds(panelBatch(OP, 'openStage', { stage: 'preTest', seq: 1, operator: OP }));
      let s = await getData('researchStudy', 'current');
      assert.equal(s.operatorSeq, 1);
      assert.ok(s.stages.preTest.closeAt.toMillis() > Date.now() + 365 * DAY);
      const log = await getData('researchAuditLog', 'study_1');
      assert.equal(log.action, 'open_stage');
      assert.equal(log.operatorUid, OP);

      await rut.assertSucceeds(panelBatch(OP, 'closeStage', { stage: 'preTest', seq: 2, operator: OP }));
      s = await getData('researchStudy', 'current');
      assert.ok(s.stages.preTest.closeAt.toMillis() <= Date.now() + 1000);

      await rut.assertSucceeds(panelBatch(OP, 'openStageTimed', { stage: 'placement', seq: 3, operator: OP }));
      s = await getData('researchStudy', 'current');
      assert.ok(s.stages.placement.closeAt.toMillis() < Date.now() + DAY);
      // A never-opened stage can be opened too.
      await rut.assertSucceeds(panelBatch(OP, 'openStage', { stage: 'postTest', seq: 4, operator: OP }));
    });

    it('refuses: no audit entry, a reused sequence number, an open stage re-opened, a closed stage closed, two stages at once', async () => {
      await seedStudy({ stages: { preTest: closed(), postTest: open() } });
      await rut.assertFails(panelBatch(OP, 'openStage', { stage: 'preTest', seq: 1, operator: OP }, (w) => (w.path.startsWith('researchAuditLog') ? null : w)));
      await rut.assertFails(panelBatch(OP, 'openStage', { stage: 'preTest', seq: 2, operator: OP }));
      await rut.assertFails(panelBatch(OP, 'openStage', { stage: 'postTest', seq: 1, operator: OP }));
      await rut.assertFails(panelBatch(OP, 'closeStage', { stage: 'preTest', seq: 1, operator: OP }));
      await rut.assertFails(
        panelBatch(OP, 'openStage', { stage: 'preTest', seq: 1, operator: OP }, (w) =>
          w.path.startsWith('researchStudy') ? { ...w, data: { ...w.data, 'stages.placement': { openAt: TS, closeAt: { $timestampMillisFromNow: DAY } } } } : w
        )
      );
      // An opening in the past or a close-at in the past.
      await rut.assertFails(
        panelBatch(OP, 'openStage', { stage: 'preTest', seq: 1, operator: OP }, (w) =>
          w.path.startsWith('researchStudy') ? { ...w, data: { ...w.data, 'stages.preTest': { openAt: TS, closeAt: { $timestampMillisFromNow: -1000 } } } } : w
        )
      );
      await rut.assertSucceeds(panelBatch(OP, 'openStage', { stage: 'preTest', seq: 1, operator: OP }));
    });

    it('never touches the study status, and refuses a study that is not active', async () => {
      await seedStudy({ stages: { preTest: closed() } });
      await rut.assertFails(
        panelBatch(OP, 'openStage', { stage: 'preTest', seq: 1, operator: OP }, (w) => (w.path.startsWith('researchStudy') ? { ...w, data: { ...w.data, status: 'closed' } } : w))
      );
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(db(OP), 'researchStudy', 'current'), { status: 'closed' }));
      await seedStudy({ status: 'setup', stages: { preTest: closed() } });
      await rut.assertFails(panelBatch(OP, 'openStage', { stage: 'preTest', seq: 1, operator: OP }));
      await seedStudy({ status: 'closed', stages: { preTest: closed() } });
      await rut.assertFails(panelBatch(OP, 'openStage', { stage: 'preTest', seq: 1, operator: OP }));
    });

    it('ordinary guru, students and revoked operators cannot open or close anything', async () => {
      await seedStudy({ stages: { preTest: closed() } });
      await seedOperator('opRevoked01', false);
      await seedParticipant('stuA00001');
      for (const uid of [GURU, 'stuA00001', 'opRevoked01']) {
        await rut.assertFails(panelBatch(uid, 'openStage', { stage: 'preTest', seq: 1, operator: uid }));
      }
    });
  });

  describe('authorization', () => {
    beforeEach(async () => {
      await seedStudy();
    });

    it('pretest 0 → 1 for a placement-banded participant, with the acknowledgement recorded', async () => {
      await seedParticipant('stuA00001', { band: 'B1' });
      await rut.assertSucceeds(panelBatch(OP, 'authorizePreTest', { uid: 'stuA00001', operator: OP }));
      assert.equal((await getData('researchParticipants', 'stuA00001')).authorizedAttempts.preTest, 1);
      const log = await getData('researchAuditLog', 'authorize_preTest_stuA00001_1');
      assert.equal(log.placementPolicyAcknowledged, true);
      assert.equal(log.session4Confirmed, false);
      // Only once.
      await rut.assertFails(panelBatch(OP, 'authorizePreTest', { uid: 'stuA00001', operator: OP }));
    });

    it('refuses participants without a usable band, under review, excluded, and banks not seeded', async () => {
      await seedParticipant('stuWait001', { status: 'awaiting_placement' });
      await seedParticipant('stuExcl001', { status: 'excluded', extra: { band: null, bandSource: null, exclusionReason: 'placement_c1' } });
      await seedParticipant('stuCond001', { status: 'conditional', bandSource: 'manual_review' });
      await seedParticipant('stuRevw001', { extra: { reviewStatus: 'pending' } });
      for (const uid of ['stuWait001', 'stuExcl001', 'stuCond001', 'stuRevw001']) {
        await rut.assertFails(panelBatch(OP, 'authorizePreTest', { uid, operator: OP }));
      }
      await seedParticipant('stuBank001', { band: 'C1' });
      await trusted((t) => fsdk.deleteDoc(fsdk.doc(t, 'researchInstrument', 'v1_C1')));
      await rut.assertFails(panelBatch(OP, 'authorizePreTest', { uid: 'stuBank001', operator: OP }));
    });

    it('refuses a missing or false acknowledgement, a missing audit entry, and any other field change', async () => {
      await seedParticipant('stuA00001');
      const logOnly = (patch) => (w) => (w.path.startsWith('researchAuditLog') ? { ...w, data: { ...w.data, ...patch } } : w);
      await rut.assertFails(panelBatch(OP, 'authorizePreTest', { uid: 'stuA00001', operator: OP }, logOnly({ placementPolicyAcknowledged: false })));
      await rut.assertFails(panelBatch(OP, 'authorizePreTest', { uid: 'stuA00001', operator: OP }, logOnly({ operatorUid: GURU })));
      await rut.assertFails(panelBatch(OP, 'authorizePreTest', { uid: 'stuA00001', operator: OP }, (w) => (w.path.startsWith('researchAuditLog') ? null : w)));
      const participantPatch = (patch) => (w) => (w.path.startsWith('researchParticipants') ? { ...w, data: { ...w.data, ...patch } } : w);
      for (const patch of [{ band: 'C1' }, { status: 'excluded' }, { cohort: 'pilot' }, { 'authorizedAttempts.postTest': 1 }, { 'authorizedAttempts.preTest': 2 }, { reviewStatus: 'pending' }]) {
        await rut.assertFails(panelBatch(OP, 'authorizePreTest', { uid: 'stuA00001', operator: OP }, participantPatch(patch)));
      }
      await rut.assertSucceeds(panelBatch(OP, 'authorizePreTest', { uid: 'stuA00001', operator: OP }));
    });

    it('posttest needs the completed pretest, four recorded treatment sessions and the session-4 attestation', async () => {
      await seedParticipant('stuA00001', { pre: 1 });
      await seedAttempt('stuA00001', { status: 'in_progress', answered: 10 });
      await seedTreatment('stuA00001', 4);
      await rut.assertFails(panelBatch(OP, 'authorizePostTest', { uid: 'stuA00001', operator: OP }));
      await seedAttempt('stuA00001', { status: 'completed', answered: 20 });
      await seedTreatment('stuA00001', 3);
      await rut.assertFails(panelBatch(OP, 'authorizePostTest', { uid: 'stuA00001', operator: OP }), 'three sessions recorded');
      await seedTreatment('stuA00001', 4);
      await rut.assertFails(
        panelBatch(OP, 'authorizePostTest', { uid: 'stuA00001', operator: OP }, (w) => (w.path.startsWith('researchAuditLog') ? { ...w, data: { ...w.data, session4Confirmed: false } } : w))
      );
      await rut.assertSucceeds(panelBatch(OP, 'authorizePostTest', { uid: 'stuA00001', operator: OP }));
      const log = await getData('researchAuditLog', 'authorize_postTest_stuA00001_1');
      assert.equal(log.session4Confirmed, true);
      // A participant without a pretest authorization never gets a posttest.
      await seedParticipant('stuB00001');
      await rut.assertFails(panelBatch(OP, 'authorizePostTest', { uid: 'stuB00001', operator: OP }));
    });

    it('a legacy researcher-assigned band records no placement acknowledgement', async () => {
      await seedParticipant('stuOld0001', { bandSource: 'researcher_assigned' });
      await rut.assertFails(panelBatch(OP, 'authorizePreTest', { uid: 'stuOld0001', operator: OP }));
      await rut.assertSucceeds(
        panelBatch(OP, 'authorizePreTest', { uid: 'stuOld0001', operator: OP }, (w) => (w.path.startsWith('researchAuditLog') ? { ...w, data: { ...w.data, placementPolicyAcknowledged: false } } : w))
      );
    });

    it('ordinary guru, students (even for themselves) and revoked operators cannot authorize', async () => {
      await seedParticipant('stuA00001');
      await seedOperator('opRevoked01', false);
      for (const uid of [GURU, 'stuA00001', 'opRevoked01']) {
        await rut.assertFails(panelBatch(uid, 'authorizePreTest', { uid: 'stuA00001', operator: uid }));
      }
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(db('stuA00001'), 'researchParticipants', 'stuA00001'), { 'authorizedAttempts.preTest': 1, updatedAt: fsdk.serverTimestamp() }));
    });

    it('an audit entry cannot be written on its own, edited or deleted', async () => {
      await seedParticipant('stuA00001');
      const stray = payloads.batches.authorizePreTest.find((w) => w.path.startsWith('researchAuditLog'));
      const w = fill(stray, { uid: 'stuA00001', operator: OP });
      const [col, id] = w.path.split('/');
      await rut.assertFails(fsdk.setDoc(fsdk.doc(db(OP), col, id), materialize(w.data)));
      await rut.assertSucceeds(panelBatch(OP, 'authorizePreTest', { uid: 'stuA00001', operator: OP }));
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(db(OP), col, id), { reason: 'x' }));
      await rut.assertFails(fsdk.deleteDoc(fsdk.doc(db(OP), col, id)));
    });
  });

  describe('technical void and retake', () => {
    beforeEach(async () => {
      await seedStudy();
    });

    it('voids the unfinished attempt (answers kept) and authorizes attempt 2 in one batch', async () => {
      await seedParticipant('stuA00001', { pre: 1 });
      const id = await seedAttempt('stuA00001', { answered: 7 });
      const before = await getData('researchAssessmentResults', id);
      await rut.assertSucceeds(panelBatch(OP, 'voidAndRetake', { uid: 'stuA00001', stage: 'preTest', n: 1, next: 2, operator: OP }));
      const a = await getData('researchAssessmentResults', id);
      assert.equal(a.status, 'voided');
      assert.equal(a.voidReason, 'technical_interruption');
      assert.deepEqual(a.responses, before.responses);
      assert.equal((await getData('researchParticipants', 'stuA00001')).authorizedAttempts.preTest, 2);
      assert.ok(await getData('researchAuditLog', `void_${id}`));
      assert.ok(await getData('researchAuditLog', 'retake_preTest_stuA00001_2'));
      // The voided attempt is frozen for the student, and attempt 2 can be created.
      const fresh = fixtures.attempt({ uid: 'stuA00001', stage: 'preTest', n: 2, band: 'A2', status: 'in_progress', answered: 0 });
      await rut.assertSucceeds(
        fsdk.setDoc(fsdk.doc(db('stuA00001'), 'researchAssessmentResults', fresh.id), {
          ...fresh.data, startedAt: fsdk.serverTimestamp(), updatedAt: fsdk.serverTimestamp(), completedAt: null,
        })
      );
    });

    it('a retake after an earlier (tooling) void needs no void in the batch', async () => {
      await seedParticipant('stuA00001', { pre: 1 });
      await seedAttempt('stuA00001', { status: 'voided', answered: 3 });
      await rut.assertSucceeds(panelBatch(OP, 'retakeOnly', { uid: 'stuA00001', stage: 'preTest', n: 1, next: 2, operator: OP }));
    });

    it('refuses: completed attempts, superseded attempts, a pretest after the posttest is authorized, a retake of a live attempt, free-text reasons', async () => {
      await seedParticipant('stuDone001', { pre: 1 });
      await seedAttempt('stuDone001', { status: 'completed', answered: 20 });
      await rut.assertFails(panelBatch(OP, 'voidAndRetake', { uid: 'stuDone001', stage: 'preTest', n: 1, next: 2, operator: OP }));

      await seedParticipant('stuPost001', { pre: 1, post: 1 });
      await seedAttempt('stuPost001', { answered: 4 });
      await rut.assertFails(panelBatch(OP, 'voidAndRetake', { uid: 'stuPost001', stage: 'preTest', n: 1, next: 2, operator: OP }));

      await seedParticipant('stuOld0001', { pre: 2 });
      await seedAttempt('stuOld0001', { n: 1, answered: 4 });
      await rut.assertFails(panelBatch(OP, 'voidAndRetake', { uid: 'stuOld0001', stage: 'preTest', n: 1, next: 2, operator: OP }));

      await seedParticipant('stuLive001', { pre: 1 });
      await seedAttempt('stuLive001', { answered: 4 });
      await rut.assertFails(panelBatch(OP, 'retakeOnly', { uid: 'stuLive001', stage: 'preTest', n: 1, next: 2, operator: OP }));
      await rut.assertFails(
        panelBatch(OP, 'voidAndRetake', { uid: 'stuLive001', stage: 'preTest', n: 1, next: 2, operator: OP }, (w) =>
          w.path.startsWith('researchAssessmentResults') ? { ...w, data: { ...w.data, voidReason: 'Siswa X menyontek' } } : w
        )
      );
      // A void may never change an answer.
      await rut.assertFails(
        panelBatch(OP, 'voidAndRetake', { uid: 'stuLive001', stage: 'preTest', n: 1, next: 2, operator: OP }, (w) =>
          w.path.startsWith('researchAssessmentResults') ? { ...w, data: { ...w.data, responses: {} } } : w
        )
      );
      await rut.assertSucceeds(panelBatch(OP, 'voidAndRetake', { uid: 'stuLive001', stage: 'preTest', n: 1, next: 2, operator: OP }));
    });

    it('a posttest void + retake works the same way', async () => {
      await seedParticipant('stuA00001', { pre: 1, post: 1 });
      await seedAttempt('stuA00001', { stage: 'preTest', status: 'completed', answered: 20 });
      await seedAttempt('stuA00001', { stage: 'postTest', answered: 2 });
      await rut.assertSucceeds(panelBatch(OP, 'voidAndRetake', { uid: 'stuA00001', stage: 'postTest', n: 1, next: 2, operator: OP }));
    });

    it('ordinary guru, students and revoked operators cannot void or retake', async () => {
      await seedParticipant('stuA00001', { pre: 1 });
      await seedAttempt('stuA00001', { answered: 4 });
      await seedOperator('opRevoked01', false);
      for (const uid of [GURU, 'stuA00001', 'opRevoked01']) {
        await rut.assertFails(panelBatch(uid, 'voidAndRetake', { uid: 'stuA00001', stage: 'preTest', n: 1, next: 2, operator: uid }));
      }
    });
  });

  describe('progress mirror', () => {
    beforeEach(async () => {
      await seedStudy();
    });

    const mirror = (uid, stage, n, answered, total, status) => ({
      studentId: uid, stage, attemptNumber: n, answered, total, status, updatedAt: fsdk.serverTimestamp(),
    });

    it('a student mirrors exactly their own attempt (counts and status, never answers)', async () => {
      await seedParticipant('stuA00001', { pre: 1 });
      const id = await seedAttempt('stuA00001', { answered: 6 });
      const ref = (uid) => fsdk.doc(db(uid), 'researchProgress', id);
      await rut.assertSucceeds(fsdk.setDoc(ref('stuA00001'), mirror('stuA00001', 'preTest', 1, 6, 20, 'in_progress')));
      await rut.assertFails(fsdk.setDoc(ref('stuA00001'), mirror('stuA00001', 'preTest', 1, 7, 20, 'in_progress')));
      await rut.assertFails(fsdk.setDoc(ref('stuA00001'), mirror('stuA00001', 'preTest', 1, 6, 20, 'completed')));
      await rut.assertFails(fsdk.setDoc(ref('stuA00001'), { ...mirror('stuA00001', 'preTest', 1, 6, 20, 'in_progress'), responses: {} }));
      await rut.assertFails(fsdk.setDoc(ref('stuA00001'), mirror('stuA00001', 'postTest', 1, 6, 20, 'in_progress')));
      // Someone else's attempt, and reading the mirror back.
      await seedParticipant('stuB00001', { pre: 1 });
      await rut.assertFails(fsdk.setDoc(ref('stuB00001'), mirror('stuB00001', 'preTest', 1, 6, 20, 'in_progress')));
      await rut.assertFails(fsdk.getDoc(ref('stuA00001')));
      await rut.assertFails(fsdk.deleteDoc(ref('stuA00001')));
    });

    it('a research placement attempt is mirrored; a learning attempt is not', async () => {
      await seedParticipant('stuP00001', { status: 'awaiting_placement' });
      const attempt = (context) => ({
        studentId: 'stuP00001', context, attemptNumber: 1, instrumentVersion: 'PT-V1.1', itemOrder: [], answers: { 'A1-01': 'A', 'A1-02': 'E' },
        lastAnsweredItemId: 'A1-02', tabSwitchCount: 0, status: 'in_progress', startedAt: tsAgo(1000), updatedAt: tsAgo(1000),
      });
      await trusted(async (t) => {
        await fsdk.setDoc(fsdk.doc(t, 'placementAttempts', 'stuP00001_research_1'), attempt('research'));
        await fsdk.setDoc(fsdk.doc(t, 'placementAttempts', 'stuP00001_learning_1'), attempt('learning'));
      });
      const c = db('stuP00001');
      await rut.assertSucceeds(fsdk.setDoc(fsdk.doc(c, 'researchProgress', 'stuP00001_research_1'), mirror('stuP00001', 'placement', 1, 2, 50, 'in_progress')));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(c, 'researchProgress', 'stuP00001_research_1'), mirror('stuP00001', 'placement', 1, 2, 20, 'in_progress')));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(c, 'researchProgress', 'stuP00001_learning_1'), mirror('stuP00001', 'placement', 1, 2, 50, 'in_progress')));
    });

    it('nobody but the student writes a mirror — not even the operator', async () => {
      await seedParticipant('stuA00001', { pre: 1 });
      const id = await seedAttempt('stuA00001', { answered: 6 });
      for (const uid of [OP, GURU]) {
        await rut.assertFails(fsdk.setDoc(fsdk.doc(db(uid), 'researchProgress', id), mirror('stuA00001', 'preTest', 1, 6, 20, 'in_progress')));
      }
    });
  });

  describe('roster', () => {
    it('nobody writes the roster from a client — not even the operator', async () => {
      for (const uid of [OP, GURU, 'stuA00001']) {
        await rut.assertFails(fsdk.setDoc(fsdk.doc(db(uid), 'researchRoster', 'stuA00001'), { researchId: 'R', name: 'X', cohort: 'study', createdAt: fsdk.serverTimestamp() }));
      }
    });
  });

  describe('the operator gains nothing else', () => {
    it('no band, enrolment, review, key, bank, study-status or user-role writes', async () => {
      await seedStudy();
      await seedParticipant('stuA00001');
      await seedParticipant('stuWait001', { status: 'awaiting_placement' });
      const o = db(OP);
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(o, 'researchParticipants', 'stuWait001'), { band: 'B2', bandSource: 'placement_test', status: 'enrolled', updatedAt: fsdk.serverTimestamp() }));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(o, 'researchParticipants', 'stuNew0001'), { researchId: 'R', band: 'A2' }));
      await rut.assertFails(fsdk.deleteDoc(fsdk.doc(o, 'researchParticipants', 'stuA00001')));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(o, 'researchReviews', 'x'), { uid: 'stuA00001' }));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(o, 'placementKey', 'PT-V1.1'), { key: {} }));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(o, 'researchInstrument', 'v1_A2'), {}));
      await rut.assertFails(fsdk.setDoc(fsdk.doc(o, 'placementConfig', 'current'), { learningOpen: true }));
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(o, 'users', OP), { role: 'siswa' }));
      await rut.assertFails(fsdk.updateDoc(fsdk.doc(o, 'users', 'stuA00001'), { name: 'x' }));
    });
  });
});
