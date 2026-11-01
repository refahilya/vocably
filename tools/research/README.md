# tools/research — research instrument tooling

Developer-side tooling for Vocably's **pretest/posttest research instrument** and the **Placement Test (PT-V1.1)**.
It is not part of the Flutter app: nothing here ships, and nothing here runs
at app runtime. The instrument build has no npm dependencies. The emulator
tests and the researcher tools use three pinned dev-only dependencies (see
[Security-rules tests](#security-rules-tests-local-firestore-emulator)).

**What this tooling covers:**
- **Instrument data (research Milestone 1):** builds the app-safe bank of
  items and options from the researcher's PDF and writes the private answer
  key outside the repository.
- **Security-rules tests (Milestone 2a):** the research rules in
  `firestore.rules`, tested against local emulators only.
- **App side (M2b-1 – M2b-4, in `lib/`):** the bank loader and attempt
  planner, answer persistence (`lib/services/research_assessment_service.dart`,
  `lib/providers/research_assessment_providers.dart`) and the student test
  screens (`lib/screens/student/research_assessment/`).
- **M2b-3:** [researcher administration](#researcher-administration-m2b-3)
  (`bin/research_admin.js`).
- **M2b-5:** the [emulator workflow](#running-the-app-against-the-emulators-m2b-5)
  and end-to-end emulator tests.
- **M2b-6:** [offline export and scoring](#export-and-scoring-m2b-6)
  (`bin/export_results.js`).
- **Placement Test PT-V1.1:** [bank build, scoring model, study/stage
  controls, review/void tooling and export](#placement-test-pt-v11)
  (`bin/build_placement.js`, `bin/research_admin.js`, `bin/export_placement.js`).

**Current status** — what is committed, deployed, verified or still pending,
including the open research decisions (B2-06, retention, session-4
verification, placement policy questions, …) — is kept only in
[`HANDOFF.md`](../../HANDOFF.md).

## Source of truth

The only authoritative source for the instrument is the researcher's PDF,
**`Rancangan_Instrumen_Pretest_Vocably.pdf`** (15 pages). It defines the
items, the options, the answer key, the scoring rubric and the procedure.
The PDF contains the answer key (§7), so:

- it is **not** in this repository and must never be added to it;
- keep your copy somewhere private and outside OneDrive.

The instrument design is complete. **Expert validation and the pilot with
non-respondents are still pending**, so nothing here claims the instrument
is valid or reliable (PDF §10).

## What the instrument is (from the PDF)

- **Bands and items:** 4 bands (A2, B1, B2, C1) × 20 multiple-choice items = 80 items.
  - A student takes only the 20 items of their assigned band.
  - The pretest and the posttest use the same 20 items.
- **Each item:** an English word with its word class. Students choose one of:
  - four Indonesian meanings a–d: one key and three distractors;
  - e) **"Saya tidak tahu kata ini"** ("I don't know this word").
- **Key spread:** in the reference order, the key is balanced (a, b, c and d are each the key of 5 items per band).
- **Word classes per band** (§3.4):

  | Band | Noun | Verb | Adjective |
  |---|---|---|---|
  | A2 | 15 | 0 | 5 |
  | B1 | 13 | 2 | 5 |
  | B2 | 7 | 7 | 6 |
  | C1 | 10 | 4 | 6 |

- **Placement → band** (§2) — **implemented with PT-V1.1** (decision by the
  researcher): a scored research placement attempt sets the band
  automatically (A1/A1* → A2; C1 → excluded, no band). Participants enrolled
  with the original `enrol` command keep a researcher-assigned band. See
  [Placement Test PT-V1.1](#placement-test-pt-v11):

  | Placement level | Band |
  |---|---|
  | A1 | A2 |
  | A2 | B1 |
  | B1 | B2 |
  | B2 | C1 |

  The pretest/posttest tooling works for both kinds of participants.
- **Procedure:**
  - Treatment: 4 sessions × 5 of the band's 20 target words, each through Storyfier Reading → Cloze → Co-Write.
  - The posttest runs **immediately after session 4**, with independently reshuffled item and option order.
  - Planned sample: **35–40 students** (§9.4).

### Scoring rules (PDF §8–§9; scoring happens offline, never in the app)

| Code | Response | Score |
|---|---|---|
| B | the key option | 1 |
| S | a distractor (a–d, not the key) | 0 |
| T | "Saya tidak tahu kata ini" | 0 (recorded separately) |
| K | no response / data missing | 0 (count reported) |

- **Test score** is the number of B codes, from 0 to 20. There's no weighting, no partial credit, no guessing correction and no score bands.
- **Gain** = Post − Pre. It can be negative, and negative values are kept.
- **N-gain** = (Post − Pre) / (20 − Pre). It's **undefined and not calculated when Pre = 20**; report how many were excluded.
- **Missing a whole test:** a student who misses the pretest or the posttest is excluded from the paired analysis, and the number and reasons are reported.
- **Technical interruption:** recorded; if the test can't continue, the student retakes it and the incident is reported.

### Behaviour required of the app

- Item order and the order of options a–d are shuffled per student and per stage (`Random.secure()`), with pretest and posttest shuffled independently. "Saya tidak tahu kata ini" always comes last.
- The selected option is stored by its **opaque option ID and its text** (plus its display position), never by a displayed letter.
- Students see no correctness feedback, scores or answers.
- The instructions and example item are shown verbatim from PDF §5. No progress counter is shown (the PDF doesn't specify one; pending researcher decision).

## Files

| Path | What it is | In Git? |
|---|---|---|
| `bin/build_instrument.js` | CLI: PDF → validated bank (+ optional private key and report) | yes |
| `bin/run_rules_tests.js` | Starts local Firestore + Auth emulators (demo project), runs `test/rules/*.test.js`, stops them | yes |
| `bin/start_emulators.js` | Starts the emulators for manual app testing (`npm run emulators`) | yes |
| `bin/seed_emulator.js` | Dummy accounts + research setup in the running emulators (`npm run seed:emulator`) | yes |
| `bin/research_admin.js` | Researcher administration: seed bank, enrol, authorize, void, retake, status (`npm run admin`) | yes |
| `bin/export_results.js` | Offline key validation, scoring and CSV export (`npm run export`) | yes |
| `bin/build_placement.js` | Placement item file → validated app-safe bank (+ optional private key) (`npm run build:placement`) | yes |
| `bin/export_placement.js` | Offline Placement Test export with derived band scores and flags (`npm run export:placement`) | yes |
| `lib/placement/` | Placement constants, K2 scoring (`scoring.js`), bank build/validation (`build.js`) | yes |
| `lib/` | parser, validation/build, output-path guard, vocab lookup, report, `researchInstrument` document builder, `emulatorEnv.js` | yes |
| `lib/admin/` | target safety (`target.js`), CSV parser, operations, placement/study operations (`placementOperations.js`), emulator seed, CLI helpers | yes |
| `lib/export/` | scoring (`scoring.js`), CSV layout and Firestore read (`files.js`), placement export (`placement.js`) | yes |
| `test/` | `node --test` suite (synthetic fixtures only); `test/rules/` = emulator-only suites; `test/fixtures/client_payloads.json` and `test/fixtures/placement_client_payloads.json` = the app's payloads, generated by the Flutter tests `test/research_client_payloads_test.dart` and `test/placement_client_payloads_test.dart` | yes |
| `package.json`, `package-lock.json` | pinned dev dependencies | yes |
| `node_modules/`, `firestore-debug.log` | local install / emulator log | no (ignored) |
| `../../assets/research/instrument_v1.json` | **App-safe bank** (no answer key), bundled by the Flutter app | yes |
| `../../assets/placement/placement_bank_pt_v1_1.json` | **App-safe Placement Test bank** (no key), bundled by the Flutter app | yes |
| `<your path>.private.json` | **Private answer key**, written only where you say | **never** |
| `<your path>.private.md` | **Private comparison report** (contains the key) | **never** |

### App-safe bank schema (`assets/research/instrument_v1.json`)

```jsonc
{
  "schemaVersion": 1,
  "instrumentId": "vocably-pretest-posttest",
  "instrumentVersion": "v1",
  "status": "…expert validation and the non-respondent pilot are pending…",
  "source": { "title": "…", "fileName": "Rancangan_Instrumen_Pretest_Vocably.pdf", "sha256": "<sha256 of the PDF>" },
  "bands": ["A2", "B1", "B2", "C1"],
  "itemsPerBand": 20,
  "optionOrder": "…stored in reference order; shuffled at runtime…",
  "dontKnowOption": { "id": "dont_know", "text": "Saya tidak tahu kata ini" },
  "items": [
    {
      "id": "A2-01", "band": "A2", "number": 1,
      "word": "climate", "pos": "noun", "posLabel": "kata benda",
      "options": [ { "id": "opt_…12 hex…", "text": "…" }, … 4 in total ]
    }
  ]
}
```

- **Item IDs:** `<band>-<two-digit number>`, in the PDF's reference order.
- **Option IDs:** `opt_` + 12 hex characters of `sha256("v1|<itemId>|<option text>")`.
  - They're stable: rebuilding from the same PDF gives the same IDs.
  - They're opaque: they don't depend on the option's letter or on whether it's the key.
- **Option order:** the four options are stored in reference order. Shuffling is the app's job in a later milestone.
- **"Tidak tahu" choice:** `dontKnowOption` is a separate choice with the same ID on every item. It's never one of the four options, and it can never be the key.
- **No key data:** the bank has **no** key, correctness, letter or score field. The build and both test suites check this.

### Private answer-key schema

The key is a JSON object holding:
- a `warning` field;
- `instrumentId` and `instrumentVersion`;
- `source` (the PDF's file name and sha256);
- `bankSha256`, which ties the key to the exact bank file;
- `entries`: one per item, each with `{ itemId, band, word, correctOptionId, referenceLetter, correctOptionText }`. The last two are there so the key can be checked against the PDF.

## Running the build

You need **`pdftotext`** (xpdf or poppler) on `PATH`, or pass `--pdftotext <path>`. Git for Windows ships xpdf's `pdftotext` 4.00 in `/mingw64/bin`.

All commands run from `tools/research/`:

```bash
# Validate only: compares against the committed bank and writes nothing.
node bin/build_instrument.js --pdf "<path to the PDF>" --check

# Regenerate the app-safe bank (assets/research/instrument_v1.json).
node bin/build_instrument.js --pdf "<path to the PDF>"

# Also write the private comparison report and/or the private answer key.
node bin/build_instrument.js --pdf "<path to the PDF>" --check \
  --report-out "<private folder>/instrument_v1_comparison.private.md" \
  --key-out    "<private folder>/instrument_v1_key.private.json"
```

What the build checks (it stops on the first failed category and lists every problem in it):
- **Items:** exactly 80 unique items, 20 per band, numbered 1–20.
  - Each has 4 options a–d and e) exactly "Saya tidak tahu kata ini".
  - No text is left unparsed.
  - No unexpected characters.
- **Duplicates:** no repeated option text within an item or within a band; no repeated target word.
- **Word classes:** the counts match the PDF's §3.4 table, which is read from the PDF itself.
- **Key:**
  - one key entry per item in §7, and §7 has exactly 80 entries;
  - the letter is the same in both extraction modes (`-layout` and, where available, `-table`);
  - the text printed in the key cell is the text of the option that letter points to;
  - letters balanced 5/5/5/5 per band, as stated in the PDF's §3.2.
- **Bundle:** the bank contains no key-like field.
- **Vocabulary:** every target word is checked against `assets/vocab/vocab_<band>.json` (same trim + lowercase as `normalizeWord()`). Mismatches are **reported**, not fixed.

The terminal shows only counts, item IDs and file paths, **never key content**.

### Where the private files may go

`--key-out` and `--report-out` have **no default**: you always name the file. The tool refuses, and writes nothing at all, when the path:
- doesn't end in `.private.json` (key) or `.private.md` (report);
- is in a folder that doesn't exist (create the folder yourself);
- is inside this repository, inside **any** Git working tree, or inside a **OneDrive** folder (from the `OneDrive*` environment variables or any `OneDrive…` folder name);
- already exists (it never overwrites).

On this machine, `Documents` and `GitHub` live under OneDrive, so use a plain local folder, for example `C:\Users\<you>\vocably-private\`. Create it yourself and keep it out of any sync or backup service you don't control.

`.gitignore` also ignores `*.private.json` and `*.private.md` as a second line of defence.

### After generating the key

1. Review the comparison report against the PDF, item by item. Rows marked **wrapped** are key cells that wrap onto a second line in the PDF table, so check them by eye.
2. Check the key against a fresh build without printing it:
   ```bash
   VOCABLY_INSTRUMENT_PDF="<pdf>" VOCABLY_INSTRUMENT_KEY="<key>.private.json" npm test
   ```
3. Delete the report once you've reviewed it. Back up the key privately; it's needed for scoring.

## Tests

```bash
cd tools/research && npm test   # node --test
```

- **Synthetic tests:** the parser, build, validation and path-safety tests use invented items only, so no real answer appears in a test name, message or fixture.
- **`test/bankAsset.test.js`:** checks the committed bank (counts, IDs, option uniqueness, the "tidak tahu" choice, no key fields, word-class composition, vocab lookup).
- **`test/sourcePdf.test.js`:** **skipped** unless `VOCABLY_INSTRUMENT_PDF` (and, for the key check, `VOCABLY_INSTRUMENT_KEY`) is set. Its assertions report booleans and counts only.
- **`test/instrumentDocs.test.js`:** the `researchInstrument` documents mirror the bank exactly and carry no key fields.
- **`test/scoring.test.js`:** offline scoring with a **synthetic** key (B/S/T/K, gain, N-gain incl. pre = 20, incomplete/missing stages, voids and retakes, conflicting attempts, authorization states, invalid records, key validation, no UIDs in analysis files).
- **`test/adminUnits.test.js`:** strict CSV parsing, target safety (emulator vs production), argument parsing, audit-log and export-folder location checks, CSV encoding.
- **`test/rules/*.test.js`:** the emulator suites (security rules, admin tooling, the end-to-end flow). **Skipped** in a plain `npm test`; they run only inside the emulators (below).

A plain `npm test` skips the two PDF/key checks (unless their environment variables are set) and the emulator suites. Latest results: [`HANDOFF.md`](../../HANDOFF.md) §3.

The Flutter suite also has `test/research_instrument_asset_test.dart`, which checks that the asset is bundled and carries no key fields.

## Security-rules tests (local Firestore Emulator)

Research Milestone 2a. These tests exercise the real `firestore.rules` from the repository root against a **local** Firestore Emulator. **Nothing is deployed, and production is never contacted.**

### Safety

- The emulator runs under the demo project **`demo-vocably-test`**. Firebase treats `demo-*` projects as offline-only, so no production resource can be reached and no login or credentials are used. The real project `vocably-idn-en` is never passed to any command.
- `bin/run_rules_tests.js` runs only `firebase emulators:exec --only firestore,auth …` (one test file at a time, since they share the emulators), never `deploy`, and removes `GOOGLE_APPLICATION_CREDENTIALS` from the child environment.
- Each test file skips itself unless `FIRESTORE_EMULATOR_HOST` (and, for the end-to-end file, `FIREBASE_AUTH_EMULATOR_HOST`) points at `127.0.0.1`/`localhost` and the project ID starts with `demo-`.
- Every participant is synthetic (`stu-a2`, …) and every answer is fabricated (a fixed display position). The tests never read the answer key; the export test uses a synthetic key.
- Suites:
  - `researchRules.test.js`: the rules, with trusted records written through the testing library's rules-disabled context.
  - `adminTooling.test.js`: the researcher tooling through the Admin SDK, then the real rules checking what students can do afterwards.
  - `clientFlow.test.js` (one end-to-end test): a dummy student signs in through the **Auth emulator** (a real ID token) and replays the app's exact payloads (`test/fixtures/client_payloads.json`) through create, interruption and resume, duplicate/changed answers, early and final completion, posttest gating, void and retake. Then the offline export scores the result.

### Prerequisites

| Tool | Requirement | On this machine (2026-10-24) |
|---|---|---|
| Firebase CLI | `firebase` on `PATH` (or set `FIREBASE_CLI`) | firebase-tools **15.32.0** (global npm install) |
| Java | **21 or newer.** firebase-tools 15 refuses older Java for emulators (`MIN_SUPPORTED_JAVA_MAJOR_VERSION = 21`) | System JDKs are 1.8, 17 and 19, all too old. A **portable** Eclipse Temurin **21.0.12.1** is unpacked at `%USERPROFILE%\.vocably-dev\jdk-21.0.12.1+1` (outside the repo and OneDrive; no system setting changed) |
| Node | `>= 20` | 25.2.1 |
| npm dev dependencies | `@firebase/rules-unit-testing` **5.0.2** and its required peer `firebase` **12.19.0**, plus `firebase-admin` **14.5.0** for the researcher tools (added in M2b-3; all pinned exactly) | installed with `npm install` |
| Firestore emulator JAR | downloaded automatically on first run | `cloud-firestore-emulator-v1.22.0.jar` in Firebase's user cache (`%USERPROFILE%\.cache\firebase\emulators`) |

`npm audit` reports a "high" advisory in `@grpc/grpc-js` (pulled in by the Firebase JS SDK; `firebase-admin` added no new advisory, checked 2026-10-25). Both advisories concern gRPC *server* behaviour. Here the SDK is only a client talking to the localhost emulator during tests, and nothing here ships. npm's suggested "fix" is a downgrade to firebase 9, which is not applied.

The test runner finds Java in this order: `VOCABLY_JAVA_HOME`, then `JAVA_HOME`, then `%USERPROFILE%\.vocably-dev\jdk-2*`. It uses the first that is Java 21 or newer, and only for the processes it starts.

### PowerShell commands

One-time setup of the portable JDK. Skip it if you already have Java 21+ and set `VOCABLY_JAVA_HOME` to it:

```powershell
$dev = "$env:USERPROFILE\.vocably-dev"
New-Item -ItemType Directory -Force $dev | Out-Null
$zip = "$dev\OpenJDK21U-jdk_x64_windows_hotspot_21.0.12.1_1.zip"
Invoke-WebRequest "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_windows_hotspot_21.0.12.1_1.zip" -OutFile $zip
# Expected SHA-256 (published by Adoptium): f9d6e191ab098c0d416e7d588a24420a8621cd2f4720dab2459b8b7b2d2d8b4e
(Get-FileHash $zip -Algorithm SHA256).Hash
Expand-Archive $zip -DestinationPath $dev
Remove-Item $zip
```

Install the dev dependencies once:

```powershell
cd tools\research
npm install
```

Run the rules tests. This starts the emulator, runs the suite and stops the emulator again, even when tests fail:

```powershell
cd tools\research
npm run test:rules
```

You don't need a separate start/stop step: `emulators:exec` owns the emulator's lifetime, and every test starts from an empty database (`clearFirestore()` before each test). If a run is interrupted and port 8080 or 9099 stays busy, find and stop the leftover process:

```powershell
Get-NetTCPConnection -LocalPort 8080,9099 -State Listen | ForEach-Object { Stop-Process -Id $_.OwningProcess }
```

### Collections and what the rules enforce

The full schema is in `DATA_MODEL.md` §6b. In short:

- **`researchParticipants/{uid}`** (band — `null` while awaiting placement —, `status`, `reviewStatus`, `researchId`, `authorizedAttempts: {placement?, preTest, postTest}`, cohort):
  - the owner can `get` it;
  - clients can never create, delete or list it; their **only** update is the automatic placement band, recomputed by the rules (`validPlacementBandWrite`), so nobody can choose their band or authorize themselves;
  - pretest/posttest also need a band, `status` `enrolled` (or absent), no pending review and an open stage window in `researchStudy/current`;
  - `users.cefrLevel` / `users.resultLevel` are never consulted.
- **`researchInstrument/{version}_{band}`:** the **public** option IDs and texts per item, from the bank. No answer key. Only the rules read it, through `get()`. Embedding this data in the rules would exceed Firestore's 1000-expression per-request limit. Clients can't read or write it, and a missing document makes attempt creation and answer saving fail closed. **It must be seeded by trusted tooling before the rules are ever deployed.**
- **`researchAssessmentResults/{uid}_{stage}_{n}`:** one attempt.
  - **Read:** an existing attempt only by the UID stored in it (`studentId`). A not-yet-created attempt only when its ID is **exactly** one of the caller's currently authorized attempt IDs, so the app can check whether there is an attempt to resume. No UID is ever interpreted as a regex or prefix.
  - **Create:** only when `n == authorizedAttempts[stage]`, the participant is eligible and the stage window is open. Band and version must match the participant's. The question order must be exactly the band's 20 items, and each item's option order a permutation of its 4 bank option IDs. Responses start empty, status `in_progress`, server timestamps, an exact field list. A posttest also needs the authorized pretest `completed`.
  - **Answer:** exactly one new answer per write, to an item not yet answered (forward-only). The option must be one of that item's displayed options or `dont_know` (position 5, exact text "Saya tidak tahu kata ini"); the text and position must match; `answeredAt` must be server time. Only while `in_progress` and only on the currently authorized attempt.
  - **Complete:** only when all 20 answers exist, with a server `completedAt`. After that the attempt is frozen.
  - **Never allowed:** deletes, list queries, reading someone else's attempt, `voided` set by a client, or any key/score/correctness field.

**Enforcement levels** (security audit, 2026-10-24):

1. **Enforced by Firestore rules:**
   - ownership: reads, creates and updates are tied to `request.auth.uid` by exact equality only. No UID is ever used as a regex or prefix.
   - no listing;
   - band and authorization come only from the trusted participant record;
   - posttest gating;
   - exact field lists;
   - option IDs and texts must exist in the bank for that item;
   - forward-only answers (no edit or delete);
   - completion only with the attempt's 20 distinct items, each added through a validated write;
   - nothing changes after completion;
   - server timestamps;
   - no deletes.
2. **Structurally validated, but not provable as what the UI did:**
   - the stored question and option order is a valid permutation, but rules can't prove the screen displayed it, or that it was randomly generated;
   - `displayPosition` is consistent with the stored order, not with what the student actually saw;
   - an answer saved means a valid write was made, not that the student read the question.
3. **Needs trusted researcher tooling or human supervision:**
   - who actually answered, and whether they had outside help (dictionary, the in-app dictionary, other people);
   - the time between treatment session 4 and the posttest;
   - voiding attempts and authorizing retakes;
   - seeding `researchInstrument` and participant records;
   - data retention.

**Researcher-controlled operations** (participant records, opening the posttest, voiding an attempt and authorizing a retake, seeding `researchInstrument`) are performed only with the Admin SDK tooling below, on the researcher's machine. No privileged operation is exposed to students.

## Researcher administration (M2b-3)

`bin/research_admin.js` (`npm run admin -- <command> …`). Tested against the local emulators; whether it has been used against production is recorded in [`HANDOFF.md`](../../HANDOFF.md).

| Command | What it does |
|---|---|
| `seed-instrument` | Writes `researchInstrument/v1_{A2,B1,B2,C1}` from the committed bank (public data only, no key). Existing identical documents are left alone; a different existing document is refused, never overwritten. |
| `enrol --csv <file>` | Creates `researchParticipants/{uid}` for each row, with `authorizedAttempts {preTest: 0, postTest: 0}`. The CSV header must be exactly `uid,researchId,band,cohort` (bands A2/B1/B2/C1; cohorts study/pilot/test; research IDs 2–32 letters, digits, `_` or `-`, starting with a letter or digit). Refused if any row is malformed, a UID or research ID is duplicated or already used, a participant already exists, or the account has no `users/{uid}` profile with role `siswa`. All rows are written atomically, or none. |
| `authorize --stage preTest\|postTest (--uid <uid>… \| --cohort <c>)` | First authorization of a stage (0 → 1). Refused if the bank isn't seeded. With `--uid`, any ineligible UID refuses the whole request; with `--cohort`, ineligible participants are listed as `skipped`. **The posttest also needs `--confirm-session4-completed`**: the tooling checks that the pretest is completed, but it **cannot verify treatment session 4** (there is no session tracking), so the researcher attests it and the attestation is logged. |
| `void --uid <uid> --stage <s> --reason "<text>" [--allow-completed]` (exactly one `--uid`) | Marks the currently authorized attempt `voided` with `voidReason`/`voidedAt`. **All answers are kept.** A completed attempt needs `--allow-completed`. Voiding the pretest is refused once the posttest is authorized. |
| `retake --uid <uid> --stage <s> --reason "<text>"` (exactly one `--uid`) | Only after the current attempt is voided: authorizes attempt n+1 (the student then starts a new attempt with a new order). A pretest retake is refused once the posttest is authorized. |
| `status [--uid <uid>]` | Read-only: research ID, UID, participant band, status, cohort, and every attempt's status and answer count. For the research placement attempt it also prints the stored result: see "Reading `status`" under Placement Test. |

Safety:
- **Target:** exactly one of `--emulator` (needs `FIRESTORE_EMULATOR_HOST` on localhost and a `demo-*` project) or `--production --project <id> --confirm-project <same id>` (needs `GOOGLE_APPLICATION_CREDENTIALS` pointing at a service-account file **outside** the repository, any Git working tree and OneDrive, and refuses while emulator variables are set). Anything else is refused.
- **Dry run by default:** nothing is written without `--apply`. With `--production --apply`, `--log <file.private.jsonl>` is required.
- **Audit log** (`--log`): one JSON line per command (time, target, command, apply, outcome, planned actions or refusal reasons). It must be outside the repository/Git/OneDrive. It holds UIDs, research IDs and reasons; never passwords, tokens or keys.
- **Never deletes or overwrites:** writes are creates or transactions that re-check the record first; voiding keeps answers; a retake is a new attempt number.
- Problems name CSV line numbers or UIDs, never echo CSV field values.

Example (emulator):

```powershell
cd tools\research
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"
npm run admin -- seed-instrument --emulator --apply
npm run admin -- enrol --emulator --csv C:\path\outside\repo\participants.csv          # dry run
npm run admin -- enrol --emulator --csv C:\path\outside\repo\participants.csv --apply
npm run admin -- authorize --emulator --stage preTest --cohort study --apply
npm run admin -- authorize --emulator --stage postTest --uid <uid> --confirm-session4-completed --apply
npm run admin -- status --emulator
```

Production use is a separate, explicit decision by the researcher (service-account key, rules deployment, retention policy); the prerequisites are listed as blockers in [`HANDOFF.md`](../../HANDOFF.md).

## Placement Test PT-V1.1

Source documents (researcher's, **outside the repository**; the item file contains the key): `Vocably_Spesifikasi_Placement_Test_v1.0.pdf` and `placement_items_v1.0.json` (PT-V1.0). PT-V1.1 = the same 50 items, options and keys, plus the researcher's decisions: **K2 scoring** (researcher-selected, **not expert/supervisor-validated**), **no key in the client**, separate stage controls. Schema and rules: `DATA_MODEL.md` §6/§6b; app behaviour: `SPEC.md` §3.1.

### Build the bank (and optionally the private key)

```powershell
cd tools\research
# Validate + (re)write assets/placement/placement_bank_pt_v1_1.json (no key):
npm run build:placement -- --source C:\path\to\placement_items_v1.0.json
# Only compare with the committed bank:
npm run build:placement -- --source C:\path\to\placement_items_v1.0.json --check
# Also write the private key (outside the repo, any Git tree and OneDrive; never overwritten; contents never printed):
npm run build:placement -- --source C:\path\to\placement_items_v1.0.json --key-out C:\vocably-private\placement\placement_key_pt_v1_1.private.json
```

The build refuses anything unexpected: 50 items (10 per band), ids `pt-<band>-NN`, options exactly A–D (non-empty, distinct), key A–D, exactly one `[[word|form]]` marker matching `sentence`, unique words across items and the 12 reserves, **no word shared with the pretest/posttest bank** (checked against `assets/research/instrument_v1.json`), and the 16 source test vectors must still match the PT-V1.0 rule with **K2 changing only `[7,6,6,6,7]`** (C1 → A1). Set `VOCABLY_PLACEMENT_SOURCE` to the item file to make `npm test` also check that a rebuild reproduces the committed bank.

### Scoring and security model

- K2 lives in `lib/placement/scoring.js` (tooling, export) **and** in `firestore.rules` (`placementK2`); the emulator tests check that the rules accept exactly the tooling's result on boundary and random profiles. Exhaustive check (161,051 profiles): deterministic, monotone, never above PT-V1.0, 1,108 profiles placed lower than PT-V1.0.
- The key exists only in the private file and in `placementKey/{version}`, which clients cannot read. After submission the app proposes each of the six possible results; the rules recompute K2 from the frozen answers (`answers.diff(bandKey).unchangedKeys().size()` per band) and accept only the exact one, once, in a batch with `users.resultLevel` and the participant band. No Worker, MAC or service account is involved.
- Band scores, total and quality flags (`near_threshold`, `inconsistent_profile`, `below_a1_threshold`, `suspicious_pattern` — 6+ identical non-E letters in display order, **E interrupts a run**) are never stored; `bin/export_placement.js` derives them offline.
- Residual risks: anyone who can take learning attempts can use the returned level as a slow oracle for the key (limited to one learning attempt per day per account; keep `learning-placement` closed while official placement sessions run). Rules cannot prove who answered.

### Researcher commands (all dry-run without `--apply`; production also needs `--log`)

| Command | What it does |
|---|---|
| `seed-placement --key <file.private.json>` | Creates `placementInstrument/PT-V1.1` (public band item lists), `placementKey/PT-V1.1` (the key, unreadable by clients) and, if missing, `placementConfig/current` with learning placement **closed**. Refuses a key for another bank; never overwrites. |
| `learning-placement --open` / `--close` | Ordinary (learning-only) placement for every account. |
| `study --status setup\|active\|closed` | Study lifecycle; `closed` is final and freezes every unfinished research attempt. |
| `stage --stage placement\|preTest\|postTest --open [--close-at <iso>]` / `--close` | Separate windows per stage, server timestamps (`openAt`/`closeAt`). Closing never discards answers; a submission accepted before closure is still scored. |
| `review --uid <uid> --open --reason "…"` / `--close --outcome confirmed\|not_confirmed --reason "…"` | Human review case. `pending` blocks the participant's research actions (the student sees only a neutral message). Signals never open a review automatically. |
| `placement-void --uid <uid> --category technical\|integrity --reason "…"` | Voids the current research placement attempt (answers kept). `integrity` needs a **confirmed** review. A band that came from the attempt is revoked (`bandHistory`). Refused once the pretest is authorized. |
| `placement-retake --uid <uid> --reason "…"` | Attempt n+1 — **only after a technical void**. Never after an integrity void. |
| `placement-restore --uid <uid> --reason "…"` | Administrative correction of an **erroneous** void: the same attempt returns to its previous status (and its band). No attempt is created. |
| `assign-band --uid <uid> --band A2\|B1\|B2\|C1 --basis "…" --reason "…"` | Manual band after an integrity void; participant becomes `conditional`. `authorize` and the rules **refuse** pretest/posttest for `conditional` until the conditional-inclusion criteria are decided. |

Reasons are stored only in `researchReviews` (no client access) and the local audit log — never on documents the student can read. `authorize` now refuses participants without a usable band (`awaiting_placement`, `excluded`, `awaiting_manual_band`, `conditional`) or with a pending review, and requires `--acknowledge-placement-policy` for bands that came from the Placement Test (K2 not expert-validated).

**Not implemented (deferred milestone):** enrolling participants **without** a band. `enrol` still requires the `band` column; pending-band participants are currently created only by the emulator seed and the tests.

### Reading `status`

```text
EMU-PT  emuStudentPlacement  A2  enrolled  test placement=#1 scored answered=50/50 level=A1* targetBand=A2  pre=0  post=0
```

| Field | Meaning |
|---|---|
| Third column (`A2`) | `researchParticipants.band`, the **pretest target band**. It is not the placement level. |
| `scored` | The attempt status (`not_started`, `in_progress`, `submitted`, `scored`, `voided`). |
| `answered=50/50` | Saved answers, **E included**. It is never a score: band scores and totals are not stored, and only `export:placement` derives them. |
| `level=` | `resultLevel` stored on the attempt; `*` = stored `belowA1Threshold` is true (A1*). The student sees A1* as A1. |
| `targetBand=` | `pretestTargetBand` stored on the attempt; `none` = stored null (result C1, no research band). |
| `-` | Nothing stored yet. `level` and `targetBand` are never derived from each other or from the participant band. |

A level of A1 and A1* both give target band A2, so `A2` alone says nothing about which one it was. The command prints no answers, per-item data or key data.

### Export

```powershell
npm run export:placement -- --emulator --key C:\vocably-private\placement\placement_key_pt_v1_1.private.json --out-dir C:\vocably-private\exports\pt-01
#   …or --production --project <id> --confirm-project <id> (read-only)
```

Research attempts only (learning attempts are not research data). Files: `placement_attempts.csv` (research_id, cohort, participant status/band/source, attempt status incl. `in_progress (incomplete)`, void category, stored result, `offline_check` = match/MISMATCH against an offline K2 recomputation, band scores, total, flags, suspicious_pattern, answered, tab_switch_count, timestamps, duration), `placement_items.csv` (per-item answer and correctness), `placement_operational_problems.csv`, `placement_manifest.json`. Never overwrites.

### PT-V1.1 corrections still to apply to the researcher's PDF/JSON

The PDF and the item JSON are the researcher's source documents and were **not** modified (no reliable way to regenerate the PDF here). The accepted correction list (decision dossier, D10) still has to be applied to the source `.docx`/PDF/JSON: version PT-V1.1 and date; §10.2 pool check B1/B2/C1 → "sudah dicek: tidak ada irisan" (confirmed by the build above: 62 words, 0 overlap with 80 pretest/posttest words); §10.3 pool source = `assets/research/instrument_v1.json`; K6 final; §8.1 access = separate per-stage open/close; §8.3 scoring by the security rules, key **not** bundled; §3.4 result text (level shown, no scores); §6.4 E interrupts `suspicious_pattern`; §6.2/§6.3/§6.7/§7.2/§9 and JSON `thresholds`/`testVectors` → K2 (only `[7,6,6,6,7]` changes). Noticed but not yet approved: §9.4/§11 statements about a bundled key, the page header, §4.1 step 3, JSON `poolCheckStatus`/`generatedAt`, and §8.1 "band ditentukan di luar sistem" vs. the recorded manual band.

## Running the app against the emulators (M2b-5)

For manual end-to-end checks with dummy accounts. Emulator data lives in memory only: stopping the emulators is the teardown, and the next start is empty.

```powershell
# Terminal 1 — Firestore 127.0.0.1:8080 + Auth 127.0.0.1:9099, demo project, real firestore.rules
cd tools\research
npm run emulators

# Terminal 2 — dummy accounts + bank + enrolment + pretest authorized (safe to re-run)
cd tools\research
npm run seed:emulator -- --password <a dummy password of your choice>
# Needed by every `npm run admin -- … --emulator` command below:
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"

# Terminal 3 — the app, pointed at the emulators (debug only)
flutter run -d chrome --web-port=5555 --dart-define=USE_FIREBASE_EMULATORS=true
```

- Dummy accounts: `siswa.a2@example.test`, `siswa.b1@…`, `siswa.b2@…`, `siswa.c1@…` (enrolled, pretest authorized), `siswa.umum@example.test` (not a participant; learning placement) and `siswa.placement@example.test` (participant **without a band**, awaiting the research Placement Test). The seed also creates an active study with the placement/pretest/posttest windows open, the Placement Test bank with a **synthetic** key (letter by item number — never the real key) and learning placement open. The password is the one you passed; it is never printed.
- **The emulator grades with the synthetic key, not the real one.** For item numbers 1–10 of each band it is `B C D A B C D A B C`. Choosing the genuinely correct meanings therefore scores far too low (11/50, best band 4/10, on the current bank) and gives A1*, target band A2, exactly like answering E. To reach a higher level, look up each word's `number` in `assets/placement/placement_bank_pt_v1_1.json` and answer with that pattern (7 correct per band passes it). A scored research attempt cannot be retaken in the same emulator session; restart the emulators to try another result.
- `USE_FIREBASE_EMULATORS=true` re-points the app at the demo project and connects Firestore/Auth to `127.0.0.1` (`lib/services/firebase_emulator_config.dart`). A **release** build with that define refuses to start, and without it the emulator code is compiled out (checked: the release `main.dart.js` contains no emulator host or demo project).
- The AI features still call the Worker as usual; only the research assessment is the point of this mode.

**Manual end-to-end checklist** (latest result: [`HANDOFF.md`](../../HANDOFF.md) §3):

1. Log in as `siswa.umum@example.test` → dashboard shows "Belum tersedia" on both banners; tapping shows "Belum terdaftar".
2. Log in as `siswa.b1@example.test` → Pre-Test "Siap dikerjakan", Post-Test "Belum dibuka".
3. Open Pre-Test → instructions and the "book" example match PDF §5 exactly → "Mulai".
4. Each item: word in bold with "(kata …)", four options a)–d), "e) Saya tidak tahu kata ini" last; "Lanjut" disabled until a choice; no score or right/wrong anywhere.
5. Answer 5 items, then reload the browser tab → dashboard shows "Lanjutkan"; reopening shows the instructions with "Lanjutkan" and then the 6th item, with the same order as before.
6. Stop the network (DevTools → Offline), choose an option, press "Lanjut" → "Jawaban belum tersimpan…", same item, choice kept; back online → "Lanjut" saves once and moves on (`npm run admin -- status --emulator` shows the count).
7. Finish all 20 ("Kirim" on the last) → "Pre-Test selesai", no score; dashboard "Selesai".
8. Post-Test still "Belum dibuka" → `npm run admin -- authorize --emulator --stage postTest --uid emuStudentB1 --confirm-session4-completed --apply` → "Siap dikerjakan"; the posttest order differs from the pretest's.
9. Start the posttest, answer 3, then `npm run admin -- void --emulator --uid emuStudentB1 --stage postTest --reason "uji" --apply` → the next "Lanjut" leads to "Tes dibatalkan"; `retake … --apply` → reopening starts attempt 2 with a new order.
10. Phone width (390 px, DevTools device toolbar): no horizontal scrolling; options are full-width tap targets.
11. Optional — voiding a **completed** attempt: `npm run admin -- void --emulator --uid <uid> --stage <stage> --reason "uji" --allow-completed --apply` → `retake … --apply` → the student starts attempt 2 with a newly generated item/option order, while `npm run admin -- status --emulator` still shows attempt 1 as `voided` with its answers kept.

**Placement Test checklist** (`siswa.placement@example.test`, before answering anything: this account has a single research attempt):

1. Dashboard → card **Level** → "Ambil Tes Penempatan" → stop at the instructions, do not press "Mulai".
2. `npm run admin -- stage --emulator --stage placement --close --apply`, then press "Mulai" → "Tes belum dibuka. Tunggu arahan pengawas.", with no connection message.
3. `npm run admin -- stage --emulator --stage placement --open --apply` → "Muat ulang" → "Mulai".
4. Each item: the sentence is regular and only the target word is bold and underlined.
5. Answer all 50, "Ringkasan" → "Kirim jawaban" → "Kirim" → "Level kamu: …", no score.
6. `npm run admin -- status --emulator --uid emuStudentPlacement` → compare with "Reading `status`" above.

## Export and scoring (M2b-6)

`bin/export_results.js` (`npm run export -- …`): trusted, offline tooling. The app never scores.

```powershell
cd tools\research
# Check the private key against the committed bank (prints only OK / item IDs):
npm run export -- validate-key --key C:\Users\<you>\vocably-private\instrument_v1_key.private.json
# Score and export (folder must exist, outside the repo, Git and OneDrive):
npm run export -- export --key <key.private.json> --out-dir C:\path\outside\repo\export-2026-xx-xx --emulator
#   …or --production --project <id> --confirm-project <id> (read-only)
#   optional: --cohort study|pilot|test
```

- **Key validation** (refuses to score otherwise): same `instrumentId` and version as the bank, `bankSha256` equal to the committed bank's (LF-normalized), exactly one entry per bank item, band, `correctOptionId` one of that item's four options (never "tidak tahu"), and `correctOptionText` equal to the bank text. Messages name item IDs only, and the key contents are never printed.
- **Scoring:** B (key option) = 1; S (other option) = 0; T ("tidak tahu") = 0; K (missing) = 0. Score = number of B (0–20); percent = score ÷ 20 × 100. Gain = post − pre. N-gain = (post − pre) ÷ (20 − pre), 4 decimals, **blank with the note "not computed: pre = 20"** when pre = 20.
- **Attempt selection, never guessed:** per participant and stage there must be exactly one non-voided attempt, it must be the currently authorized number, it must be valid against the bank (band, version, item order, option orders, every answer's option ID, text and display position), and it must be `completed` with all 20 answers. Otherwise the stage is excluded with a reason: `no_attempt`, `only_voided_attempts`, `conflicting_attempts`, `attempt_not_currently_authorized`, `invalid_authorization_state`, `invalid_record`, `incomplete`. A pair is also excluded if the posttest started before the pretest was completed. Voided attempts are listed but never scored. Excluded attempts get B/S/T/K counts but no score.
- Participants whose `instrumentVersion` differs from the committed bank are left out with an `instrument_version_mismatch` problem (a different version needs its own bank and key).
- **Paired analysis:** only participants with a valid pretest **and** posttest; everyone else gets an `excluded_from_paired_analysis` row with the reason. No other statistics are computed.

Files (UTF-8, RFC 4180 CSV with CRLF; written new, never overwritten):

| File | Contents | Identifiers |
|---|---|---|
| `analysis_paired.csv` | `research_id, band, cohort, pre_score, post_score, gain, pre_percent, post_percent, n_gain, n_gain_note, pre_dont_know, post_dont_know` | research ID only |
| `analysis_attempts.csv` | every attempt: `research_id, band, cohort, instrument_version, stage, attempt_number, status, included_in_scoring, exclusion_reason, score, percent, count_B, count_S, count_T, count_K, started_at, completed_at` | research ID only |
| `analysis_items.csv` | per item of scored attempts: `research_id, band, stage, attempt_number, display_order, item_id, item_number, word, selected_option_id, selected_option_text, display_position, code, score, answered_at` | research ID only |
| `analysis_exclusions.csv` | `research_id, band, cohort, stage, reason, detail` (stage `pair` = paired-analysis exclusion) | research ID only |
| `operational_identifiers.csv` | `research_id, uid` | **UIDs** — keep separate |
| `operational_problems.csv` | `category, reference, detail` (duplicate research IDs, orphan or mismatched attempts) | **UIDs / attempt IDs** |
| `operational_voided_attempts.csv` | `research_id, uid, stage, attempt_number, void_reason, voided_at` | **UIDs** |
| `export_manifest.json` | time, source, instrument, bank SHA-256, scoring rules, instrument status, counts, column lists | none |

No names, e-mails or credentials are read. Nothing is uploaded. **Where exports are stored, who may access them, and how long Firestore research data is kept are researcher decisions that are still pending** (no deletion or retention job exists).
