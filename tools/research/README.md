# tools/research — research instrument tooling

Developer-side tooling for Vocably's **pretest/posttest research instrument**.
It is not part of the Flutter app: nothing here ships, and nothing here runs
at app runtime. The instrument build has no npm dependencies. The
security-rules tests use two pinned dev-only dependencies (see
[Security-rules tests](#security-rules-tests-local-firestore-emulator)).

**Status:**
- **Research Milestone 1 (done):** the instrument *data* is prepared. The
  bank of items and options ships with the app, and the private answer key
  has been generated outside the repository.
- **Research Milestone 2a (done):** Firestore security rules for the
  research collections are written and tested against a **local Firestore
  Emulator** only. **They are not deployed.**
- **M2b-1 (working tree, not committed):** the app has pure Dart models,
  a strict loader for this bank (`lib/services/research_instrument_service.dart`)
  and the runtime shuffling/resume planner
  (`lib/utils/research_attempt_planner.dart`). Nothing calls them yet.
- **Still not implemented:** the pretest/posttest **feature** in the app
  (screens, saving answers from Flutter), the researcher
  tooling that writes participant/eligibility and bank documents in
  production, and the offline export and scoring. The app still shows the
  placeholder screen. The placement test is deferred.

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

### Behaviour required of the app (for later milestones, not implemented)

- Item order and the order of options a–d are shuffled per student and per stage, with pretest and posttest shuffled independently. "Saya tidak tahu kata ini" always comes last.
- The selected option is stored by its **opaque option ID and its text**, never by a displayed letter.
- Students see no correctness feedback, scores or answers.

## Files

| Path | What it is | In Git? |
|---|---|---|
| `bin/build_instrument.js` | CLI: PDF → validated bank (+ optional private key and report) | yes |
| `bin/run_rules_tests.js` | Starts the local Firestore Emulator (demo project) and runs the rules tests | yes |
| `lib/` | parser, validation/build, output-path guard, vocab lookup, report, `researchInstrument` document builder | yes |
| `test/` | `node --test` suite (synthetic fixtures only); `test/rules/` = emulator-only rules tests | yes |
| `package.json`, `package-lock.json` | pinned dev dependencies for the rules tests | yes |
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
- **`test/rules/researchRules.test.js`:** the security-rules suite. **Skipped** in a plain `npm test`; it runs only inside the emulator (below).

Current result of a plain `npm test`: **46 passing, 2 skipped** (the PDF/key checks), plus the skipped emulator suite.

The Flutter suite also has `test/research_instrument_asset_test.dart`, which checks that the asset is bundled and carries no key fields.

## Security-rules tests (local Firestore Emulator)

Research Milestone 2a. These tests exercise the real `firestore.rules` from the repository root against a **local** Firestore Emulator. **Nothing is deployed, and production is never contacted.**

### Safety

- The emulator runs under the demo project **`demo-vocably-test`**. Firebase treats `demo-*` projects as offline-only, so no production resource can be reached and no login or credentials are used. The real project `vocably-idn-en` is never passed to any command.
- `bin/run_rules_tests.js` runs only `firebase emulators:exec --only firestore …`, never `deploy`, and removes `GOOGLE_APPLICATION_CREDENTIALS` from the child environment.
- The test file skips itself unless `FIRESTORE_EMULATOR_HOST` points at `127.0.0.1`/`localhost` and the project ID starts with `demo-`.
- Every participant is synthetic (`stu-a2`, …) and every answer is fabricated (a fixed display position). The tests never read the answer key.
- Trusted records (participants, bank documents, voiding an attempt) are written with the testing library's rules-disabled context, which stands in for the future researcher Admin tooling. Student actions use authenticated test contexts and go through the rules.

### Prerequisites

| Tool | Requirement | On this machine (2026-10-24) |
|---|---|---|
| Firebase CLI | `firebase` on `PATH` (or set `FIREBASE_CLI`) | firebase-tools **15.32.0** (global npm install) |
| Java | **21 or newer.** firebase-tools 15 refuses older Java for emulators (`MIN_SUPPORTED_JAVA_MAJOR_VERSION = 21`) | System JDKs are 1.8, 17 and 19, all too old. A **portable** Eclipse Temurin **21.0.12.1** is unpacked at `%USERPROFILE%\.vocably-dev\jdk-21.0.12.1+1` (outside the repo and OneDrive; no system setting changed) |
| Node | `>= 20` | 25.2.1 |
| npm dev dependencies | `@firebase/rules-unit-testing` **5.0.2** and its required peer `firebase` **12.19.0** (pinned exactly) | installed with `npm install` |
| Firestore emulator JAR | downloaded automatically on first run | `cloud-firestore-emulator-v1.22.0.jar` in Firebase's user cache (`%USERPROFILE%\.cache\firebase\emulators`) |

`npm audit` reports a "high" advisory in `@grpc/grpc-js` (pulled in by the Firebase JS SDK). Both advisories concern gRPC *server* behaviour. Here the SDK is only a client talking to the localhost emulator during tests, and nothing here ships. npm's suggested "fix" is a downgrade to firebase 9, which is not applied.

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

You don't need a separate start/stop step: `emulators:exec` owns the emulator's lifetime, and every test starts from an empty database (`clearFirestore()` before each test). If a run is interrupted and port 8080 stays busy, find and stop the leftover Java process:

```powershell
Get-NetTCPConnection -LocalPort 8080 -State Listen | ForEach-Object { Stop-Process -Id $_.OwningProcess }
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

**Researcher-controlled operations** (participant records, opening the posttest, voiding an attempt and authorizing a retake, seeding `researchInstrument`) are performed only with Admin SDK tooling on the researcher's machine. That tooling is a later milestone and is **not implemented yet**. No privileged operation is exposed to students.
