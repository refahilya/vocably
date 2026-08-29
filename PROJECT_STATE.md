# Vocably — Project State

> This file is a snapshot, not a source of truth. `CLAUDE.md`, `SPEC.md`,
> `DATA_MODEL.md`, and `DESIGN_REFERENCE.md` remain the authoritative
> project documents. If anything here conflicts with the live repository
> or with those four documents, the live repository / those documents win
> — update this file, don't trust it blindly.

## 1. Current Status

**Milestones 1–4 complete and pushed to `origin/main`** (`bab8170`),
including the post-Milestone-4 pagination-bar layout fix. **Milestone 5
(Cloudflare Worker + guru "Tambah Kosakata") is complete** —
implemented (§5g), a real CORS configuration bug found and fixed during
manual testing (§5h), and manually verified end-to-end by the project
owner against the real deployed Worker and live Firestore (§5h). A new
sibling repo, `vocably-ai-worker/` (TypeScript, separate git history,
not a subdirectory of this Flutter repo, now has its own first commit)
holds the Worker itself; this repo's changes are the Flutter-side
integration (new services/providers/screens, `firestore.rules` guru
write access — deployed and confirmed working by real writes during
E2E testing). **One thing explicitly remains unconfirmed, not just
undeployed:** whether Cloudflare's native Rate Limiting binding is
available on the project owner's Workers plan — the Worker still runs
on the in-memory fallback (§5g/§7).

**Milestone 6 (Student Dashboard + Riwayat + Placement/Pre-Post-Test
scaffolds) is now implemented** (§5i) — real "Belajar"/"Riwayat"
screens replacing their Milestone 3 placeholders, read-only
`targetWordSets`/`learningProgress`/`learningSessions` access, the
one-time placement-test auto-offer, and placeholder screens for the
placement test and the research assessment (Pre-Test/Post-Test), per
the scope explicitly approved by the project owner. **Not yet
deployed or manually verified end-to-end** — `firestore.rules`/
`firestore.indexes.json` changes are written but undeployed, and
nothing in this milestone has been clicked through in a real browser
yet (§7/§5i). **A real, pre-existing environment defect was found
during this milestone's own verification, unrelated to any Milestone 6
code change:** `flutter test` at its default concurrency silently
drops a large, non-deterministic subset of test files (both new and
several pre-existing ones) while still reporting "All tests passed!"
with a clean exit code — `--concurrency=1` reliably runs the complete
suite instead. See §5i and §9 for the full finding and its evidence.

## 2. Milestone History

| # | Milestone | Status |
|---|---|---|
| 1 | Skeleton project + Firebase connection | **Complete, pushed** |
| 2 | Auth: sign up, login, role-based routing | **Complete, pushed** |
| 3 | Design system / theme layer + responsive nav shell | **Complete, pushed** |
| 4 | Vocab module: `vocabWords`, CSV import, CEFR bundles, browse, DictionaryAPI, TTS | **Complete, pushed** (real data seeded, a post-seed Firestore-index bug found and fixed — see §5b; pagination-bar overflow fix — see §5f) |
| 5 | Cloudflare Worker + guru "Tambah Kosakata" | **Complete — implemented, deployed, and manually verified end-to-end (§5g/§5h). Uncommitted in both repos — see §10.** |
| 6 | Student dashboard + Riwayat + Placement/Pre-Post-Test scaffolds | **Implemented (§5i) — automated tests passing, `flutter analyze` clean. NOT yet deployed (`firestore.rules`/`firestore.indexes.json` changes pending) or manually verified in a real browser. Uncommitted — see §10.** |
| 7 | Storyfier core (3-phase learning flow) | Not started |
| 8 | Guru: Set Target Kata + Edit Kata | Not started |

### Milestone 4 stage detail

| Stage | What | Status |
|---|---|---|
| 1 | `VocabWord`/`VocabMeaning` models, `normalizeWord()` | Complete |
| 2 | Firestore rules: `vocabWords`/`topics` read-only for authenticated users | Complete, deployed by the project owner |
| 3 | `VocabBundleEntry` model + pure parser | Complete |
| 4 | `VocabBundleService` (asset load + Firestore delta merge) + providers | Complete |
| 5 | Vocabulary browse screen (abjad/tema/POS, 6 CEFR levels) | Complete |
| 6 | Learning cart (`LearningCart` Riverpod notifier, session-local) | Complete |
| 7 | Dev-side CSV import pipeline (`tools/vocab_import/`) — parse, validate, merge Oxford 3000+5000 | **Complete — run for real against the actual CSVs (§5)** |
| 8 | One-off Indonesian translation generation (OpenAI-compatible API) | **Complete — all 5,936 meanings translated and cached (§5)** |
| 9 | Firestore seed/import (Admin SDK) | **Complete — run for real by the project owner, 4,952 documents confirmed live (§5)** |
| 10 | Bundle generation (`assets/vocab/vocab_*.json`) | **Complete — real bundle files generated and verified against the actual `VocabBundleEntry` parser (§5)** |
| 11 | DictionaryAPI integration (word-detail screen, Layer 1 fallback) | Complete |
| 12 | TTS integration (`flutter_tts`, Layer 2 audio fallback) | Complete |
| 13 | Temporary dashboard entry point to browse | Still temporary and intentionally left in place — Milestone 6 replaces it |

## 3. Current Architecture

- **Framework:** Flutter (web-only), Dart, Riverpod with code generation exclusively.
- **Firebase:** `firebase_core`, `firebase_auth`, `cloud_firestore`, project `vocably-idn-en`, Spark plan, no Cloud Functions.
- **Design system:** `lib/theme/theme.dart` (`AppColors`/`AppSpacing`/`AppRadius`/`AppTextStyles`/`AppTheme`).
- **Navigation:** `AppNavShell` (`lib/widgets/app_nav_shell.dart`) — `NavigationRail` on wide screens, top tabs on narrow/mobile, one reusable widget for both siswa and guru.
- **Vocabulary data flow:** `assets/vocab/vocab_{level}.json` bundles (generated by `tools/vocab_import/`, loaded via `VocabBundleService`) + a live Firestore delta query for anything newer than the bundle's generation timestamp (`kBundleGeneratedAt`, `lib/utils/vocab_bundle_constants.dart`).
- **`meanings[].translation`** (renamed from `translationId` during this Milestone 4 run — see §8) holds the Indonesian translation text **directly**, inline — there is no separate `translations` collection.
- **DictionaryAPI + TTS:** `DictionaryApiService` (English definitions/phonetics, direct client call, no proxy) + `TtsService` (`flutter_tts`, always used for the speaker button — see §7's disclosed limitation on real recorded-audio playback).
- **Dev-side data pipeline:** `tools/vocab_import/` (Node.js, separate from the Flutter app) — see §5.
- **Backend/API beyond Firebase:** `vocably-ai-worker/` (Cloudflare Worker, TypeScript, separate sibling git repo — see §5g), accessed from Flutter via `AiWorkerService`.

### Directory structure (current)

```
lib/
  app.dart, main.dart, firebase_options.dart
  models/
    app_user.dart, vocab_word.dart, vocab_bundle_entry.dart, dictionary_entry.dart,
    topic.dart,                                           # Milestone 5
    target_word_set.dart, learning_progress.dart, learning_session.dart  # Milestone 6
  services/
    firebase_service.dart, auth_service.dart, user_service.dart,
    vocab_bundle_service.dart, dictionary_api_service.dart, tts_service.dart,
    ai_worker_service.dart, vocab_word_service.dart, topics_service.dart,  # Milestone 5
    target_word_set_service.dart, learning_progress_service.dart,
    learning_session_service.dart                          # Milestone 6 — all read-only
  providers/
    auth_providers(+.g), sign_up_controller(+.g), login_controller(+.g),
    complete_registration_controller(+.g), vocab_bundle_providers(+.g),
    vocab_browser_providers(+.g), learning_cart_providers(+.g),
    dictionary_providers(+.g),
    ai_worker_providers(+.g), vocab_management_providers(+.g),
    lazy_translation_providers(+.g),                       # Milestone 5
    dashboard_providers(+.g), history_providers(+.g),
    placement_test_providers(+.g)                          # Milestone 6
  screens/
    auth/login_screen.dart, sign_up_screen.dart, complete_registration_screen.dart
    student/
      dashboard/dashboard_screen.dart, target_word_list_screen.dart   # Milestone 6 — replaces the old placeholder
      history/history_screen.dart, session_detail_screen.dart          # Milestone 6 — replaces the old placeholder
      placement_test/placement_test_offer_screen.dart,
        placement_test_placeholder_screen.dart              # Milestone 6, scaffold only
      research_assessment/research_assessment_placeholder_screen.dart  # Milestone 6, scaffold only
      vocab_browser/vocab_browser_screen.dart, learning_cart_screen.dart, word_detail_screen.dart
    teacher/
      target_words/target_words_placeholder.dart
      vocab_management/tambah_kosakata_screen.dart   # Milestone 5 — replaces the old placeholder
  theme/theme.dart
  utils/role.dart, normalize_word.dart, vocab_browse_filter.dart, vocab_bundle_constants.dart,
    cefr_levels.dart, topic_slug.dart, worker_config.dart,  # Milestone 5
    target_word_constants.dart, story_markers.dart, session_date_format.dart  # Milestone 6
  widgets/app_nav_shell.dart, mastery_badge.dart              # mastery_badge.dart: Milestone 6

tools/vocab_import/            # separate Node.js tool, not part of the Flutter app — see §5
  bin/merge.js, translate.js, seed_firestore.js, generate_bundles.js
  lib/csvParser.js, normalize.js, merge.js, translateClient.js,
      translationCache.js, seedDecision.js, bundleGen.js, dotenv.js
  test/*.test.js
  input/ (git-ignored), output/ (git-ignored)

assets/vocab/                  # real per-level bundle files, generated by
                                # tools/vocab_import/ (§5, Stage 4/10)
```

```
# SEPARATE REPO (sibling directory, own git history) — see §5g:
vocably-ai-worker/
  src/index.ts, auth.ts, cors.ts, rateLimit.ts, openai.ts, env.ts
  src/handlers/translate.ts, generateStory.ts, cowriteTurn.ts
  test/*.test.ts, test/handlers/*.test.ts
  wrangler.jsonc, vitest.config.ts, README.md
```

`lib/screens/placeholders/` (Milestone 2's temporary routing-proof screens) has been deleted, as planned, once Milestone 3's real nav shell landed. `lib/screens/teacher/vocab_management/vocab_management_placeholder.dart` was deleted the same way in Milestone 5, once `tambah_kosakata_screen.dart` replaced it. `lib/screens/student/dashboard/dashboard_placeholder.dart` and `lib/screens/student/history/history_placeholder.dart` were deleted the same way in Milestone 6, once `dashboard_screen.dart`/`history_screen.dart` replaced them.

## 4. Authentication and Authorization

Unchanged since Milestone 2 — see `DATA_MODEL.md` §1 for the full schema/rules. No auth-related work happened in Milestone 3 or 4.

## 5. Data Population Pipeline (`tools/vocab_import/`) — detail

This is new in this Milestone 4 session. Full rationale/usage in
`tools/vocab_import/README.md`; summary here for the progress ledger.

**Why Claude built this (context for future sessions):** `CLAUDE.md`/
`DATA_MODEL.md` originally reserved CSV import, translation generation,
and bundle generation as "not Claude's job" (dev-only, own laptop, own
keys). The project owner explicitly authorized Claude to build this
pipeline mid-Milestone-4, on the condition that secrets and the first
real run of any costly/production-writing stage stay developer-gated.
`CLAUDE.md`/`DATA_MODEL.md` were updated to reflect this (§8 below).

**Stage 1 (merge) — run for real, against the actual Oxford CSVs:**
- Oxford 3000: 3,308 data rows. Oxford 5000: 2,015 data rows. 0 malformed rows in either file.
- **4,952 unique canonical `vocabWords` documents** after merging duplicates and the 21 Oxford 3000/5000 overlap words.
- 353 duplicate-word groups merged (multiple CSV rows → one document).
- CEFR distribution of the merged documents: A1 898, A2 792, B1 690, B2 1295, C1 1277 (no C2, as expected — Oxford source data doesn't reach C2).
- 10 "same-POS collision" cases flagged for manual review (same word + same POS contributed by two different rows — see `tools/vocab_import/README.md`'s "Known limitation" section and `DATA_MODEL.md` §2's translation note). Full list in `output/import_report.json`.
- Output: `tools/vocab_import/output/canonical_vocab.json` (git-ignored, regenerate anytime via `node bin/merge.js`).

**Stage 2 (translate) — complete, real run against the configured API:**
- Configuration (`.env` at repo root, not committed): `OPENAI_BASE_URL=https://ai.dinoiki.com/v1`, `OPENAI_API_PATH=/chat/completions`, `OPENAI_MODEL=gpt-4o-mini` — a pre-existing developer-configured OpenAI-compatible endpoint, not something Claude set up.
- A 5-item smoke test ran first and was manually spot-checked for quality (e.g. "abandon"→"meninggalkan", "ability"→"kemampuan" — correct, natural Indonesian) before scaling up.
- Full run: 5,936 total meanings across all 4,952 documents, batches of 25. One batch (of 238) reliably failed with a JSON-parsing error on the model's response for that specific 25-item grouping (not a transient network issue — retried identically and failed the same way); re-running with a smaller batch size isolated and resolved it — all 25 items translated fine individually. **Final state: all 5,936 meanings have a non-null translation, 0 remaining.**
- Spot-checked quality on several words post-completion — all correct and properly disambiguated by POS (e.g. "run" verb→"berlari"/noun→"lari", "light" noun/adjective/verb → "cahaya"/"ringan"/"menyalakan"). One minor known imperfection: "equal" as a noun (a rarer sense, "no equal") translated to "sama" (matches the adjective sense) rather than something like "tandingan" — not corrupted, just an imperfect rare-sense translation, worth a teacher's eventual review alongside the same-POS collision list.
- Output: `tools/vocab_import/output/translations_cache.json` (resumable cache, 5,936 entries) + `output/canonical_vocab_translated.json` (canonical data with translations applied, 0 nulls).

**Stage 3 (seed to Firestore) — complete, run for real by the project owner:**
- The project owner generated a service-account key (kept outside the repo), set `GOOGLE_APPLICATION_CREDENTIALS`, ran `node bin/seed_firestore.js --dry-run` then `--yes`, and confirmed in the Firebase Console that all 4,952 `vocabWords` documents (+ the `topics` master list) are now really present in the `vocably-idn-en` project.
- The decision logic (create vs. update vs. skip-unchanged vs. skip-foreign, idempotent reruns, never touching `source: "guru"` documents) was already fully unit-tested (`test/seedDecision.test.js`) before this run; it now also has a real production run behind it.
- A minor gap was found and fixed *after* this run (§5b): the seed pipeline never wrote the documented `posList` field. Not re-seeded now (harmless — nothing reads it from Firestore today); the fix makes a future rerun self-heal it (see §5b).

**Stage 4 (bundle generation) — complete, run for real:**
- `assets/vocab/vocab_a1.json` (898 words), `vocab_a2.json` (792), `vocab_b1.json` (690), `vocab_b2.json` (1295), `vocab_c1.json` (1277) — all generated from the real translated canonical data. No `vocab_c2.json` (no C2 data, as expected). `.gitkeep` removed since real files now exist.
- `lib/utils/vocab_bundle_constants.dart`'s `kBundleGeneratedAt` updated to the real generation timestamp.
- **Verified against the actual Flutter model**, not just assumed correct: a temporary test loaded all 5 files through the real `VocabBundleEntry.listFromJson` parser — **0 of 4,952 entries failed to parse**, every entry has a non-empty `word`/`meanings` and the expected `cefrLevel`.
- **A real regression was caught and fixed by this verification**: `test/screens/vocab_browser_screen_test.dart` started hanging (`pumpAndSettle` timeout) once real, sizeable bundle files existed, because it had been implicitly relying on `rootBundle.loadString` failing fast (asset didn't exist yet) — a genuine multi-hundred-KB disk read doesn't resolve within `flutter test`'s fake-async pump loop without `tester.runAsync()`. This is a test-harness artifact, not a production bug (a real running app resolves this normally) — fixed by injecting a fake `AssetBundle` in that test, the same pattern `vocab_bundle_service_test.dart` already used, so the test no longer depends on real disk I/O timing.

## 5b. Bug Fix — Vocabulary Browse Failed to Load Real Data

**Symptom:** after the real Firestore seed (§5) completed and was verified in the console, `Jelajahi Kosakata` → any CEFR level × any browse mode (A1/A2/B1 × Abjad/Tema all tried) hung loading, then showed "Gagal memuat kosakata" / "Coba lagi" — which just repeated the same failure.

**Root cause (confirmed, not guessed):** `VocabBundleService.fetchDelta()` runs
```dart
firestore.collection('vocabWords')
  .where('cefrLevel', isEqualTo: cefrLevel)
  .where('updatedAt', isGreaterThan: Timestamp.fromDate(bundleGeneratedAt))
```
— an equality filter on one field plus a range filter on a *different* field, which Firestore requires a composite index for. `DATA_MODEL.md` §11.5 already documented that this index was needed ("index baru `cefrLevel + updatedAt` ditambahkan untuk query delta") — but `firestore.indexes.json` still had `"indexes": []`, and running `firebase firestore:indexes` against the live project confirmed **zero composite indexes actually existed there either.** The index was described in the docs but never actually created. With an empty `vocabWords` collection (before the real seed) this never mattered; once ~5,000 real documents existed and the query actually ran, Firestore rejected it with `FAILED_PRECONDITION` ("query requires an index"). `loadLevelWithDelta()` didn't catch this, so the exception propagated all the way to the `vocabLevel` provider as an `AsyncError` — for every level and every browse mode, since the failure happens before any level/mode-specific logic runs at all. This matches the reported symptom exactly.

**Files changed:**
- `firestore.indexes.json` — added the `vocabWords` composite index (`cefrLevel` ASC, `updatedAt` ASC) that should have been there since Milestone 4 Stage 2.
- `lib/services/vocab_bundle_service.dart` — `loadLevelWithDelta()` now catches a `fetchDelta()` failure and falls back to bundle-only data (logged via `debugPrint`) instead of letting the whole level fail. This means: (a) the browse screen now works immediately even before the index finishes deploying/building, and (b) any *future* transient delta failure (index rebuild, brief network issue) degrades to "no freshness top-up this load" instead of an outright failure — matching the graceful-degradation pattern `SPEC.md` §3.5 already uses for DictionaryAPI.
- `test/services/vocab_bundle_service_test.dart` — two new tests: `fetchDelta` throwing still returns bundle data (this is the regression test; confirmed it fails against the pre-fix code via a manual revert-and-rerun), and `fetchDelta` succeeding still merges normally.
- `tools/vocab_import/lib/seedDecision.js` (+ `test/seedDecision.test.js`) — secondary finding from the same investigation, not the crash's cause: the seed pipeline never wrote the documented `posList` field (`DATA_MODEL.md` §2 says Firestore must persist it since there are no computed fields; `VocabWord.toMap()` on the Dart side already does). Fixed so future creates/updates include it, and so an existing document missing it is now detected as needing an update (self-healing backfill on the next rerun) rather than wrongly treated as already up to date. **Not a cause of the reported bug** — `VocabWord.fromFirestore` never reads `posList` back — and the already-seeded 4,952 documents were deliberately **not** re-seeded for this alone.
- `DATA_MODEL.md` §11.3/§11.5 — recorded this bug and its fix inline.

**Verification:**
- `flutter analyze`: no issues.
- `flutter test`: **116/116 passing** (full suite).
- `tools/vocab_import` (`node --test`): **43/43 passing**.
- The new regression test was confirmed to actually fail against the pre-fix code (temporarily reverted `vocab_bundle_service.dart` via `git stash`, reran, saw it fail with the exact simulated exception, then restored the fix and confirmed it passes again).
- **Not yet re-verified against the real running web app** by a human — the `fetchDelta`-failure path was exercised automatically (unit test) but the *actual* browse screen, against the *actual* seeded Firestore data, has not been manually re-tested since this fix. The code-level fix means it should now work regardless of whether the index has been deployed yet (bundle-only fallback), but a real click-through is still recommended.

**Remaining manual action:** deploy the index so the freshness-delta feature actually works (not just degrades gracefully): from the repo root, `firebase deploy --only firestore:indexes`. Not run automatically this session (same standing rule as Firestore rules — Claude edits the config file, the project owner deploys it). Note indexes can take some time to finish building on a ~5,000-document collection; until built, the graceful-degradation fix means browse still works, just without the live top-up.

## 5c. Audit — Word Detail English Definition/Example/Phonetic Coverage

**Trigger:** manual end-to-end testing (post-§5b fix) found Word Detail
often shows "Definisi saat ini tidak tersedia" and inconsistent
phonetic/example-sentence coverage. Audited against `SPEC.md`,
`DATA_MODEL.md`, `DESIGN_REFERENCE.md`, `CLAUDE.md` before touching code.

**1. Explicitly required for Milestone 4:** POS (Vocably's own data,
always present) and Indonesian translation per meaning (`meanings[].translation`,
from the bank kosakata) — `SPEC.md` §3.5. Layer 1 graceful degradation
(a friendly fallback message when English content is missing) and Layer
2 audio fallback (TTS) are both explicitly "wajib" (mandatory) — and both
are implemented.

**2. Only optional/best-effort:** English definition, example sentence,
and phonetic text are **all** sourced from DictionaryAPI, which
`SPEC.md` §3.5 explicitly and repeatedly describes as unreliable: *"API
tersebut adalah layanan komunitas gratis tanpa jaminan uptime — jadi
kegagalan harus dianggap normal, bukan kasus tepi"* ("failure must be
considered normal, not an edge case"). The exact fallback text this
session's implementation shows ("Definisi bahasa Inggris tidak tersedia
untuk kata ini" / current wording) is the literal example string
`SPEC.md` §3.5 Layer 1 gives.

**3. Bug or expected limitation?** **Both** — split findings:
- Missing content for genuinely rare/uncommon words, or for function
  words (articles) DictionaryAPI just doesn't model well, is **expected**
  per the SPEC's own framing above. Not a bug.
- However, empirical testing (live calls to the real DictionaryAPI for
  representative words spanning every POS tag Vocably's data actually
  uses) found a **genuine implementation bug**: Oxford's POS taxonomy
  doesn't match DictionaryAPI's (Wiktionary-derived) tags for several
  categories — confirmed against the live API, not assumed:
  - Vocably `modal` (e.g. "can", "must") — DictionaryAPI tags these `verb`, never `modal`.
  - Vocably `auxiliary` (e.g. "do") — DictionaryAPI tags `verb`.
  - Vocably `number` (e.g. "one") — DictionaryAPI tags `numeral`.
  - Vocably `exclamation` (e.g. "oh") — DictionaryAPI tags `interjection`.
  - Vocably `determiner` (e.g. "this", "some", "each") — DictionaryAPI tags `pronoun` (occasionally `adjective`), never `determiner`.
  - `article` (e.g. "a"/"the") has no reliable DictionaryAPI equivalent found — genuinely unavailable, not a mismatch.
  
  Since the old code matched Vocably's tag against DictionaryAPI's
  `partOfSpeech` by **exact string equality**, every word whose Vocably
  POS falls into one of the first five categories above was silently
  shown "not available" **even when the API actually had the
  definition**, just filed under a different tag name.

**4. Did the current code fail to display data it actually had?** **Yes,
confirmed** — this is exactly the bug in point 3. Phonetic text is
**not** affected by this bug (it's word-level, not per-POS); its
inconsistent presence is the expected DictionaryAPI-completeness
limitation from point 3's first bullet.

**5–7. Fix (schema/API unchanged, as instructed):**
- `lib/models/dictionary_entry.dart` — added `DictionaryEntry.definitionsForPos(pos)`: tries the exact tag first, then a small, empirically-verified alias table (`modal`/`auxiliary`→`verb`, `number`→`numeral`, `exclamation`→`interjection`, `determiner`→`pronoun` then `adjective`) before giving up. `article` deliberately left unmapped — no evidence-based fallback exists for it.
- `lib/screens/student/vocab_browser/word_detail_screen.dart` — now calls `definitionsForPos(meaning.pos)` instead of the exact-match `meaningsByPos[meaning.pos]`.
- `test/models/dictionary_entry_test.dart` — 7 new tests, including one confirmed to fail (a compile error, since the method didn't exist) against the pre-fix code via a manual `git stash`/rerun/restore cycle.
- No schema change, no new dependency, no new API — exactly as instructed.

**Verification:** `flutter analyze` clean; `flutter test` all passing (124 total). Not yet re-verified against the real running app with a live "can"/"must"/"one"/"oh" lookup — worth a quick manual check, but the fix is a pure, fully-tested local lookup change with no external-service risk.

**Recorded as a known, accepted limitation going forward (not something to "fix" further without a new decision):** `article`-tagged words, and any word DictionaryAPI genuinely has no entry for, will continue to show the Layer 1 fallback message — this is by design, not a gap.

## 5d. Follow-up Investigation — English Definitions Still Missing After §5c

Manual re-testing after §5c's alias fix still found missing English
definitions in Word Detail. Investigated end-to-end (Oxford entry →
`dictionaryLookupProvider` → real DictionaryAPI request → response
parsing → POS matching → rendering) with real, spaced-out calls to the
live API — not assumed.

**Findings, with evidence:**
- The §5c alias table itself is **confirmed correct** on real bundle data — spot-checked real words for every aliased category (`do`/`have`→auxiliary, `all`/`another`/`any`/`both`/`each`/`enough`→determiner, `bye`/`goodbye`/`hello`/`hey`/`hi`→exclamation) and all matched successfully.
- **New, real gap found:** `number`→"one"/"million"/"thousand" are tagged `numeral`, but a few (e.g. "billion") are tagged only `noun` — confirmed the noun definition ("a thousand million...") *is* the correct numeric one, not an unrelated sense. **Fixed:** `number` alias extended to `['numeral', 'noun']`.
- **A rapid-fire diagnostic script hitting ~45 real API calls without delay produced a large false "networkError" batch** (words like "can"/"address"/"eight" that a spaced-out, separate real curl check confirmed work fine) — this is DictionaryAPI's own rate limiting, not a Vocably bug, but it surfaced a real, separate implementation gap (next point).
- **Real bug found:** the UI collapsed three different situations into the exact same "Definisi bahasa Inggris tidak tersedia" message: (a) still loading, (b) a genuine permanent content gap, (c) a transient failure (network error/rate limit) that might well succeed on retry. (a) could flash a false "unavailable" before the API even responded; (c) gave the user no way to tell a fixable failure apart from a real gap, or to retry.
- **Confirmed genuine, permanent DictionaryAPI content gaps** (not a bug — correctly left as-is): `article` ("a"/"the" — no equivalent tag), `be` (404, no entry at all for the bare word), `would`/`ought` as `modal` (API only has an unrelated noun sense, no verb entry exists to alias to), `no` as `determiner` (none of the API's tags for "no" correspond to that sense), `ok` as `exclamation` (API only tags it adjective).

**Fix:**
- `lib/models/dictionary_entry.dart` — extended the `number` alias (`['numeral', 'noun']`); expanded the doc comment with the full evidence trail (which words were tested, what was confirmed unmappable and why).
- `lib/screens/student/vocab_browser/word_detail_screen.dart` — replaced the flat nullable-list rendering with a small `_DictionaryContent` sealed type (`_DictionaryLoading` / `_DictionaryFound` / `_DictionaryUnavailable` / `_DictionaryRetryable`), computed via `_dictionaryContentFor()`. Loading now shows a small spinner + "Memuat definisi..."; a permanent gap shows the original fallback text unchanged; a transient failure shows "Gagal memuat definisi. Periksa koneksi lalu coba lagi." with a working "Coba lagi" button that calls `ref.invalidate(dictionaryLookupProvider(...))`.
- `test/models/dictionary_entry_test.dart` — 7 new tests for `definitionsForPos` (exact match, each alias, the deliberately-unmapped `article` case).
- `test/screens/word_detail_screen_test.dart` — rewritten: separate tests for the 404/permanent path (no retry button), the loading path (spinner, no premature "unavailable" text), the 500/retryable path (retry button present, tapping it re-triggers the lookup — verified via a call counter), and a `modal`→`verb` end-to-end proof that a definition that previously failed to appear now renders.

**Genuine remaining DictionaryAPI limitations (not bugs, not to be "fixed" further without a new decision):** `article`, `be` (as a bare auxiliary), specific modal words with no verb entry in the API's data (`would`, `ought`), `no` as a determiner, `ok` as an exclamation, and any multi-word phrase (unchanged from §5c/`SPEC.md`'s original framing).

## 5e. Pagination Added to Vocabulary Browse

The real A1 bundle (~900 words) rendered its entire filtered/sorted
result at once, and was reported as noticeably laggy in the real Chrome
app. Added client-side pagination — no bundle format change, no
Firestore change, no server-side pagination.

- **Page size: 50** (`kVocabBrowsePageSize`, `lib/utils/vocab_browse_filter.dart`).
- New pure `paginate<T>(items, {page, pageSize})` → `VocabBrowsePage<T>` (`items`, `pageIndex`, `totalPages`) — generic, no `VocabBundleEntry` dependency, always called **after** `applyVocabBrowseFilter` (filter/sort first, paginate the result, never the other way around).
- `VocabBrowserFilterState` gained a `page` field (0-indexed). `selectLevel`/`selectMode`/`selectTopic`/`selectPos` all reset it to `0`; a new `goToPage(int)` sets it directly.
- UI: a `_PaginationBar` (Previous/Next `OutlinedButton`s + "Halaman X dari Y") appears below the list only when `totalPages > 1` — hidden entirely (not just disabled) when everything fits on one page, per the "not unnecessarily prominent" requirement. Previous/Next disable via `onPressed: null` at the first/last page respectively.
- **Performance:** `_LevelContent` was converted from `ConsumerWidget` to `ConsumerStatefulWidget` purely to memoize `applyVocabBrowseFilter`/`distinctTopics`/`distinctPosValues` — these are cached (invalidated on `identical()`/field-equality checks against `allEntries`/`mode`/`selectedTopic`/`selectedPos`) so paging through 18 pages of A1 no longer re-filters/re-sorts/re-derives the full ~900-word list on every click, only on an actual level/mode/filter change. No new package, no app-wide state-management change — a contained, single-widget memoization.

**Tests added:**
- `test/utils/vocab_browse_filter_test.dart` — 9 new `paginate` tests: 0 results, fewer than a page, exactly one page, multiple pages with a smaller last page, page-index clamping past the end/below zero (acts as disabled Next/Previous), full next/previous walk with no gaps/overlap, no mutation of the input, custom page size.
- `test/providers/vocab_browser_providers_test.dart` (new file) — 8 tests confirming every mutating action (`selectLevel`/`selectMode`/`selectTopic`/`selectPos`) resets `page` to `0`, `goToPage` doesn't disturb other selection fields, and vice versa.
- `test/screens/vocab_browser_screen_test.dart` — 10 new widget tests against a 120-word fake A1 bundle (+ a 75-word A2 bundle): page-1 rendering, Previous disabled on page 1, Next navigation + Previous re-enabling, last-page-smaller-than-page-size disabling Next, Previous navigating back, level switch resetting to page 1, mode switch resetting to page 1, a topic filter narrowing to 30 results (under one page) both resetting to page 1 *and* hiding the pagination bar, and an empty level showing no pagination bar.

## 5f. UI Fix — Pagination Bar Horizontal Overflow

Milestone 4 was committed and pushed (`24cd651 Complete Milestone 4
vocabulary module`) before this fix. Manual testing in real Chrome at
the canonical ~390px mobile width then found a visible `RenderFlex`
horizontal overflow in the vocab-browser pagination bar (§5e) — the
right side clipped/broke the layout.

- **Root cause:** `_PaginationBar`'s Previous/Next were
  `OutlinedButton.icon` widgets with text labels ("Sebelumnya"/
  "Selanjutnya"). Two such buttons (icon + label + default Material
  button padding) plus the "Halaman X dari Y" indicator text, laid out
  in a plain `Row(mainAxisAlignment: spaceBetween)` with no flexible
  child, together demanded more intrinsic width than fits at ~390px —
  confirmed by reverting the fix and re-running the new regression test
  below, which reported "A RenderFlex overflowed by 298 pixels on the
  right."
- **Fix:** Previous/Next rebuilt as small, fixed-size **icon-only**
  buttons (`_PageNavButton`, 40×40, tight padding, `VisualDensity.compact`)
  wrapped in `Tooltip` (keeps "Sebelumnya"/"Selanjutnya" available on
  hover/long-press and supplies the accessibility label, since `Tooltip`
  auto-generates a semantics label from its `message`). The page
  indicator text is wrapped in `Expanded` + `overflow: TextOverflow.ellipsis`
  so it can never itself force an overflow. Because the two nav buttons
  now have a small, fixed intrinsic width (no longer text-length-dependent)
  and the indicator is the only flexible element, the row structurally
  fits at any supported viewport width rather than being tuned to one
  screenshot. Added `AppTextStyles.caption` (12px, `lib/theme/theme.dart`)
  for the now-smaller page-indicator text, per `CLAUDE.md` §5 ("jangan
  hardcode nilai style di widget individual").
- **No behavior change:** page size (50), Previous/Next enable/disable
  logic, "Halaman X dari Y" text, reset-on-level/mode/topic/POS-change,
  filter-then-paginate order, and the empty-state/hidden-when-one-page
  rules are all unchanged — this was a layout-only fix.
- **Tests:** existing pagination widget tests updated to locate the
  Previous/Next buttons by `Key` (`vocabBrowserPreviousPage`/
  `vocabBrowserNextPage`) instead of by visible button text, since the
  buttons no longer carry text. One new regression test added —
  `'pagination bar does not overflow at the canonical ~390px mobile
  width'` (`test/screens/vocab_browser_screen_test.dart`) — sets
  `tester.view.physicalSize` to 390×844 and asserts
  `tester.takeException()` is `null`. Confirmed to fail against the
  pre-fix code (298px overflow) and pass after the fix, via
  `git stash`/`git stash pop` on just the two source files.

## 5g. Milestone 5 — Cloudflare Worker + Guru "Tambah Kosakata"

Implemented per the plan the project owner approved (decisions a–e: separate
sibling Worker repo; reuse the existing Dinoiki OpenAI-compatible endpoint/
model; `wrangler dev` for local Worker development; in-memory rate-limit
fallback if the native binding turns out unavailable on the Free plan;
Tambah Kosakata only — no inert Edit Kata tab).

**New sibling repo: `vocably-ai-worker/`** (TypeScript, own `git init`, not
part of this Flutter repo) — see its own `README.md` for setup/dev/deploy.
Summary:
- `src/index.ts` — router: CORS preflight → origin allowlist → Firebase ID
  token verification (`src/auth.ts`, `jose`, against Google's JWKS endpoint
  — the JWKS-shaped variant of the same keys `DATA_MODEL.md` §10.1's X.509
  URL names, since `jose`'s `createRemoteJWKSet` wants that shape) → rate
  limiting (`src/rateLimit.ts`) → dispatch. `handleRequest` takes an
  injectable `RouterDeps` so routing/CORS/status-code logic is unit-tested
  without real network calls or a real rate-limit window.
- **All three endpoints implemented to their full `DATA_MODEL.md` §10.2
  contracts** (`/translate`, `/generate-story`, `/cowrite-turn`) — `CLAUDE.md`
  §7 Milestone 5 lists all three under the Worker-setup step. Only
  `/translate` has a Flutter caller yet; the other two are built and
  Worker-side-tested now so Milestone 7 doesn't need to revisit this
  infrastructure, but have no Flutter integration until then.
- **Rate limiting:** ships *without* Cloudflare's native Rate Limiting
  binding configured in `wrangler.jsonc` (commented out, with instructions)
  — its Free-plan availability couldn't be confirmed from Cloudflare's docs.
  `src/rateLimit.ts` auto-detects `env.RATE_LIMITER` and falls back to a
  zero-cost in-memory per-isolate sliding window (30 req/60s per uid) when
  it's absent, per the project owner's explicit decision.
- **Tests:** 61 passing, run inside the real Workers runtime (`workerd`) via
  `@cloudflare/vitest-plugin` (the current package — during setup,
  `@cloudflare/vitest-pool-workers`'s `/config` export no longer existed in
  the installed version; current Cloudflare docs point at
  `@cloudflare/vitest-plugin`'s `cloudflareTest` instead, so that's what's
  wired up). Covers CORS, auth (a locally-generated JWKS/JWT, never the real
  Google endpoint), rate limiting (both paths), all three handlers'
  validation/success/failure paths, and the router's status-code/dispatch
  logic. `npm run typecheck` clean.

**Flutter-side integration (this repo):**
- `lib/utils/worker_config.dart` — `kWorkerBaseUrl`, a `--dart-define`-
  configurable base URL (defaults to `wrangler dev`'s local address).
- `lib/services/ai_worker_service.dart` — `AiWorkerService.translate()`,
  the only endpoint with a Flutter caller so far. Throws one
  `AiWorkerException` type on any failure (network/non-200/bad shape) —
  deliberately not split into notFound/networkError buckets the way
  `DictionaryApiService` is, since `/translate` has no meaningful "not
  found" case.
- `lib/services/auth_service.dart` — gained `getIdToken()`, used to
  authenticate every Worker call.
- `lib/services/vocab_word_service.dart` (new) — `findByWord` (duplicate
  check), `createWord` (new word, builds the write map directly with
  `FieldValue.serverTimestamp()` rather than reusing `VocabWord.toMap()`,
  which emits a concrete client-side `Timestamp` that wouldn't satisfy
  `firestore.rules`' `updatedAt == request.time`), `appendMeaning` (runs as
  a Firestore transaction, not a plain read-then-write, so two teachers
  editing the same word can't silently clobber each other).
- `lib/services/topics_service.dart` (new) + `lib/models/topic.dart` (new)
  — `fetchAll()`/`createOrGetTopic()` for the `topics` master list.
- `lib/utils/topic_slug.dart` (new) — Dart port of
  `tools/vocab_import/lib/seedDecision.js`'s `topicSlug()`, kept
  byte-for-byte identical (tested against the same cases as that file's
  Node test) so a guru-created topic's `docId` can never collide with or
  diverge from what the import pipeline would have chosen.
- `lib/utils/cefr_levels.dart` (new) — `kCefrLevels` extracted from
  `vocab_browser_screen.dart` (was a private list there) so the new Tambah
  Kosakata form uses the exact same six levels, not a second hand-copied list.
- `lib/providers/ai_worker_providers.dart`, `lib/providers/
  vocab_management_providers.dart`, `lib/providers/
  lazy_translation_providers.dart` (all new) — service providers,
  `topicsListProvider`, `vocabWordLookupProvider` (family, the duplicate
  check), `TambahKosakataController` (`createNewWord`/`appendMeaning` drive
  its `AsyncValue<void> state`; `generateTranslation`/`addNewTopic` are
  lighter per-row supporting actions that deliberately don't touch it), and
  `lazyTranslationProvider` (family, cached per `(word, pos)` for the rest
  of the session — exactly the in-memory caching `DATA_MODEL.md` §2 point 4
  asks for, with no extra caching code).
- `lib/screens/teacher/vocab_management/tambah_kosakata_screen.dart` (new)
  — replaces `VocabManagementPlaceholder` (deleted) as the real "Kosakata"
  destination body. Word field with blur-triggered duplicate check; if
  found, a compact "Tambah makna baru ke kata ini" flow (POS + generated
  translation only); otherwise the full new-word form (CEFR level, topic
  multi-select + add-new-topic, one-or-more meaning rows each with a
  "Buat Terjemahan" button that calls the Worker, primary-meaning labeling).
  Errors are always friendly text, never a raw Firestore/Worker error.
- `lib/screens/student/vocab_browser/word_detail_screen.dart` — the
  existing `_MeaningBlock` now renders a new `_LazyTranslationText` widget
  whenever `meaning.translation == null`, per `DATA_MODEL.md` §2 point 4:
  calls the Worker via `lazyTranslationProvider`, shows a small spinner
  while in flight, the result on success, and a dim "—" on failure — never
  written back to Firestore, never an error screen.
- `firestore.rules` — added `isGuru()` (the same `get()`-on-`users`-doc
  pattern `DATA_MODEL.md` §5 already documents for `targetWordSets`, reused
  here) and guru write rules for `vocabWords` (`create` for a new word,
  `update` for either the append-meaning shape or — added now since
  `DATA_MODEL.md` §2 documents both shapes as one pair, though unused until
  Milestone 8 — the topics-only Edit Kata shape) and `topics` (`create`
  only). No per-element array validation anywhere, per `CLAUDE.md` §6's
  explicit rule against rules that would need it.

**Tests added (Flutter side):** `test/utils/topic_slug_test.dart`,
`test/services/ai_worker_service_test.dart`,
`test/screens/tambah_kosakata_screen_test.dart` (new-word render/duplicate-
detect/generate-then-submit/submit-failure/add-meaning-row/append-meaning
flows, all against fake services — no real Firestore/Firebase Auth
touched), `test/screens/word_detail_lazy_translation_test.dart` (loading/
success/failure states, via a controllable fake `AiWorkerService`).
`test/screens/word_detail_screen_test.dart` updated (an
`_AlwaysFailingAiWorkerService` override added to every case, so the
existing fixture's null-translation meaning settles deterministically
rather than incidentally depending on Firebase-not-initialized). `test/
screens/destination_placeholders_test.dart` and `test/app_routing_test.dart`
updated for the placeholder's removal. **Full suite: 174/174 passing.**

**Known, disclosed test-coverage limitation:** `VocabWordService`/
`TopicsService`'s actual Firestore calls (as opposed to the pure logic
around them) aren't covered by an automated test — this project has no
Firestore fake/emulator test harness (the existing precedent,
`VocabBundleService.fetchDelta`, has the same gap and is tested the same
way: by subclassing to control just that method). Adding one (e.g.
`fake_cloud_firestore`) would be a new dependency requiring the
confirm-first step `CLAUDE.md` §6 asks for, not decided as part of this
milestone. This gap is no longer purely theoretical, though — §5h's
manual E2E pass exercised the real Firestore calls directly and they
worked, which is the closest thing to coverage this specific gap has.
`firestore.rules`' new guru-write rules were never mechanically validated
either (no Java available in this environment to run the Firestore
emulator), but **are now deployed and confirmed working against the real
project** by the successful writes in §5h.

## 5h. Manual End-to-End Verification (Milestone 5) — Including a Real CORS Bug Found & Fixed

The project owner deployed `vocably-ai-worker/` for real (`https://
vocably-ai-worker.refahilyaa.workers.dev`), deployed the updated
`firestore.rules` and the leftover Milestone-4 Firestore index, and ran
Flutter against both with `flutter run -d chrome --web-port=5555
--dart-define=WORKER_BASE_URL=https://vocably-ai-worker.refahilyaa.workers.dev`.

**A real bug surfaced during this pass — not a false alarm, and not
something the automated Worker tests could have caught** (they don't
exercise the deployed config, only the code): clicking "Buat
Terjemahan" failed with a browser CORS error
(`No 'Access-Control-Allow-Origin' header is present`). Investigated
against the actual deployed configuration rather than assumed — root
cause and fix:

- **Root cause:** `wrangler.jsonc` originally kept `http://localhost:5555`
  in a separate `env.development` block, on the assumption that local
  Flutter dev would always talk to a *locally-running* `wrangler dev`
  Worker. In practice, local Flutter dev pointed straight at the
  **deployed** Worker via `--dart-define=WORKER_BASE_URL`, and a plain
  `wrangler deploy` only ever reads the top-level `vars` — never
  `env.development`'s. So the live deployment's `ALLOWED_ORIGINS`
  genuinely never included `localhost:5555`, and `src/cors.ts` (unchanged,
  and correct) correctly rejected it. Not a matching-logic bug — a
  deployed-configuration/workflow mismatch.
- **Fix:** `http://localhost:5555` merged into the single top-level
  `vars.ALLOWED_ORIGINS` in `wrangler.jsonc`, alongside the two
  production Firebase Hosting origins (still three fixed, explicit
  strings — no wildcard, so this doesn't open the Worker to arbitrary
  origins). The now-redundant `env.development` block removed;
  `package.json`'s `dev` script simplified from `wrangler dev --env
  development` to `wrangler dev`; `README.md` updated accordingly.
  Verified: the relevant Worker CORS tests, the full Worker suite
  (61/61), and `npm run typecheck` (clean) all still passed after the fix.
- **Not deployed by Claude** — the project owner deployed this fix
  themselves after the code-level fix was made.

**Full manual E2E checklist, all confirmed working by the project owner
against the real deployed Worker and live Firestore:**

- [x] Guru login → "Kosakata" destination → Tambah Kosakata screen loads.
- [x] Topic list loads (from the live `topics` collection).
- [x] Duplicate-word detection (typing an existing word and blurring the
      field surfaces the "Kata ini sudah ada" notice).
- [x] CEFR level selection.
- [x] Selecting an existing topic.
- [x] Creating a brand-new topic.
- [x] The CORS bug above, found and fixed.
- [x] Lazy translation exercised against a real `vocabWords` document
      with one meaning's `translation: null` (a dedicated temporary test
      document, per the procedure worked out together — not a real
      Oxford word, no edit to real data).
- [x] The translation was successfully generated and displayed on Word
      Detail.
- [x] Confirmed the lazy translation is **not** persisted to Firestore
      (display-only, per `DATA_MODEL.md` §2 point 4 — matches the
      implementation, which never writes it back).
- [x] The temporary test document was removed afterward.
- [x] No test data left behind in `vocabWords` after cleanup.

**Not covered by this pass** (still only automated-test-verified, or not
yet re-checked at all — see §7): the vocab browse screen's pagination/
filtering re-verification and the Word Detail POS-alias words (`can`,
`billion`, `one`, `oh`, `this`) carried over from Milestone 4; the
`firestore.rules` negative path (confirming a signed-in **siswa** is
actually denied a `vocabWords`/`topics` write attempt) wasn't part of
this checklist either — only the guru-positive paths were exercised.

## 5i. Milestone 6 — Student Dashboard + Riwayat + Placement/Pre-Post-Test Scaffolds

Implemented per the plan the project owner approved (decisions: `intl` for
date formatting; the placement-test auto-offer as a full-screen
`_RootRouter` interstitial, not a dialog over the nav shell; the
`[[kata|bentuk]]` story-marker parser built now, shared-utility-only, no
Storyfier phase logic pulled forward).

**Scope actually implemented — all read paths, no Milestone 7/8 writes:**
- Real "Belajar" dashboard (`DashboardScreen`) replacing
  `DashboardPlaceholder`: "Target Kata Hari Ini" card (resolves
  `targetWordSets` → `VocabBundleEntry` list), "Level" card (6 CEFR pills,
  active level ring, C2 always visually muted, permanent Placement Test
  entry-point link), and a visually-separated Pre-Test/Post-Test section.
- Real "Riwayat" destination (`HistoryScreen`) replacing
  `HistoryPlaceholder`: two tabs ("Per Kata" — mastery-filterable word
  list with a present-but-inert "Pelajari Kembali" button; "Per Sesi" —
  session cards, tap → read-only story replay).
- One-time automatic placement-test offer (`PlacementTestOfferScreen`),
  shown by `_RootRouter` in place of `AppNavShell` whenever a signed-in
  student's `placementTestPrompted != true`; both choices flip that flag
  immediately via a new `UserService.markPlacementTestPrompted`.
- `PlacementTestPlaceholderScreen` (reachable from the offer's "Mulai
  Tes" and from the dashboard's permanent link) and
  `ResearchAssessmentPlaceholderScreen` (reachable from the Pre-Test/
  Post-Test banners) — both pure "Segera hadir" placeholders, no
  questions, no scoring, per `CLAUDE.md` §10's TBD status.
- Shared `utils/story_markers.dart` parser (`parseStoryMarkers`/
  `stripStoryMarkers`) — used today only by Riwayat's read-only replay;
  designed so Milestone 7's Fase 1/Fase 2 can reuse it unchanged for the
  live highlight/cloze-blank logic, without pulling any of that logic in
  now.
- New models (`TargetWordSet`, `LearningProgress`, `LearningSession`),
  new read-only services (`TargetWordSetService`,
  `LearningProgressService`, `LearningSessionService`), and new providers
  (`dashboard_providers.dart`, `history_providers.dart`,
  `placement_test_providers.dart`) — all following the existing
  model/service/provider layering (`CLAUDE.md` §4).
- `utils/target_word_constants.dart` — `kNoEndDate`/`kAllStudents`
  sentinels (`DATA_MODEL.md` §5, `CLAUDE.md` §4). Milestone 6 is the
  first code to actually *read* `targetWordSets` (Milestone 8 still owns
  writing it), so these constants are introduced now on the read side and
  must be reused, not re-declared, when Milestone 8 builds the write path.

**Implementation decisions worth flagging (not asked about individually,
resolved via existing convention + explicit scope boundaries):**
- **`learningProgress`/`learningSessions` queries are single-field
  equality (`studentId ==`) with in-memory sort/filter**, not the
  `studentId` + `masteryStatus`/`orderBy(startedAt desc)` composite
  queries `DATA_MODEL.md` §8 sketches. Firestore's automatic single-field
  index covers the equality-only query; combining it with an `orderBy`
  on a *different* field needs a composite index, and — per the real
  Milestone 4 incident where a documented-but-undeployed index took the
  whole vocab browse screen down once real data existed — deploying one
  for a collection nothing writes to before Milestone 7 seemed like
  needless risk for zero present benefit. Sort/filter happens in the
  provider layer instead (`applyHistoryFilter`, sort-by-`startedAt` in
  `learningSessionListProvider`), mirroring the in-memory-filter
  convention `utils/vocab_browse_filter.dart` already established. If
  Milestone 7's real data volume ever makes this a real cost, revisit
  then — not preemptively.
- **`targetWordSets`' query is implemented exactly as `DATA_MODEL.md` §5
  documents** (array-contains-any + `endAt` range/order, filtered by
  `startAt` client-side) — that one *does* get its documented composite
  index added to `firestore.indexes.json` now (§6), since the query
  shape itself is already fully specified and not something this
  milestone chose to deviate from.
- **One combined `PlacementTestPlaceholderScreen`, not the separate
  "body"/"result" screens `DESIGN_REFERENCE.md` §5.2 sketches** — those
  are two states of a test actually *in progress*, and with the scoring
  method and question set still fully TBD, nothing in this milestone can
  ever produce a transition from one to the other. Building an
  unreachable second screen for a result nothing can generate yet would
  be dead code, not scaffolding. Revisit this split once the instrument
  is decided.
- **`firestore.rules`' new read rules for `targetWordSets` (any signed-in
  user) / `learningProgress`/`learningSessions`/`placementTestResults`/
  `researchAssessmentResults` (owner-only, via `resource.data.studentId`)
  all deny every write** — none of these collections has a tested,
  approved write shape yet (guru's "Set Target Kata" is Milestone 8; the
  3-phase flow that produces progress/session data is Milestone 7; the
  scoring method and research instrument are both still TBD per
  `CLAUDE.md` §10). Writing a plausible-looking rule now, before the
  actual writer exists to test it against, is exactly what `CLAUDE.md`
  §6 asks to avoid.
- **Riwayat "Per Sesi" cards show each session's raw `wordIds` as chip
  labels, not resolved translations** — `DESIGN_REFERENCE.md` §3.3's
  mockup shows "kata + terjemahan kecil", but resolving a session's words
  to full `VocabBundleEntry`s (a session has no single `cefrLevel` of its
  own, unlike a target set) would mean the same all-6-levels lookup
  `historyWordEntriesProvider` already does for "Per Kata" — for a
  collection guaranteed empty until Milestone 7, that complexity wasn't
  worth adding to the card summary specifically (the session *detail*
  screen, reached by tapping, does the real work of parsing/highlighting
  the actual story). A trim, not an oversight — revisit once real session
  data exists to see if the raw wordId chips read poorly in practice.
- **`TargetWordListScreen`/Riwayat's "Pelajari Kembali" both keep their
  CTA buttons visible but `onPressed: null`**, with a small "Segera hadir
  di Milestone berikutnya" caption — per the project owner's explicit
  instruction to keep later-milestone CTAs present but inert rather than
  omitted.

**A real, pre-existing environment defect found during this milestone's
own test-verification pass (not caused by any Milestone 6 change):**
`flutter test` at its default concurrency silently drops a large,
non-deterministic subset of test files — confirmed by running the full
suite three times and diffing which files actually produced a test-result
line each time; the dropped set varied between runs (13 files missing in
one run, a different 12 in another) and included several pre-existing
files this milestone never touched (`test/models/dictionary_entry_test.dart`,
`test/models/vocab_bundle_entry_test.dart`, `test/services/ai_worker_service_test.dart`,
`test/services/dictionary_api_service_test.dart`, `test/utils/normalize_word_test.dart`,
among others) — and every one of these runs still printed **"All tests
passed!" with a successful exit code**, because the runner simply never
attempted the missing files rather than failing on them. `flutter test
--concurrency=1` reliably runs and reports on the complete suite (verified
three consecutive times) — see §9 for the trustworthy final numbers. This
is an environment/tooling issue with this machine's `flutter test`
concurrency handling, not a project code defect — but it means **every
past session's "`flutter test`: N/N passing" claims in this file's
history cannot be retroactively assumed to have covered every file**
unless they were independently re-verified with `--concurrency=1`. Not
re-auditing prior milestones' historical claims now (out of scope for
this pass), but flagging this clearly since it changes what "flutter
test passed" should be trusted to mean going forward — see the new
handoff note in §12.

**Tests added:** `test/utils/story_markers_test.dart` (9),
`test/utils/target_word_constants_test.dart` (2),
`test/utils/session_date_format_test.dart` (2),
`test/models/target_word_set_test.dart` (1),
`test/models/learning_progress_test.dart` (2),
`test/models/learning_session_test.dart` (2),
`test/services/target_word_set_service_test.dart` (5, against the pure
`filterStillActive` function — the actual Firestore query itself isn't
mechanically tested, same disclosed gap as `VocabWordService`/
`TopicsService` since Milestone 5: no Firestore fake/emulator in this
repo),
`test/providers/history_providers_test.dart` (7),
`test/providers/dashboard_providers_test.dart` (4, via `ProviderContainer`
+ fake services),
`test/screens/dashboard_screen_test.dart` (10),
`test/screens/history_screen_test.dart` (5),
`test/screens/placement_test_offer_screen_test.dart` (3).
`test/app_routing_test.dart` updated (+2 new cases: the unprompted-student
interstitial branch, and a defensive `null`-`placementTestPrompted` case).
`test/screens/destination_placeholders_test.dart` trimmed (Dashboard/
Riwayat groups removed — moved to their own dedicated test files above;
`TargetWordsPlaceholder`'s coverage, still real for Milestone 8, stays in
place).

**Not yet done (see §7):** deploying `firestore.rules`/
`firestore.indexes.json`; any manual browser click-through of the new
screens; confirming the placement-test offer's real Firestore write
actually satisfies the (unchanged) rules against the live project.

## 6. Firebase / Firestore State

- **Project:** `vocably-idn-en`, Firestore Native mode, `asia-southeast1`.
- **Collections modeled in rules:** `users`, `teacherAccessCodes` (Milestone 2); `vocabWords`/`topics` — read-only for any authenticated user, plus guru-only write rules added in Milestone 5 (§5g) for both; `targetWordSets`/`learningProgress`/`learningSessions`/`placementTestResults`/`researchAssessmentResults` — read-only rules added in Milestone 6 (§5i), all writes explicitly denied for now.
- **Real data status:** **confirmed populated** — 4,952 `vocabWords` documents + the `topics` master list, seeded for real by the project owner and confirmed in the Firebase Console (§5, Stage 3). `targetWordSets`/`learningProgress`/`learningSessions`/`placementTestResults`/`researchAssessmentResults` have **no real documents at all** — nothing in the app has ever written to any of them (Milestone 6 only reads; the respective writers are Milestones 7/8 and TBD).
- **`cefrLevel` + `updatedAt` composite index (§5b/§11.3):** **confirmed deployed and live** — verified directly against the project via `firebase firestore:indexes`, which returned exactly this index (plus Firestore's automatic `__name__` tiebreaker field), matching `firestore.indexes.json`. (This corrects an earlier snapshot of this file, which still listed the deploy as outstanding — the live project had already moved past that by the time this was checked.)
- **`targetWordSets` composite index (`targetStudentIds` array-contains + `endAt` ASC, §5i):** added to `firestore.indexes.json` this session, matching `DATA_MODEL.md` §5's documented query exactly — **not yet deployed**, see §7. `learningProgress`/`learningSessions` deliberately don't need a new index — see §5i's note on why those two collections' queries were designed to avoid one.
- **`vocabWords`/`topics` guru-write rules (§5g):** **deployed and confirmed working** — the project owner's manual E2E pass (§5h) successfully created a word, appended a meaning, and created a topic as guru through the real app, which only works if these rules are live. The rules' negative path (a signed-in siswa being denied) was not explicitly exercised in that pass.
- **Milestone 6's new read rules (§5i):** written, internally consistent with the models/services that read them, but **not yet deployed and not yet exercised against the real project** — nothing has manually verified that a signed-in student can actually read (or is actually denied writing to) any of these five collections through the live app yet. See §7.

## 7. Manual Actions Required

**Done since the last snapshot of this file** (kept here, struck through
in spirit, for the record — not deleted, since a future session should
know these happened and roughly when):

- ~~Deploy the Firestore composite index~~ — confirmed live (§6).
- ~~Deploy the updated `firestore.rules`~~ — confirmed live and working via real writes (§5h/§6).
- ~~Set up and deploy `vocably-ai-worker/` for real~~ — deployed to `https://vocably-ai-worker.refahilyaa.workers.dev`; a real CORS config bug was found and fixed in the process (§5h).
- ~~Manually re-verify Tambah Kosakata end-to-end~~ — done, full checklist in §5h, including the lazy-translation display and its non-persistence.

**Still genuinely outstanding:**

1. **Deploy Milestone 6's `firestore.rules`/`firestore.indexes.json` changes** (§5i/§6) — `firebase deploy --only firestore:rules,firestore:indexes`. Nothing in Milestone 6 has been exercised against the real project yet; the Dashboard/Riwayat screens will work against the live Firestore project's existing (Milestone 5) rules for anything they don't touch, but the new `targetWordSets`/`learningProgress`/`learningSessions`/`placementTestResults`/`researchAssessmentResults` reads will fail with `permission-denied` until this deploy happens.
2. **Manually click through Milestone 6 end-to-end** (`flutter run -d chrome`) — no automated test can replace a real signed-in student walking through: the placement-test offer appearing exactly once, the Level card's pills/ring/C2-muting, Target Kata's empty state (guaranteed, since no `targetWordSets` document exists yet), Riwayat's both tabs' empty states (guaranteed, same reason), and the Pre-Test/Post-Test entry points. See §7's temporary-test-data note below for exercising the *non*-empty states.
3. **To see the "Target Kata Hari Ini"/Riwayat populated states** (not just their empty states), you'll need temporary test documents — same pattern as Milestone 5's lazy-translation test document. A minimal `targetWordSets` doc: `teacherId` (any existing guru uid), `wordIds` (array of real, already-seeded `vocabWords` docIds, e.g. `["run"]`), `cefrLevel` (matching those words' actual level, e.g. `"A1"`), `startAt`/`endAt` (Timestamps bracketing now — e.g. yesterday/`kNoEndDate`-style far future), `targetStudentIds: ["__all__"]`, `createdAt` (Timestamp, now). A minimal `learningProgress` doc (`docId = "{yourTestUid}_run"`): `studentId`, `wordId: "run"`, `learnedStatus: "sudahDipelajari"`, `masteryStatus: "difficult"` (or `"mastered"`), `firstLearnedAt`/`lastUpdatedAt` (Timestamps), `lastSessionId: "test-session"`. A minimal `learningSessions` doc: `studentId`, `wordIds: ["run"]`, `sourceType: "keranjangPelajari"`, `currentPhase: "selesai"`, `storyTitle`, `storyContent: "I [[run|ran]] today."`, `storyTranslation` (optional), `clozeTestResult: {"run": true}`, `cowriteTranscript: []`, `cowriteWordsUsedCorrectly: ["run"]`, `startedAt`/`completedAt` (Timestamps). Remove all three afterward — same cleanup discipline as Milestone 5's test document.
4. **Confirm whether Cloudflare's native Rate Limiting binding is available on your Workers plan** (§5g) — **still unconfirmed either way; the Worker is still running on the in-memory fallback.** If you confirm it's available, uncomment the `unsafe.bindings` block in `vocably-ai-worker/wrangler.jsonc` (no code change needed elsewhere) and redeploy. Do not treat this as done until you've actually checked your plan's dashboard/docs.
5. **Optionally exercise the `firestore.rules` negative path** — confirm a signed-in siswa attempting to create/update `vocabWords` or create a `topics` doc is actually denied (Milestone 5), and (new, Milestone 6) that a signed-in student can't read another student's `learningProgress`/`learningSessions`/`placementTestResults`/`researchAssessmentResults` documents. Not part of any automated pass — no Firestore emulator in this environment.
6. **Manually re-verify the browse screen** (`flutter run -d chrome`) — confirm pagination (§5e: "Halaman X dari Y", Previous/Next, resets on level/mode/filter change) and that A1/A2/B1 × Abjad/Tema all still load correctly end-to-end. Carried over from Milestone 4 — still only automated-test-verified. Not a blocker for any milestone since.
7. **Manually re-check Word Detail** for words like "can" (modal), "billion" (number), "one", "oh", "this" now that the extended alias table and the loading/retryable/unavailable UI split are in place (§5c/§5d) — verified via unit/widget tests only so far. Carried over from Milestone 4 — not a blocker for any milestone since.
8. **Review the 10 same-POS collisions** in `tools/vocab_import/output/import_report.json` (`samePosCollisions`) — not blocking, but worth a look since the schema can only keep one sense per POS.
9. **Optionally spot-check translation quality** beyond what this session sampled — `tools/vocab_import/output/canonical_vocab_translated.json` has all 4,952 documents; the "equal"/noun case (§5) is the one known imperfect example found so far.
10. **Going forward, run `flutter test --concurrency=1`, not plain `flutter test`** (§5i/§9) — the default-concurrency run on this machine has been confirmed (three separate runs) to silently skip a large, non-deterministic subset of test files while still exiting successfully. `--concurrency=1` is slower (~40–50s vs. ~10–20s here) but is the only mode confirmed to actually run and report on every test file.
11. Decide whether/when to `git add`/commit/push the current working tree in **both** repos — not done automatically, per your standing instruction. See §10 for exactly what's pending in each.

## 8. Important Architectural Decisions (this session)

- **`translationId` renamed to `translation`** everywhere (Dart models, Firestore field, bundle field, the new import pipeline, tests, docs) — the old name wrongly implied a foreign key into a separate collection; it always held the translation text directly, and no separate `translations` collection exists or is planned. Safe to do because `vocabWords` had no real production data yet.
- **`cefrLevel` stays one-per-document, set to the LOWEST level found across a word's contributing CSV rows** — all distinct meanings/POS are kept regardless of the level they originally came from (per-word, not per-meaning, CEFR — a known, accepted simplification, documented in `DATA_MODEL.md` §2).
- **Oxford 3000 + Oxford 5000 are one merged dataset** — a word in both becomes one document; `source` = `"oxford3000"` if present there, else `"oxford5000"` (no new enum value).
- **`CLAUDE.md`/`DATA_MODEL.md`'s "CSV import is not Claude's job" language was revised** (not deleted) to: Claude may write/maintain the pipeline; secrets and the first full run of a costly/production-writing stage stay developer-gated. See `tools/vocab_import/README.md` for the exact split.
- **Same-POS collisions are surfaced, not silently resolved** — first-encountered row wins, the discarded alternative is logged for manual review, since the current schema has no way to represent two senses of the same POS for one word.
- **`test/screens/vocab_browser_screen_test.dart` now injects a fake `AssetBundle`** instead of relying on the real `rootBundle` — needed once real, sizeable bundle files existed (a `flutter test` fake-async-pump artifact, not a production bug; see §5's Stage 4 entry for the full explanation). Follow this same pattern (reuse the existing `_FakeAssetBundle`/`_EmptyAssetBundle` style) for any future widget test that touches `vocabLevelProvider`.
- **`test/services/vocab_bundle_service_test.dart` gained two tests exercising `loadLevelWithDelta`'s failure path directly** via subclassing (`_ThrowingDeltaVocabBundleService`/`_StubDeltaVocabBundleService`, overriding just `fetchDelta`) — the first direct test coverage this method has ever had (previously flagged as a disclosed gap since it needs Firestore). Follow this same subclassing pattern for any future test needing to control `fetchDelta` without a real/fake Firestore instance.
- **`DictionaryEntry.definitionsForPos` alias table** (`modal`/`auxiliary`→`verb`, `number`→`numeral`/`noun`, `exclamation`→`interjection`, `determiner`→`pronoun`/`adjective`) reconciles Vocably/Oxford's POS taxonomy against DictionaryAPI's Wiktionary-derived tags — confirmed empirically against the live API twice (§5c, §5d), not guessed. `article` deliberately left unmapped (no evidence-based equivalent found). Extend this table, not the matching logic's shape, if another mismatch is found later.
- **Word Detail's dictionary content is now a 4-state sealed type** (`_DictionaryLoading`/`_DictionaryFound`/`_DictionaryUnavailable`/`_DictionaryRetryable`, `word_detail_screen.dart`) instead of a flat nullable list — loading, a permanent content gap, and a transient/retryable failure are visually distinct, with a working retry action for the last one. Follow this same distinction (don't collapse states back into one) if this screen changes again.
- **Vocabulary browse is paginated (50/page, §5e)** — always filter/sort first via `applyVocabBrowseFilter`, then paginate via `paginate()`. Never paginate before filtering.
- **Milestone 5 decisions (project owner, this session):** Worker as a separate sibling repo (`vocably-ai-worker/`); reuse the existing Dinoiki OpenAI-compatible endpoint/model rather than switching providers; `wrangler dev` for local Worker development (not a dev-flag on the deployed Worker); an in-memory rate-limit fallback (not a paid plan) if the native Cloudflare binding turns out unavailable on Free; Tambah Kosakata only this milestone, no inert Edit Kata tab — see §5g.
- **`VocabWordService.createWord`/`appendMeaning` build their Firestore write maps directly, not via `VocabWord.toMap()`** — that method emits a concrete client `Timestamp`, which can't satisfy `firestore.rules`' `updatedAt == request.time`; a client write needs an actual `FieldValue.serverTimestamp()` sentinel (same pattern `AppUser.newStudentData()` already uses for `users.createdAt`). Follow this same distinction if another client-side Firestore writer is added later.
- **`topicSlug()` (Dart) must stay byte-for-byte identical to `tools/vocab_import/lib/seedDecision.js`'s version** — both compute the same `topics` collection's `docId`. If one changes, change the other and re-verify both test suites.
- **`vocably-ai-worker/`'s CORS allowlist is a single flat list (`wrangler.jsonc`'s top-level `vars.ALLOWED_ORIGINS`), not split across a `vars`/`env.development` divide** (§5h) — the earlier per-environment split assumed local Flutter dev always talks to a locally-running `wrangler dev` Worker, but the real workflow points the local client straight at the deployed Worker via `--dart-define=WORKER_BASE_URL`, which only ever reads the top-level `vars`. If Worker environment-specific config is reintroduced later, keep this lesson in mind — verify what a plain `wrangler deploy` actually reads before assuming a dev-only origin is safely isolated.
- **Milestone 6 decisions (project owner, this session):** `intl` added as a normal dependency for `d/M/yyyy HH:mm` formatting rather than hand-rolled date formatting; the placement-test auto-offer is a full-screen `_RootRouter` interstitial (not a dialog layered over `AppNavShell`); the `[[kata|bentuk]]` story-marker parser (`utils/story_markers.dart`) was built now as a standalone shared utility, with no Storyfier phase/UI logic pulled forward — see §5i for the full write-up.
- **`learningProgress`/`learningSessions` are queried with single-field equality only (`studentId ==`), sorted/filtered in the provider layer** — not the `studentId` + `masteryStatus`/`orderBy(startedAt desc)` composite queries `DATA_MODEL.md` §8 sketches. Deliberately avoids needing a new composite index for two collections nothing writes to before Milestone 7, learning from the real Milestone 4 incident where an undeployed documented index took down a whole feature once real data existed. `targetWordSets`' query, by contrast, **is** implemented exactly as `DATA_MODEL.md` §5 already specifies, composite index included — see §5i for the full reasoning on why these two collections were treated differently.
- **A real `flutter test` environment defect was found this session**: default concurrency silently drops a non-deterministic subset of test files (new and pre-existing) while still reporting success. Always use `--concurrency=1` for a trustworthy full-suite run in this environment — see §5i/§9/§12.
- All Milestone 1–5 decisions from the previous snapshot (Riverpod-only, no routing package, no `custom_lint`, rules-enforced role assignment, `definitionsForPos` alias table, paginate-after-filter, Milestone 5's Worker/rate-limiting/CORS decisions, etc.) remain unchanged and still apply — not re-litigated this session.

## 9. Verification Status

- `flutter analyze`: **no issues**.
- `flutter test`: **225/225 passing — but only reliably observed via `flutter test --concurrency=1`** (verified three consecutive full runs at this concurrency, each covering all 32 test files with zero failures). **The default-concurrency invocation is not trustworthy on this machine** — it silently skipped a different, non-deterministic subset of test files (12–13 of 32) across repeated runs while still printing "All tests passed!"; see §5i for the full finding, including the exact file-diffing method used to confirm it. The 225 total reconciles exactly against arithmetic from the prior 174-test snapshot plus this session's additions/removals (see §5i's "Tests added" list) — cross-checked, not just trusted at face value.
- `tools/vocab_import` pure-logic tests (`node --test`): **43/43 passing** (untouched this session).
- **`vocably-ai-worker/` (separate repo) tests:** `npm test` (Vitest, real `workerd` runtime via `@cloudflare/vitest-plugin`) — **61/61 passing** (unchanged this session — no Worker code touched). `npm run typecheck` — clean.
- Stage 1–4 (Milestone 4 data pipeline): unchanged, still real/complete — see §5 for detail.
- **Post-seed bug found and fixed** (§5b), **English-definition gaps investigated twice** (§5c/§5d), **pagination added** (§5e) **and its overflow fixed** (§5f) — all as previously recorded, unchanged this session.
- **Milestone 5 implemented, deployed, and manually verified end-to-end** (§5g/§5h): Worker (all 3 endpoints to their documented contracts, auth/CORS/rate-limiting infrastructure), Flutter integration (services/providers/screens), `firestore.rules` guru write access. A real CORS configuration bug was found during the manual pass and fixed (§5h) — re-verified after the fix: Worker suite 61/61, `npm run typecheck` clean. **What manual verification actually covered vs. didn't** is spelled out precisely in §5h — don't assume everything is checked; in particular, Rate Limiting plan availability is explicitly still unconfirmed (§7).
- **Milestone 6 implemented and automated-test-verified only** (§5i) — `firestore.rules`/`firestore.indexes.json` changes are written but **not deployed**, and **no manual browser verification has happened yet**. Do not treat Milestone 6 as done the way Milestone 5 is; §7 lists exactly what's still needed, including temporary test-data instructions for exercising the non-empty dashboard/Riwayat states.

## 10. Current Git State

- **Flutter repo (`vocably/`) — branch `main`, in sync with `origin/main`.** Milestone 4 + the pagination-bar fix are **committed and pushed** (`bab8170 Fix vocabulary pagination layout`, on top of `24cd651 Complete Milestone 4 vocabulary module`).
- **Flutter repo working tree: modified but uncommitted.** All of Milestone 5's new/changed files (§5g) plus all of Milestone 6's new/changed files (§5i: new models/services/providers/screens/utils, `lib/app.dart`, `lib/services/user_service.dart`, `firestore.rules`, `firestore.indexes.json`, `pubspec.yaml`/`pubspec.lock` for `intl`, and the two deleted placeholder screens), this file's updates, plus a small unrelated `.gitignore` addition (`.dev.vars` — not something this session added; noted here rather than silently left unexplained, see §12 note on reviewing untracked/unexplained changes before committing). The CORS bug (§5h) was entirely a `vocably-ai-worker/` fix, nothing on the Flutter side. Commit/push remains the project owner's action per standing instruction.
- **`vocably-ai-worker/` (sibling repo, `c:\Users\isaan\projects\flutter\vocably-ai-worker`): now has its own first commit** (`915289b Initialize Vocably AI Worker`, made by the project owner — not this session). **Working tree on top of that commit is modified but uncommitted**: the CORS fix (§5h) — `wrangler.jsonc`, `package.json`, `README.md`. Entirely separate git history from the Flutter repo (separate `.git`, no remote configured yet as far as this session can see).

## 11. Next Recommended Step

**Milestone 5 is complete** — implemented, deployed, and manually
verified end-to-end (§5g/§5h). **Milestone 6 is implemented and
automated-test-verified, but NOT yet deployed or manually verified**
(§5i/§7/§9) — deploying the new rules/indexes and a real browser
click-through are the two concrete remaining steps before it can be
called complete the way Milestone 5 is.

1. **Deploy Milestone 6's `firestore.rules`/`firestore.indexes.json`** (§7 item 1).
2. **Manually click through Milestone 6** — dashboard, Riwayat (both tabs), the one-time placement-test offer, the placeholder screens — using §7 item 3's temporary test-data recipe to see the non-empty states.
3. Decide on git history for both repos (§10) — commit/push each independently whenever ready. Worth a look at the stray `.gitignore` change (§10) before committing, to confirm it's intentional.
4. Optionally work through §7's remaining (non-blocking) items — Rate Limiting plan confirmation, rules negative-path checks, two Milestone-4-era re-verification items.
5. **Per `CLAUDE.md` §7's documented milestone order, Storyfier core (the 3-phase learning flow) is Milestone 7** — that's next in sequence once Milestone 6 is confirmed deployed/verified, **not started, not to be started without explicit instruction.**

## 12. Handoff Instructions for a New AI Session

1. Read this file first for orientation, then `CLAUDE.md` in full (its own header requires this every session).
2. Read `SPEC.md`, `DATA_MODEL.md`, `DESIGN_REFERENCE.md` as needed.
3. **Inspect the live repository** before changing anything — `git log`, `git status`, actual file contents, and (for the import pipeline) `tools/vocab_import/output/*.json` and `translate_full_run.log` for the real current data-population state. This file drifts; the repository doesn't. **Also check the sibling `vocably-ai-worker/` repo** (`c:\Users\isaan\projects\flutter\vocably-ai-worker`, separate `git log`/`git status`) — it's a separate codebase from Milestone 5 onward (§5g) and this file's view of it can go stale independently of the Flutter repo's.
4. Check whether §7's manual actions (Firestore index/rules deploys, Worker setup/deploy) have already been done since this snapshot was written.
5. Preserve §8's decisions unless the project owner explicitly reopens discussion on one of them.
6. **Before committing anything, `git status`/`git diff` for anything not attributable to a documented change in this file** (e.g. §10's note on a `.gitignore` line neither this session nor the previous one added) — surface it to the project owner rather than assuming it's fine to commit or silently reverting it.
7. **Always run `flutter test --concurrency=1`, never plain `flutter test`, when the result needs to be trustworthy** (§5i/§9) — this environment's default test concurrency has been confirmed (three separate runs) to silently skip a non-deterministic subset of test files while still reporting success. If a future session forgets this and reports a suspiciously-round "all passing" number, re-run with `--concurrency=1` and diff the file coverage before trusting it.
