# tools/research — research instrument tooling

Developer-side tooling for Vocably's **pretest/posttest research instrument**.
It is not part of the Flutter app: nothing here ships, and nothing here runs
at app runtime. The instrument build has no npm dependencies. The emulator
tests and the researcher tools use three pinned dev-only dependencies (see
[Security-rules tests](#security-rules-tests-local-firestore-emulator)).

**Status:**
- **Research Milestone 1 (done, committed):** the instrument *data* is
  prepared. The bank of items and options ships with the app, and the
  private answer key has been generated outside the repository.
- **Research Milestone 2a (done, committed):** Firestore security rules for
  the research collections, tested against a **local Firestore Emulator**
  only. **They are not deployed.**
- **M2b-1 (committed locally, `97c1469`):** pure Dart models, a strict
  loader for this bank, and the runtime shuffling/resume planner.
- **M2b-2 – M2b-6 (working tree, NOT committed, nothing deployed):**
  - M2b-2: the app saves answers (`lib/services/research_assessment_service.dart`,
    `lib/providers/research_assessment_providers.dart`);
  - M2b-3: [researcher administration](#researcher-administration-m2b-3)
    (`bin/research_admin.js`);
  - M2b-4: the student test screens (`lib/screens/student/research_assessment/`);
  - M2b-5: [emulator workflow](#running-the-app-against-the-emulators-m2b-5)
    and end-to-end emulator tests;
  - M2b-6: [offline export and scoring](#export-and-scoring-m2b-6)
    (`bin/export_results.js`).
- **Not done / not decided:** nothing has been run against production; the
  rules are not deployed; treatment-session delivery and tracking don't
  exist (opening the posttest is a researcher attestation); expert
  validation, the pilot, B2-06 and the retention policy are pending. The
  placement test is deferred.

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

- **Placement → band** (§2) — **PDF design only; not approved for
  implementation.** While placement is deferred, the researcher assigns each
  participant's band directly (`researchParticipants.band`), and nothing in
  Vocably implements this mapping:

  | Placement level | Band |
  |---|---|
  | A1 | A2 |
  | A2 | B1 |
  | B1 | B2 |
  | B2 | C1 |

  The placement test itself is **deferred** in Vocably and isn't needed for this tooling.
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

### Behaviour required of the app (implemented in M2b-1 – M2b-4, not yet committed)

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
| `lib/` | parser, validation/build, output-path guard, vocab lookup, report, `researchInstrument` document builder, `emulatorEnv.js` | yes |
| `lib/admin/` | target safety (`target.js`), CSV parser, operations, emulator seed, CLI helpers | yes |
| `lib/export/` | scoring (`scoring.js`), CSV layout and Firestore read (`files.js`) | yes |
| `test/` | `node --test` suite (synthetic fixtures only); `test/rules/` = emulator-only suites; `test/fixtures/client_payloads.json` = the app's payloads, generated by the Flutter test `test/research_client_payloads_test.dart` | yes |
| `package.json`, `package-lock.json` | pinned dev dependencies | yes |
| `node_modules/`, `firestore-debug.log` | local install / emulator log | no (ignored) |
| `../../assets/research/instrument_v1.json` | **App-safe bank** (no answer key), bundled by the Flutter app | yes |
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

Current result of a plain `npm test`: **71 passing, 2 skipped** (the PDF/key checks), plus the skipped emulator suites.

The Flutter suite also has `test/research_instrument_asset_test.dart`, which checks that the asset is bundled and carries no key fields.

## Security-rules tests (local Firestore Emulator)

Research Milestone 2a. These tests exercise the real `firestore.rules` from the repository root against a **local** Firestore Emulator. **Nothing is deployed, and production is never contacted.**

### Safety

- The emulator runs under the demo project **`demo-vocably-test`**. Firebase treats `demo-*` projects as offline-only, so no production resource can be reached and no login or credentials are used. The real project `vocably-idn-en` is never passed to any command.
- `bin/run_rules_tests.js` runs only `firebase emulators:exec --only firestore,auth …` (one test file at a time, since they share the emulators), never `deploy`, and removes `GOOGLE_APPLICATION_CREDENTIALS` from the child environment.
- Each test file skips itself unless `FIRESTORE_EMULATOR_HOST` (and, for the end-to-end file, `FIREBASE_AUTH_EMULATOR_HOST`) points at `127.0.0.1`/`localhost` and the project ID starts with `demo-`.
- Every participant is synthetic (`stu-a2`, …) and every answer is fabricated (a fixed display position). The tests never read the answer key; the export test uses a synthetic key.
- Suites:
  - `researchRules.test.js` (70): the rules, with trusted records written through the testing library's rules-disabled context.
  - `adminTooling.test.js` (15): the researcher tooling through the Admin SDK, then the real rules checking what students can do afterwards.
  - `clientFlow.test.js` (1 end-to-end test): a dummy student signs in through the **Auth emulator** (a real ID token) and replays the app's exact payloads (`test/fixtures/client_payloads.json`) through create, interruption and resume, duplicate/changed answers, early and final completion, posttest gating, void and retake. Then the offline export scores the result.

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

- **`researchParticipants/{uid}`** (band, `researchId`, `authorizedAttempts: {preTest, postTest}`, cohort):
  - the owner can `get` it;
  - clients can never create, update, delete or list it, so nobody can choose their band or authorize themselves;
  - `users.cefrLevel` is never consulted.
- **`researchInstrument/{version}_{band}`:** the **public** option IDs and texts per item, from the bank. No answer key. Only the rules read it, through `get()`. Embedding this data in the rules would exceed Firestore's 1000-expression per-request limit. Clients can't read or write it, and a missing document makes attempt creation and answer saving fail closed. **It must be seeded by trusted tooling before the rules are ever deployed.**
- **`researchAssessmentResults/{uid}_{stage}_{n}`:** one attempt.
  - **Read:** an existing attempt only by the UID stored in it (`studentId`). A not-yet-created attempt only when its ID is **exactly** one of the caller's currently authorized attempt IDs, so the app can check whether there is an attempt to resume. No UID is ever interpreted as a regex or prefix.
  - **Create:** only when `n == authorizedAttempts[stage]`. Band and version must match the participant's. The question order must be exactly the band's 20 items, and each item's option order a permutation of its 4 bank option IDs. Responses start empty, status `in_progress`, server timestamps, an exact field list. A posttest also needs the authorized pretest `completed`.
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

`bin/research_admin.js` (`npm run admin -- <command> …`). Implemented and tested **against the emulators only**; it has **never been run against production**.

| Command | What it does |
|---|---|
| `seed-instrument` | Writes `researchInstrument/v1_{A2,B1,B2,C1}` from the committed bank (public data only, no key). Existing identical documents are left alone; a different existing document is refused, never overwritten. |
| `enrol --csv <file>` | Creates `researchParticipants/{uid}` for each row, with `authorizedAttempts {preTest: 0, postTest: 0}`. The CSV header must be exactly `uid,researchId,band,cohort` (bands A2/B1/B2/C1; cohorts study/pilot/test; research IDs 2–32 letters, digits, `_` or `-`, starting with a letter or digit). Refused if any row is malformed, a UID or research ID is duplicated or already used, a participant already exists, or the account has no `users/{uid}` profile with role `siswa`. All rows are written atomically, or none. |
| `authorize --stage preTest\|postTest (--uid <uid>… \| --cohort <c>)` | First authorization of a stage (0 → 1). Refused if the bank isn't seeded. With `--uid`, any ineligible UID refuses the whole request; with `--cohort`, ineligible participants are listed as `skipped`. **The posttest also needs `--confirm-session4-completed`**: the tooling checks that the pretest is completed, but it **cannot verify treatment session 4** (there is no session tracking), so the researcher attests it and the attestation is logged. |
| `void --uid <uid> --stage <s> --reason "<text>" [--allow-completed]` (exactly one `--uid`) | Marks the currently authorized attempt `voided` with `voidReason`/`voidedAt`. **All answers are kept.** A completed attempt needs `--allow-completed`. Voiding the pretest is refused once the posttest is authorized. |
| `retake --uid <uid> --stage <s> --reason "<text>"` (exactly one `--uid`) | Only after the current attempt is voided: authorizes attempt n+1 (the student then starts a new attempt with a new order). A pretest retake is refused once the posttest is authorized. |
| `status [--uid <uid>]` | Read-only: research ID, UID, band, cohort, and every attempt's status and answer count. |

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

Production use is a separate, explicit decision by the researcher (service-account key, rules deployment, retention policy). It has not been done.

## Running the app against the emulators (M2b-5)

For manual end-to-end checks with dummy accounts. Emulator data lives in memory only: stopping the emulators is the teardown, and the next start is empty.

```powershell
# Terminal 1 — Firestore 127.0.0.1:8080 + Auth 127.0.0.1:9099, demo project, real firestore.rules
cd tools\research
npm run emulators

# Terminal 2 — dummy accounts + bank + enrolment + pretest authorized (safe to re-run)
cd tools\research
npm run seed:emulator -- --password <a dummy password of your choice>

# Terminal 3 — the app, pointed at the emulators (debug only)
flutter run -d chrome --web-port=5555 --dart-define=USE_FIREBASE_EMULATORS=true
```

- Dummy accounts: `siswa.a2@example.test`, `siswa.b1@…`, `siswa.b2@…`, `siswa.c1@…` (enrolled, pretest authorized) and `siswa.umum@example.test` (not a participant). The password is the one you passed; it is never printed.
- `USE_FIREBASE_EMULATORS=true` re-points the app at the demo project and connects Firestore/Auth to `127.0.0.1` (`lib/services/firebase_emulator_config.dart`). A **release** build with that define refuses to start, and without it the emulator code is compiled out (checked: the release `main.dart.js` contains no emulator host or demo project).
- The AI features still call the Worker as usual; only the research assessment is the point of this mode.

**Manual end-to-end checklist** (not yet performed in a browser; see `PROJECT_STATE.md` §5y):

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

## Export and scoring (M2b-6)

`bin/export_results.js` (`npm run export -- …`): trusted, offline tooling. The app never scores.

```powershell
cd tools\research
# Check the private key against the committed bank (prints only OK / item IDs):
npm run export -- validate-key --key C:\Users\<you>\vocably-private\instrument_v1_key.private.json
# Score and export (folder must exist, outside the repo, Git and OneDrive):
npm run export -- export --key <key.private.json> --out-dir C:\path\outside\repo\export-2026-xx-xx --emulator
#   …or --production --project <id> --confirm-project <id> (read-only; not done yet)
#   optional: --cohort study|pilot|test
```

- **Key validation** (refuses to score otherwise): same `instrumentId` and version as the bank, `bankSha256` equal to the committed bank's (LF-normalized), exactly one entry per bank item, band, `correctOptionId` one of that item's four options (never "tidak tahu"), and `correctOptionText` equal to the bank text. Messages name item IDs only. Verified against the real key on 2026-10-25: **OK, 80 entries, bank SHA-256 matches** (contents never printed).
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
