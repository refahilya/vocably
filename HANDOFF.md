# Vocably — Handoff Briefing

**This is a current-moment orientation document, not an ongoing log.**
Read this once at the start of a new session, then work from the
authoritative documents it points to. Unlike `PROJECT_STATE.md` (an
append-only chronological record), this file describes *only* where
things stand right now — it can be deleted or fully rewritten once its
contents are absorbed, without losing project history.

## 1. Purpose / How to Use This Handoff

- **`CLAUDE.md`** remains authoritative for coding conventions, tech
  stack, and hard project rules — read it in full every session, per its
  own header.
- **`SPEC.md`** remains authoritative for product/functional behavior
  (Co-Write: §5.3).
- **`DATA_MODEL.md`** remains authoritative for the Firestore schema and
  the Worker's request/response contracts (`/cowrite-turn`: §10.2).
- **`PROJECT_STATE.md`** remains the authoritative chronological project
  log — this file summarizes its *current* tail (§5o, §5p).

**Ground-truth hierarchy** — when any two sources disagree, trust in
this order:

```
repository code & tests  >  git state  >  verified deployment state  >  HANDOFF.md
    >  PROJECT_STATE.md / SPEC.md / DATA_MODEL.md  >  prior conversation
```

Verify any claim here that matters to your task against the source,
`git log`/`git status`, and deployment state before relying on it.

## 2. Current Project Position (2026-10-15)

- **Milestones 1–8 are complete and committed** (`1f2b606` for
  Milestone 8). Post-Milestone-8 fixes are committed: `56ded8b`,
  `34a9c4b`, and the cloze positional-leakage fix `fa4d52c` (Flutter) /
  `6239f7e` (Worker).
- **Deployment reality:**
  - The Flutter web app is **not hosted**: `firebase.json` has no
    `"hosting"` block.
  - **The Worker is deployed** as version `0bec79ee-2958-475e-97fe-64ababf31c9c`
    (2026-10-15T17:08Z UTC), including all Co-Write Worker work (Phase
    1/2, CW-05, Indonesian input, CW-02). It was deployed **from the
    uncommitted working tree**, so the deployed code matches no commit
    (`PROJECT_STATE.md` §5t).
  - Milestone 8's `firestore.rules` change is committed but not deployed.
- **Co-Write remediation is implemented in uncommitted working trees in
  both repos, and is NOT committed.**
  - The Worker side is deployed. The Flutter side runs only locally,
    because nothing is hosted.
  - Automated tests pass.
  - The owner reported a satisfactory local manual E2E of CW-02.
  - Production verification covered CORS, auth and routing only, with
    no authenticated Co-Write request.

| | |
|---|---|
| **Confirmed** (run 2026-10-15 on the working trees) | `flutter analyze` 0 issues; `flutter test --concurrency=1` **467/467**; `flutter build web --release --dart-define=WORKER_BASE_URL=…` succeeds; Worker `npx vitest run --fileParallelism=false` **148/148**, `npx tsc --noEmit` clean |
| **Worker deployment** (2026-10-16) | `0bec79ee-2958-475e-97fe-64ababf31c9c` at 100%, confirmed via `wrangler deployments list`; production CORS, auth and routing smoke tests passed (`PROJECT_STATE.md` §5t) |
| **Not verified** | Chrome E2E of Co-Write against the production Worker (incl. the Bug A physical-keyboard fix); real-LLM output quality in production (feedback accuracy, non-echo continuations, forced-word sentences). The owner reported a satisfactory **local** manual CW-02 E2E |
| **Known gaps** | No `"hosting"` block; Milestone 8 rules undeployed; student demographics (class/NISN) not in `users`; Placement Test / Pre-Post-Test instruments are placeholders (TBD) |

## 3. Co-Write — Authoritative Behavior (Phase 2)

Product rules are in `SPEC.md` §5.3. In short:

- **Valid usage (CW-05):** a target word counts when the student uses it
  **meaningfully, with an acceptable intended meaning**. Vocably credits
  vocabulary, not grammatical perfection:
  - Grammar, tense, and agreement errors — including a wrong inflection of
    the target itself ("Yesterday the monster attack the village.") —
    don't remove credit. They may still get feedback and `hasError`.
  - Bare words, lists, fragments, mere mentions ("I do not know the word
    attack."), nonsense, and wrong meanings never count.
  - Division of work: the model judges meaning, and deterministic code has
    the final say (`lib/utils/cowrite_validator.dart`, mirrored in
    `vocably-ai-worker/src/cowriteValidator.ts`). The code maps a
    model-reported form (`attacked`, `"ATTACKS"`) to its remaining base
    target, then requires it to appear in the student's text as a valid
    inflection.
  - Over-inflections like `attackked` are rejected.
  - In the Worker, a bot-sentence retry never replaces the first
    attempt's student assessment.
- **"Tanpa kesalahan" in the mastery rule** means acceptable meaning and
  usage of the target word, not an error-free sentence.
- **Indonesian / mixed-language turns (2026-10-15):** the app, not the LLM,
  classifies each student turn with the deterministic
  `containsIndonesianWords` (Dart, mirrored in TypeScript) and sends
  `studentTurnContainsIndonesian` to the Worker.
  - For a flagged turn, feedback is one short, polite Indonesian reminder
    to write in English.
  - A validated target word in a flagged turn (e.g. `attack` in "aku
    attack temanku") counts for **session coverage** and resets the miss
    counter, but **never** for independent mastery.
  - Every bot sentence (ordinary or fallback) must be English and stay in
    the story, never answering off-topic questions, calculations, or
    requests. The Worker retries an `aiTurn` it detects as Indonesian.
- **Session coverage vs. independent mastery:** `allWordsUsedCorrectly`
  holds every validly used word: the student's own, suggestion-assisted,
  mixed-language, and bot fallback words. `independentWordsUsedCorrectly`
  holds only the student's own English, non-suggestion uses. Only the
  latter is persisted as `cowriteWordsUsedCorrectly`.
- **Local rejection:** only inputs that *contain a target word* and are
  bare/fragment/list are rejected. A rejected input never reaches the
  transcript or the Worker and doesn't change the counter. `"Okay."` is an
  ordinary turn.
- **Fallback:** the app's `consecutiveMissedStudentTurns` counter reaches
  3 → the app randomly picks exactly one remaining word → the Worker
  generates a forced-word turn → the word is credited only if the client
  detects it in that text. A failed fallback credits nothing and retries
  on the next missed turn. The counter resets on valid student usage or a
  successful fallback.
- **Bot usage:** a validated fallback word counts at **session level**
  (`allWordsUsedCorrectly`, pills, auto-stop). It **never** counts toward
  `independentWordsUsedCorrectly` / persisted `cowriteWordsUsedCorrectly`
  / mastery. Incidental target words in ordinary AI turns are never
  credited.
- **Feedback** assesses only the current student sentence (sent
  separately from the story context; `assessedStudentTurn` is echoed and
  checked by the client). It is written in Indonesian.
  - **CW-02 priority:** a credited target word is acknowledged
    specifically; an attempted but uncredited one gets the real issue
    explained; no target word gets a gentle nudge.
  - At most one important grammar or meaning point is mentioned.
    Capitalization, punctuation, and apostrophes are ignored.
  - If the model claimed words but code credited none, the feedback is
    replaced by a fixed neutral message. This happens in the Worker and,
    for an older Worker, in the client too.
- **Feedback indicator (display only):** ✓ green "Sudah tepat", 💡 amber
  "Perlu perbaikan", or 💬 blue "Pengingat".
  - It's derived by `classifyCowriteFeedback` from code-validated credit,
    `hasError`, whether a target word occurs in the text, and the language
    flag. It never comes from the feedback's wording.
  - It's stored in the in-memory `CowriteTurn.feedbackKind`. It isn't
    persisted (`toMap` is unchanged) and never affects coverage, the
    counter, or mastery.
- **Unacceptable continuation:** if neither ordinary attempt yields an
  acceptable `aiTurn`, the Worker answers 502. The client rolls back the
  student turn and shows "Gagal mengirim giliran. Coba lagi.".
- **Known UX limitation:** when the fallback is due, a turn's feedback
  appears only after the forced-word call finishes. It's still attached
  to the correct turn.
- **Suggestions:** the Worker returns the English sentence only; the client
  shows `Coba tulis "<sentence>"`.

## 4. Architecture Walkthrough (Cowrite path, current source)

```
Student types a turn → cowrite_screen.dart (_ComposeBar)
  → LearningFlowController.sendTurn()          [learning_session_controller.dart]
      - shouldRejectStudentTurnLocally()        [utils/cowrite_validator.dart]
        (rejected: turnError, draft + focus kept, nothing else changes)
      - optimistic student bubble
      - AiWorkerService.cowriteTurn()           → POST /cowrite-turn (ordinary mode)
          Worker: storySoFar + currentStudentTurn → model → validateStudentTargetWords,
                  uncredited-claim feedback replacement,
                  anti-echo / no-target-word / English checks, ≤2 generations
                  (no acceptable aiTurn → 502);
                  returns feedback, wordsUsedCorrectly, aiTurn, aiUsedWords: [],
                  assessedStudentTurn
      - drop if flow restarted (_flowEpoch); fail if assessedStudentTurn mismatches
      - validateStudentTargetWords (eligible = words remaining before the turn)
      - reconcileCowriteFeedback + classifyCowriteFeedback [utils/cowrite_feedback.dart]
        → feedback + in-memory feedbackKind for THIS turn only
      - counter: 0 if a word was validly used, else +1
      - no words remain → done, no AI bubble
      - counter ≥ 3 → selectFallbackWord (cowriteFallbackRandomProvider)
          → AiWorkerService.cowriteForcedTurn() → POST /cowrite-turn {forcedWord}
              Worker: forced prompt; accepts only if the word is in aiTurn, no other
                      remaining word, not an echo; ≤2 generations, else 502
          → validateBotTargetWords(claimed: [], text, [forcedWord]) → credit + reset,
            otherwise keep the ordinary aiTurn and leave the counter at ≥3
      - else ordinary aiTurn shown, credits nothing
      - allWordsUsedCorrectly ∪= student + validated bot words
        independentWordsUsedCorrectly ∪= student words (not on suggestion turns)
      - saveCowriteTranscript (every turn)
"Saran menulis" → requestSuggestion() → POST /cowrite-turn {requestSuggestion: true}
      → bare English sentence → UI: 'Coba tulis "…"' (blocked while sending, and vice versa)
"✓ Selesai" → completeCowrite() (guarded by isCompletingCowrite)
      → completeSession + recordCowriteCompletion with the independent set only
```

**Responsibility split:**
- **Flutter client:** every decision — counter, fallback timing, word
  selection, validation of student and bot text, word status, bubble
  display, completion, and all Firestore writes.
- **Worker:** prompt builders for the three modes, deterministic
  validation of model output, bounded retries.
- **Model:** generates text and gives linguistic assessment only.
- **Firestore:** source of truth for `learningSessions`/`learningProgress`.
  No schema or rules change for Phase 2.

## 5. Runtime / Data Naming Map

| Concept | What it is | Where it lands |
|---|---|---|
| `wordsUsedCorrectly` | `/cowrite-turn` response field (ordinary mode) | Re-validated by the client against the current student turn |
| `aiUsedWords` | `/cowrite-turn` response field | `[forcedWord]` in forced mode, `[]` otherwise; the client ignores the claim and re-detects in text |
| `assessedStudentTurn` | `/cowrite-turn` response field (ordinary mode, optional) | Client association check |
| `allWordsUsedCorrectly` | client state | Session-level usage (student + validated fallback); pills + auto-stop |
| `independentWordsUsedCorrectly` | client state | Student-only, non-suggestion usage; the only source of `cowriteWordsUsedCorrectly` |
| `consecutiveMissedStudentTurns` | client state (not persisted) | Fallback counter |
| `cowriteWordsUsedCorrectly` | Persisted, `learningSessions` | Input to mastery calc (`utils/mastery_rules.dart`) |
| `hasError` | `/cowrite-turn` response field ("important problem") | Read only by `classifyCowriteFeedback` for the display indicator; never affects credit or mastery |
| `feedbackKind` | client, `CowriteTurn` (in memory only) | Feedback indicator (positive / needsImprovement / reminder); **not** in `toMap`, not persisted |

## 6. Repositories & Deployment Inventory

- **`vocably`:** `main` at `fa4d52c`, plus uncommitted changes —
  - Code: `lib/utils/cowrite_validator.dart` (new), `lib/utils/cowrite_suggestion.dart` (new), `lib/providers/learning_session_controller.dart` (+ `.g.dart`), `lib/services/ai_worker_service.dart`, `lib/screens/student/learning_flow/cowrite_screen.dart`
  - Tests: `test/utils/cowrite_validator_test.dart` (new), `test/providers/learning_session_controller_test.dart`, `test/screens/cowrite_screen_test.dart`, `test/services/ai_worker_service_test.dart`
  - Docs: the `.md` files at the repo root
- **`vocably-ai-worker`:** `main` at `6239f7e`, plus uncommitted changes to `src/cowriteValidator.ts` (new), `src/handlers/cowriteTurn.ts`, `test/cowriteValidator.test.ts` (new), `test/handlers/cowriteTurn.test.ts`, `README.md`.
  **`wrangler.jsonc` carries a local-only `http://localhost:5000` entry in
  `ALLOWED_ORIGINS` — never stage, commit, or deploy it.** Never print or
  commit `.dev.vars`.
- **Worker deployment:**
  - **Current:** `0bec79ee-2958-475e-97fe-64ababf31c9c`,
    2026-10-15T17:08:04Z UTC, at 100%. It replaced `cc325d6d…`
    (2026-08-30).
  - **How:** deployed from the uncommitted working tree with
    `npx wrangler deploy --var "ALLOWED_ORIGINS:<web.app>,<firebaseapp.com>,http://localhost:5555"`,
    so the local-only `localhost:5000` origin was **not** deployed.
  - **A plain `wrangler deploy` from this working copy would deploy it.**
    Reuse the override.
  - **Production checks:** CORS for the allowed and blocked origins, 401
    without a valid token, and 405 for GET all passed. The CW-02 feedback
    content isn't verified in production, because that needs a Firebase ID
    token.
- **Firebase:** project `vocably-idn-en`. Hosting is not configured.
  Milestone 8 rules are undeployed. No Firestore emulator is available in
  this environment (no Java).

## 7. Do Not Modify Without Explicit Project-Owner Approval

- The **Phase 2 Co-Write rules** in §3 / `SPEC.md` §5.3. In particular:
  the app (never the LLM) owns the counter, word selection, and
  completion; a bot fallback word counts at session level but never as
  mastery; incidental bot usage is never credited.
- The **Dart ⇄ TypeScript validator parity** — change both, with the
  same tests.
- The **prompt-only** approach to `/generate-story` `usedForm`
  integrity — no code-level morphology validator there.
- **No resume behavior** for abandoned learning sessions (Milestone 7
  Decision 1). **The learning cart clears only after the first successful
  `/generate-story`** (Decision 4).

## 8. Known Issues / Limitations

| Item | Status |
|---|---|
| Validator is heuristic, with no POS data: comparatives count only in a comparative context; an all-target turn with an inflection and no comma counts as a sentence (e.g. `attacks buttons`); `My mother is teacher` would match `teach` | Known, documented |
| Language detection is a word-list heuristic, not real language identification. Indonesian made only of content words (e.g. "makan nasi goreng") isn't flagged. A sentence-initial English name that is also an Indonesian weak marker needs a second marker to be flagged ("Dan went home." is fine). Whether the model really keeps every bot sentence in English, gives only a short reminder, and stays on the story needs live testing | Unit- and prompt-contract tested only |
| CW-05 meaning judgement is the model's: whether a use is meaningful (vs. a mere mention, nonsense, or a wrong meaning), and whether the model still omits a grammatically flawed use, can only be verified with the real model. Code can't add a word the model didn't report. Misspellings (`atacked`) and telegraphic all-target sentences (`Monster attack village.` when all three are targets) are not credited | Prompt-contract tested only; needs live testing |
| Once the bot uses a word via fallback, the student can't earn independent credit for it in that session | By design under the authoritative rule |
| LLM output quality (feedback accuracy, continuations) is only prompt- and retry-tested | Needs live testing |
| CW-02 residual gaps: (1) **partial contradictions** aren't detected, e.g. the model claims two words, one is rejected, and the feedback still praises it; (2) feedback that praises a word the model *didn't* claim can't be caught without parsing text, though the indicator then shows amber or blue, never green; (3) attempt detection misses misspellings (`atacked` → shown as a reminder); (4) feedback waits for the fallback call; (5) assessment is still sampled at temperature 0.7 together with the continuation; (6) a 502 for an unacceptable continuation makes the student resend a turn that might have earned credit | Implemented and locally tested (`PROJECT_STATE.md` §5s); needs live testing |
| Cloudflare native Rate Limiting binding availability unresolved (in-memory fallback in use) | Pre-existing |
| `--wasm` build fails (`flutter_tts` legacy JS interop) | Use the JS build |
| Research respondent prep: demographics, data cleanup, instruments | Pending |

## 9. Next-Step Gate

1. Project-owner review of the Co-Write Phase 1 + 2 diffs in both repos.
2. Commit, keeping `wrangler.jsonc`'s local-only origin out of the
   commit, and deploy the Worker. Confirm with `npx wrangler deployments
   list`.
3. Live Chrome + real-LLM E2E of Co-Write (`PROJECT_STATE.md` §7 item 1).
4. Deploy Milestone 8 `firestore.rules`; configure Firebase Hosting;
   manual Milestone 8 E2E.
5. Research respondent preparations (`PROJECT_STATE.md` §12).

## 10. References

- `PROJECT_STATE.md` §5o (Co-Write Phase 1), §5p (Phase 2), §7
  (outstanding), §9 (verification), §10 (git state).
- `SPEC.md` §5.3 (Co-Write), §6 (mastery).
- `DATA_MODEL.md` §4 (`learningSessions`), §10.2 (`/cowrite-turn`).
