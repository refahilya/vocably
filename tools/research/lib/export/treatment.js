'use strict';

/**
 * Treatment-implementation (fidelity) export (`DATA_MODEL.md` §6e): per
 * participant and official session, whether and how it was completed, and
 * every ordinary learning session that contained the participant's
 * instrument words (prior or parallel exposure).
 *
 * Pure: takes plain JSON (timestamps as ISO strings) and returns rows.
 * Analysis files carry the pseudonymous research ID only; co-write text is
 * never exported — only counts (turns, suggestions, words used). UIDs and
 * document IDs appear only in the operational problems file.
 */

const TREATMENT_COLUMNS = {
  'treatment_sessions.csv': [
    'research_id', 'band', 'cohort', 'session', 'words', 'status', 'via', 'opening', 'marked_present_regular',
    'set_opened_at', 'set_closes_at', 'attempts', 'started_at', 'completed_at', 'minutes', 'completed_after_window',
    'cloze_correct', 'cloze_total', 'student_turns', 'suggestion_turns', 'independent_words', 'recorded_by',
  ],
  'treatment_attempts.csv': [
    'research_id', 'band', 'session', 'via', 'opening', 'started_at', 'completed_at', 'phase_reached',
    'set_closes_at', 'completed_after_window', 'cloze_correct', 'student_turns', 'recorded',
  ],
  'treatment_exposure.csv': [
    'research_id', 'band', 'started_at', 'source_type', 'phase_reached', 'period', 'instrument_words_count', 'instrument_words',
  ],
  'treatment_summary.csv': [
    'research_id', 'band', 'cohort', 'status', 'sessions_completed', 'sessions_list', 'all_four_completed',
    'four_completed_before_posttest', 'makeup_used', 'makeup_session', 'reopened_sessions', 'completed_after_window_count',
    'posttest_authorized', 'posttest_started_at', 'exposure_before_pretest_sessions', 'exposure_before_pretest_words',
    'exposure_during_treatment_sessions', 'exposure_during_treatment_words',
  ],
  'treatment_operational_problems.csv': ['category', 'reference', 'detail'],
};

const SESSIONS = [1, 2, 3, 4];
const ms = (iso) => (iso ? Date.parse(iso) : NaN);
const yesNo = (b) => (b ? 'yes' : 'no');

function attemptTimes(attempts, uid, stage, n) {
  const a = n >= 1 ? attempts.get(`${uid}_${stage}_${n}`) : null;
  return a ? { status: a.status, startedAt: a.startedAt || null, completedAt: a.completedAt || null } : null;
}

/** 'before_pretest' | 'during_treatment' | 'after_posttest' for a start time. */
function periodOf(startedAt, preCompletedAt, postStartedAt) {
  const t = ms(startedAt);
  if (!preCompletedAt || !(t >= ms(preCompletedAt))) return 'before_pretest';
  if (postStartedAt && t >= ms(postStartedAt)) return 'after_posttest';
  return 'during_treatment';
}

function counts(s) {
  const cloze = s.clozeTestResult || {};
  const turns = (s.cowriteTranscript || []).filter((t) => t && t.sender === 'siswa');
  return {
    cloze_correct: Object.values(cloze).filter((v) => v === true).length,
    cloze_total: Object.keys(cloze).length,
    student_turns: turns.length,
    suggestion_turns: turns.filter((t) => t.usedSuggestion === true).length,
    independent_words: (s.cowriteWordsUsedCorrectly || []).length,
  };
}

/**
 * [participants]: `[{uid, data}]`; [plans]: plan docs `[{band, sessions}]`
 * of the active version; [sets]: `[{id, data}]` research session sets;
 * [sessions]: `[{id, data}]` learning sessions of participants;
 * [records]: `[{uid, data}]`; [attempts]: `[{id, data}]` pretest/posttest
 * attempts (only status and timestamps are used).
 */
function buildTreatmentExport({ participants, plans, sets, sessions, records, attempts, planVersion, cohort = null }) {
  const planByBand = new Map(plans.map((p) => [p.band, p]));
  const setById = new Map(sets.filter((s) => !planVersion || (s.data.research || {}).planVersion === planVersion).map((s) => [s.id, s.data]));
  const recordByUid = new Map(records.map((r) => [r.uid, r.data]));
  const attemptById = new Map(attempts.map((a) => [a.id, a.data]));
  const sessionsByUid = new Map();
  for (const s of sessions) {
    const list = sessionsByUid.get(s.data.studentId) || [];
    list.push(s);
    sessionsByUid.set(s.data.studentId, list);
  }
  const people = participants.filter((p) => !cohort || p.data.cohort === cohort);
  const known = new Set(participants.map((p) => p.uid));
  const out = { sessionRows: [], attemptRows: [], exposureRows: [], summaryRows: [], problems: [] };

  for (const { uid, data: p } of people) {
    const band = p.band || null;
    const researchId = p.researchId;
    const plan = band ? planByBand.get(band) : null;
    const record = recordByUid.get(uid) || { sessions: {} };
    const recorded = record.sessions || {};
    const pre = attemptTimes(attemptById, uid, 'preTest', (p.authorizedAttempts || {}).preTest || 0);
    const post = attemptTimes(attemptById, uid, 'postTest', (p.authorizedAttempts || {}).postTest || 0);
    const preCompletedAt = pre && pre.status === 'completed' ? pre.completedAt : null;
    const postStartedAt = post ? post.startedAt : null;
    const own = sessionsByUid.get(uid) || [];
    const official = own.filter((s) => Number.isInteger(s.data.researchSession));
    const makeup = setById.get(`rtm_${uid}`) || null;

    let completedCount = 0;
    let afterWindow = 0;
    let lastCompletion = null;
    const done = [];
    const reopened = [];

    for (const n of SESSIONS) {
      const tries = official.filter((s) => s.data.researchSession === n).sort((a, b) => ms(a.data.startedAt) - ms(b.data.startedAt));
      const entry = recorded[String(n)] || null;
      const chosen = entry
        ? tries.find((s) => s.id === entry.sessionId) || null
        : tries.find((s) => s.data.currentPhase === 'selesai') || tries[tries.length - 1] || null;
      if (entry && !chosen) out.problems.push({ category: 'record_without_session', reference: uid, detail: `session ${n} → ${entry.sessionId}` });
      const set = chosen ? setById.get(chosen.data.targetWordSetId) || null : null;
      const regularPresent = [...setById.entries()].some(
        ([, d]) => d.research && d.research.kind === 'regular' && d.research.band === band && d.research.session === n && (d.targetStudentIds || []).includes(uid)
      );
      const completed = chosen && chosen.data.currentPhase === 'selesai';
      const status = entry ? 'completed' : completed ? 'completed_unrecorded' : chosen ? 'started_not_completed' : regularPresent || (makeup && makeup.research.session === n) ? 'opened_not_started' : 'not_opened_for_student';
      if (status === 'completed_unrecorded') {
        out.problems.push({ category: 'completed_unrecorded', reference: uid, detail: `session ${n} learning session ${chosen.id} (run treatment-record)` });
      }
      const late = Boolean(completed && set && ms(chosen.data.completedAt) > ms(set.endAt));
      if (entry) {
        completedCount++;
        done.push(n);
        if (late) afterWindow++;
        if (set && set.research.opening > 1) reopened.push(n);
        if (chosen && chosen.data.completedAt && (!lastCompletion || ms(chosen.data.completedAt) > ms(lastCompletion))) lastCompletion = chosen.data.completedAt;
      }
      const c = chosen ? counts(chosen.data) : {};
      out.sessionRows.push({
        research_id: researchId,
        band,
        cohort: p.cohort,
        session: n,
        words: plan && plan.sessions && plan.sessions[String(n)] ? plan.sessions[String(n)].join(' ') : '',
        status,
        via: set ? set.research.kind : '',
        opening: set ? set.research.opening : '',
        marked_present_regular: yesNo(regularPresent),
        set_opened_at: set ? set.startAt : '',
        set_closes_at: set ? set.endAt : '',
        attempts: tries.length,
        started_at: chosen ? chosen.data.startedAt : '',
        completed_at: completed ? chosen.data.completedAt : '',
        minutes: completed ? Math.round((ms(chosen.data.completedAt) - ms(chosen.data.startedAt)) / 6000) / 10 : '',
        completed_after_window: completed && set ? yesNo(late) : '',
        cloze_correct: c.cloze_correct ?? '',
        cloze_total: c.cloze_total ?? '',
        student_turns: c.student_turns ?? '',
        suggestion_turns: c.suggestion_turns ?? '',
        independent_words: c.independent_words ?? '',
        recorded_by: entry ? entry.recordedBy || 'app' : '',
      });
      for (const t of tries) {
        const tSet = setById.get(t.data.targetWordSetId) || null;
        const tDone = t.data.currentPhase === 'selesai';
        out.attemptRows.push({
          research_id: researchId,
          band,
          session: n,
          via: tSet ? tSet.research.kind : '',
          opening: tSet ? tSet.research.opening : '',
          started_at: t.data.startedAt,
          completed_at: tDone ? t.data.completedAt : '',
          phase_reached: t.data.currentPhase,
          set_closes_at: tSet ? tSet.endAt : '',
          completed_after_window: tDone && tSet ? yesNo(ms(t.data.completedAt) > ms(tSet.endAt)) : '',
          cloze_correct: counts(t.data).cloze_correct,
          student_turns: counts(t.data).student_turns,
          recorded: yesNo(entry && entry.sessionId === t.id),
        });
      }
    }

    // Ordinary learning sessions with this band's instrument words.
    const instrumentWords = new Set(plan && plan.sessions ? Object.values(plan.sessions).flat() : []);
    const exposure = { before_pretest: { sessions: 0, words: new Set() }, during_treatment: { sessions: 0, words: new Set() } };
    for (const s of own.filter((x) => !Number.isInteger(x.data.researchSession)).sort((a, b) => ms(a.data.startedAt) - ms(b.data.startedAt))) {
      const hit = (s.data.wordIds || []).filter((w) => instrumentWords.has(w));
      if (!hit.length) continue;
      const period = periodOf(s.data.startedAt, preCompletedAt, postStartedAt);
      if (exposure[period]) {
        exposure[period].sessions++;
        hit.forEach((w) => exposure[period].words.add(w));
      }
      out.exposureRows.push({
        research_id: researchId,
        band,
        started_at: s.data.startedAt,
        source_type: s.data.sourceType,
        phase_reached: s.data.currentPhase,
        period,
        instrument_words_count: hit.length,
        instrument_words: hit.join(' '),
      });
    }

    const four = completedCount === SESSIONS.length;
    out.summaryRows.push({
      research_id: researchId,
      band,
      cohort: p.cohort,
      status: p.status || 'enrolled',
      sessions_completed: completedCount,
      sessions_list: done.join(' '),
      all_four_completed: yesNo(four),
      four_completed_before_posttest: !four ? 'no' : postStartedAt ? yesNo(ms(lastCompletion) <= ms(postStartedAt)) : 'posttest_not_started',
      makeup_used: yesNo(Boolean(makeup)),
      makeup_session: makeup ? makeup.research.session : '',
      reopened_sessions: reopened.join(' '),
      completed_after_window_count: afterWindow,
      posttest_authorized: yesNo(((p.authorizedAttempts || {}).postTest || 0) > 0),
      posttest_started_at: postStartedAt || '',
      exposure_before_pretest_sessions: exposure.before_pretest.sessions,
      exposure_before_pretest_words: exposure.before_pretest.words.size,
      exposure_during_treatment_sessions: exposure.during_treatment.sessions,
      exposure_during_treatment_words: exposure.during_treatment.words.size,
    });
  }

  for (const s of sessions) {
    if (Number.isInteger(s.data.researchSession) && !known.has(s.data.studentId)) {
      out.problems.push({ category: 'official_session_without_participant', reference: s.id, detail: s.data.studentId });
    }
  }
  out.summaryRows.sort((a, b) => String(a.research_id).localeCompare(String(b.research_id)));
  return out;
}

module.exports = { buildTreatmentExport, TREATMENT_COLUMNS, periodOf };
