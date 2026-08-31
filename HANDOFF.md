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
- **`SPEC.md`** remains authoritative for product/functional behavior.
- **`DATA_MODEL.md`** remains authoritative for the Firestore schema and
  the Worker's request/response contracts.
- **`PROJECT_STATE.md`** remains the authoritative chronological project
  log — this file summarizes its *current* tail, not a replacement for it.
- **This file (`HANDOFF.md`)** is a dense orientation layer on top of the
  above, written once, for the specific moment of this handoff.

**Ground-truth hierarchy** — when any two sources disagree, trust in
this order:

```
repository code  >  git state  >  deployment state  >  HANDOFF.md
    >  PROJECT_STATE.md / SPEC.md / DATA_MODEL.md  >  prior conversation
```

Documentation drifts; the repository doesn't. **Verify any claim here
that matters to your task** against actual source/`git log`/deployment
state before relying on it — this file is a starting point, not a
substitute for checking.

## 2. Current Project Position

- **Milestone 7 (Storyfier core, 3-phase learning flow) is complete.**
- **Milestone 7 Phase 2 ("Stages 1–8" — a name that exists only in code
  comments, not in `SPEC.md`/`DATA_MODEL.md`) is complete.**
- **Milestone 7 is deployed and has one recorded manual E2E pass.**
- **Milestone 8 (guru "Set Target Kata" + "Edit Kata") has NOT started.**

Split explicitly by confidence:

| | |
|---|---|
| **Confirmed** (I verified this directly) | Both repos clean, committed, pushed (`vocably`@`8f313f2`, `vocably-ai-worker`@`cbb066a`); `flutter analyze` clean; `flutter test --concurrency=1` 320/320; Worker `npm test` 89/89, `npm run typecheck` clean; latest Worker deployment `cc325d6d...` (2026-08-30T19:26:47Z); all Stage 1–8 code mechanisms described below, read from current source. |
| **Reported** (project owner told me; I could not independently reproduce — no live browser/Firestore console access) | `firestore.rules`'s Milestone 7 write rules are deployed; a manual E2E session ("brown"/"building", two words, both reaching `mastered`) succeeded end-to-end. |
| **Plausible, unconfirmed** | The "✓ Selesai" double-tap gap (real, confirmed in code) has ever actually caused a reported failure — no causal link has been established either way. |

## 3. What Was Actually Built / Changed in Phase 2

Four behavioral changes, all confirmed by reading current source:

**a. Story `usedForm` integrity.** Live testing found markers like
`[[actor|acted]]`/`[[baby|girl]]` — the second half of a
`[[targetWord|usedForm]]` marker was an unrelated word, not a genuine
inflection. Neither `validateMarkers()` (Worker) nor
`storyMarkersMatchWordIds()` (client) ever checked that half — both only
check that `targetWord` appears exactly once. Fixed via **prompt
strengthening only**, in `generateStory.ts`'s `buildSystemPrompt()`. A
code-level morphology heuristic was **deliberately rejected** — see §8.

**b. Cowrite bare-word exclusion.** The Worker's `wordsUsedCorrectly`
could include a target word the student typed alone (e.g. just
"breakfast"). A Worker prompt fix (Stage 8's step-1 instruction in
`cowriteTurn.ts`) was tried but proved insufficient against live
evidence; a second, deterministic, client-side guard
(`_isBareSingleWordTurn` in `learning_session_controller.dart`) strips
terminal punctuation and rejects a turn with no internal whitespace —
confirmed to still accept short multi-word phrases like "the baby" (2
words, no verb).

**c. 3-turn AI fallback / `aiUsedWords`.** If a student completes more
than 3 turns without using every target word, the Worker's own
`aiTurn` may use exactly one remaining word — eligibility is computed
entirely inside the Worker's prompt (counts `"siswa"` entries in the
transcript it already receives; no new request field). The response
gained `aiUsedWords: string[]`. Client-side, these words union into the
session's "used" set (drives the pill display + the auto-stop
condition) but are kept **structurally separate** from the
independently-tracked set that becomes the persisted mastery-driving
field — an AI-used word can never count as the student's own mastery.
Full contract in `DATA_MODEL.md` §10.2.

**d. Immediate completion.** Once the student's own turn causes every
target word to be used, Cowrite ends without appending a trailing AI
bubble (`completedByThisTurn`/`suppressAiBubble` in `sendTurn()`) — the
same already-necessary Worker response is conditionally not appended to
the transcript; no second Worker call is made.

**The deployment-skew regression, resolved:** immediately after the
first Stage 8 code change, live Cowrite calls failed with
`AiWorkerException: AI proxy returned an unexpected response shape`.
Root cause (inferred from `wrangler deployments list` timestamps vs.
commit history, not a direct live-response observation): the **deployed**
Worker still predated Stage 8 and omitted `aiUsedWords` entirely, which
the newly-strict Flutter client rejected. No code was wrong on either
side — the fix was a Worker deployment. The current deployment
(`cc325d6d...`, 2026-08-30T19:26:47Z) lands ~2 minutes after the
`cbb066a` commit containing the Stage 8 Worker code — strong (still
circumstantial) evidence the live Worker matches committed source.

Full narrative: `PROJECT_STATE.md` §5k.

## 4. Architecture Walkthrough (Cowrite path, current source)

```
Student types a turn
  → cowrite_screen.dart (_ComposeBar)
  → LearningFlowController.sendTurn()        [Flutter, learning_session_controller.dart]
      - _isBareSingleWordTurn() guard (client-only, deterministic, no grammar parsing)
      - AiWorkerService.cowriteTurn()          [Flutter, ai_worker_service.dart]
        → POST /cowrite-turn                    [Cloudflare Worker, cowriteTurn.ts]
            - grades the student's last turn (wordsUsedCorrectly, hasError, feedback)
            - decides the AI's own next turn (aiTurn)
            - may apply the 3-turn fallback (aiUsedWords), per its own prompt logic
        ← CowriteTurnResult (aiTurn, feedback, hasError, wordsUsedCorrectly,
                              suggestion, aiUsedWords)
      - unions wordsUsedCorrectly (minus bare-word guard) + aiUsedWords into the
        session's "all used" set → drives pill UI + auto-stop condition
      - unions ONLY wordsUsedCorrectly (never aiUsedWords), minus any
        suggestion-assisted turn, into the session's "independent" set
      - writes the transcript to Firestore after EVERY turn (LearningSessionService)
Student taps "✓ Selesai" once all words are used
  → LearningFlowController.completeCowrite()
      - LearningSessionService.completeSession()   → learningSessions doc
      - LearningProgressService.recordCowriteCompletion()
          - per-word Firestore transaction, utils/mastery_rules.dart's
            upgradedMasteryStatus() — upgrades difficult→mastered only if
            correct in cloze AND in the "independent" set; never downgrades
          → learningProgress docs
```

**Responsibility split:**
- **Flutter/client:** all mastery/session-state bookkeeping, the bare-word
  guard, the immediate-completion decision, every Firestore write.
- **Worker:** all AI generation/grading, the 3-turn fallback's eligibility
  logic and execution, response-shape validation, one retry on
  `/generate-story` marker failure (not on `/cowrite-turn`, see §10).
- **Firestore:** source of truth for `learningSessions`/`learningProgress`;
  `firestore.rules` enforces the write shapes and the mastery
  no-downgrade rule structurally.

**The one distinction that must never blur:** a word the *student* used
correctly feeds mastery; a word the *AI* used via the fallback never
does, even though both make the word count as "used" for display/stop
purposes. See §5's naming map for exactly which Firestore field that
distinction lands in.

## 5. Runtime / Data Naming Map

| Concept | What it actually is | Where it lands |
|---|---|---|
| `wordsUsedCorrectly` | `/cowrite-turn` API response field (`DATA_MODEL.md` §10.2) | Per-turn, student's own usage as judged by the Worker |
| `aiUsedWords` | `/cowrite-turn` API response field (`DATA_MODEL.md` §10.2) | Per-turn, words the AI itself used via the 3-turn fallback |
| `cowriteWordsUsedCorrectly` | **Persisted Firestore field**, `learningSessions` (`DATA_MODEL.md` §4) and input to mastery calc | The session-wide, "mandiri"-filtered, student-only word set — the only one of these that ever reaches Firestore or affects mastery |
| `hasError` | `/cowrite-turn` API response field | Validated by the client but **not currently read by any client logic** — see §10 |
| *(client-internal only, not an API/data-contract field)* "all used" session set | Dart runtime state in `LearningFlowController` | Drives the pill UI + Cowrite's auto-stop condition; union of student usage + AI-fallback usage |
| *(client-internal only, not an API/data-contract field)* "independent used" session set | Dart runtime state in `LearningFlowController` | The only accumulator ever written out as `cowriteWordsUsedCorrectly` |
| `masteryStatus` | Persisted Firestore field, `learningProgress` (`DATA_MODEL.md` §3) | `difficult` → `mastered`, never downgrades, via `utils/mastery_rules.dart` |

## 6. Deployment Inventory

- **`vocably` (Flutter repo):** branch `main`, clean, in sync with
  `origin/main`, at `8f313f2`. Sequence since Milestone 6: `a7e4d01`
  (2026-08-31 03:57:37 +0700, bare-word fix, 2 files) then `8f313f2`
  (2026-08-31 05:58:53 +0700, base Milestone 7 implementation + this
  doc catch-up, 34 files).
- **`vocably-ai-worker` (sibling repo):** branch `main`, in sync with
  `origin/main`, at `cbb066a` ("Implement Stage 8 story integrity and
  cowrite fallback"). **4 untracked debris files present**, harmless,
  not committed: `diff-cowriteTurn-test.txt`, `diff-cowriteTurn.txt`,
  `diff-generateStory-test.txt`, `diff-generateStory.txt`.
- **Latest confirmed Worker deployment:** `cc325d6d-723d-4adf-a6b1-6d139fcdc2f4`,
  created `2026-08-30T19:26:47Z` (via `npx wrangler deployments list` —
  confirms which version is serving, not the live response *shape*).
- **Firestore rules deployment:** **reported** by the project owner as
  deployed; corroborated by a real manual E2E session succeeding under
  them. No tool available to an AI session directly queries the live
  published rules content — treat this as reported, not confirmed.
- **Firebase project:** `vocably-idn-en`, Firestore Native mode,
  `asia-southeast1` — as recorded in `PROJECT_STATE.md` §6 (not
  independently re-verified this session; carried forward from the
  project's own documentation, which has otherwise proven reliable for
  static facts like this).
- **No Firestore emulator available in this environment** — no Java
  runtime — a standing, pre-existing limitation, not new to Phase 2.

## 7. Verification Snapshot (fresh as of 2026-08-31)

| Check | Result | Status |
|---|---|---|
| `flutter analyze` | No issues | Confirmed |
| `flutter test --concurrency=1` | 320/320 | Confirmed |
| Worker `npm test` | 89/89 | Confirmed |
| Worker `npm run typecheck` | Clean | Confirmed |
| Worker deployment version | `cc325d6d...`, 2026-08-30T19:26:47Z | Confirmed (via Wrangler) |
| Firestore rules deployed | — | Reported / corroborated, not directly queried |
| Manual E2E ("brown"/"building" → both `mastered`) | — | Reported by project owner, not independently reproduced |
| Firestore emulator | Not available | Confirmed limitation (no Java runtime) |

## 8. Already Investigated — Do Not Re-litigate Without New Evidence

- **No code-level `usedForm`/morphology validator was built** — confirmed
  deliberate, documented in `validateMarkers()`'s own doc comment
  (`generateStory.ts`): English inflection is too irregular for a cheap
  heuristic (`go→went` shares no characters with its base form; a naive
  check would reject valid inflections and accept `actor→acted`).
- **No code-level sentence-count validator was built** — same doc
  comment, same file: a sentence-boundary splitter is fragile against
  real English punctuation (abbreviations, decimals, ellipses); enforced
  by prompt strength alone.
- **No general grammar parser was introduced for bare-word detection** —
  `_isBareSingleWordTurn` is explicitly documented as narrow and
  non-grammatical (strip terminal punctuation, test for internal
  whitespace only).
- **The Worker/client deployment-skew regression already occurred and
  was resolved** — see §3. Don't re-diagnose this if a similar-looking
  shape error appears; check deployment freshness first.
- **Mastery isolation between student-used and AI-fallback-used words is
  deliberate**, enforced at three layers (Worker response schema, client
  accumulator separation, Firestore field naming) — not an oversight to
  "simplify."

## 9. Do Not Modify Without Explicit Project-Owner Approval

These are considered decisions, not just current behavior — a fix to a
*newly found* bug in these areas is fine; a redesign of the *approach*
is not, without asking first:

- The **prompt-only** approach to `usedForm` integrity (§8) — do not add
  a code-level validator as a "safety net."
- The **narrow, non-grammar** bare-word guard's design (§8) — do not
  extend it into a general sentence validator.
- The **3-turn AI fallback's semantics**: eligibility lives entirely in
  the Worker's prompt (no new request field), exactly one word per
  fallback turn, only after >3 student turns.
- **`aiUsedWords`'s isolation from student mastery** — never merge it
  into the accumulator that feeds `cowriteWordsUsedCorrectly`.
- **No resume behavior** for abandoned learning sessions (Milestone 7
  Decision 1, `PROJECT_STATE.md` §5j) — every entry always creates a new
  `learningSessions` document.
- **The learning cart clears only once the first `/generate-story` call
  succeeds** (Milestone 7 Decision 4, `PROJECT_STATE.md` §5j).

## 10. Known Issues / Open Questions

| Item | Confidence |
|---|---|
| `hasError` is validated client-side but read by no client logic | **Confirmed** (grep) |
| "✓ Selesai" has no in-flight/double-tap guard, unlike `sendTurn()`'s `isSendingTurn` | **Confirmed** (code) — causal link to any real-world failure is **unconfirmed** |
| `/cowrite-turn` has no retry-once on malformed AI JSON (unlike `/generate-story`, which does) | **Confirmed** (code) — by-design asymmetry, not necessarily a bug |
| Cloudflare native Rate Limiting binding availability is unresolved; Worker still on in-memory fallback | **Confirmed unresolved**, pre-existing, not Phase-2-specific |
| 4 untracked Worker debris files (`diff-*.txt`) | **Confirmed present**, harmless |
| The ">3 turns" fallback threshold is an interpretation of the project owner's original wording, not separately re-confirmed as final | **Flagged for owner confirmation if it ever becomes relevant** — not a bug |

None of the above are asserted as confirmed *bugs* unless explicitly marked so.

## 11. Next-Step Gate

Documentation catch-up (this handoff itself) is the current task.
**Milestone 8 is next in `CLAUDE.md` §7's sequence, but that alone is
not authorization to start it.** Do not begin Milestone 8 without
explicit project-owner instruction, even though it is "next."

## 12. References

- `PROJECT_STATE.md` §5j (Milestone 7 base), §5k (Phase 2 Stages 1–8),
  §9 (verification), §10 (git state).
- `SPEC.md` §5.3 (Cowrite functional spec, including the two Phase-2
  behaviors).
- `DATA_MODEL.md` §10.2 (`/cowrite-turn` contract, including `aiUsedWords`).
- `CLAUDE.md` §7 (milestone order).
- Commits: `a7e4d01`, `8f313f2` (`vocably`); `cbb066a` (`vocably-ai-worker`).
- Latest Worker deployment: `cc325d6d-723d-4adf-a6b1-6d139fcdc2f4`
  (2026-08-30T19:26:47Z).
