# Vocab Import Pipeline

Developer-side tool that turns the two Oxford CSVs into Vocably's
`vocabWords` Firestore data and the `assets/vocab/vocab_*.json` runtime
bundles. **Not part of the Flutter app** — never shipped, never imported
by anything under `lib/`, never run at app runtime.

Node.js (>= 18, this repo was built/tested on v24) is the only runtime
this tool needs — separate from the Flutter/Dart toolchain.

## Who does what (`CLAUDE.md` §7 Milestone 4)

Claude may write and maintain every script in here (parsing, merging,
the translation client, the Firestore writer, bundle generation) and run
the fully local/free stages itself. Three things stay **developer-owned,
always**, regardless of who wrote the code that uses them:

1. **Secrets never get hardcoded or committed.** The translation stage
   reads `OPENAI_API_KEY` (+ `OPENAI_BASE_URL`/`OPENAI_API_PATH`/
   `OPENAI_MODEL`) from the repo root's `.env` (already git-ignored). The
   Firestore stage reads `GOOGLE_APPLICATION_CREDENTIALS` from the
   environment. Neither is ever printed, logged, or written into any
   output file this tool produces.
2. **The first real run of a large/costly/production-writing stage gets
   a human check before it runs at full scale** — a tiny `--limit`
   smoke-test for translation, a mandatory `--dry-run` before
   `--yes` for Firestore. This isn't a permissions restriction on Claude
   specifically; it's the same caution any first run of new automation
   against a live paid API / production database deserves.
3. **Whoever runs `bin/seed_firestore.js --yes` against the real
   `vocably-idn-en` project needs their own Admin SDK credential** — this
   tool does not (and should not) embed or share one.

## Pipeline stages

Run in order from this directory (`tools/vocab_import/`):

```bash
npm install                      # once, installs firebase-admin

node bin/merge.js                # Stage 1 — CSV -> canonical_vocab.json
                                  # Pure, local, free. Safe to rerun anytime.

node bin/translate.js --limit 5  # Stage 2, smoke-test first (negligible cost)
node bin/translate.js            # Stage 2, full run — resumable, only
                                  # generates what's missing from
                                  # output/translations_cache.json

node bin/seed_firestore.js --dry-run   # Stage 3 — preview only, no writes
node bin/seed_firestore.js --yes       # Stage 3 — commits to real Firestore
                                        # (needs GOOGLE_APPLICATION_CREDENTIALS)

node bin/generate_bundles.js     # Stage 4 — writes assets/vocab/vocab_*.json
                                  # + updates lib/utils/vocab_bundle_constants.dart
```

`npm test` (or `node --test`) runs the pure-logic unit tests
(`test/*.test.js`) — no network, no credentials, no live services
involved.

## Inputs / outputs

- `input/oxford3000.csv`, `input/oxford5000.csv` — the source CSVs
  (`word,cefrLevel,topics,pos,source`), git-ignored (not project source,
  just imported reference data).
- `output/canonical_vocab.json` — Stage 1's merged result: one record per
  normalized word, `meanings[].translation` all `null`. Regenerated fresh
  every Stage 1 run.
- `output/import_report.json` — Stage 1's full report (row counts,
  duplicate/overlap counts, CEFR distribution, malformed rows, same-POS
  collisions needing manual review).
- `output/translations_cache.json` — Stage 2's resumable cache, keyed by
  `word::pos`. **This is the thing that makes reruns cheap** — never
  delete it casually.
- `output/canonical_vocab_translated.json` — canonical data with
  `translation` filled in from the cache. What Stages 3 and 4 both read.

## Known limitation: same-POS collisions

The `vocabWords` schema has one `{pos, translation}` slot per part of
speech — it can't hold two *different senses* of the same POS for the
same word (e.g. "bank" as a noun meaning both the financial institution
and a riverbank). When the source CSVs contribute the same word+POS
combination from more than one row, Stage 1 keeps the first-encountered
row's context and reports the discarded one in
`import_report.json`'s `samePosCollisions` (10 cases in the real Oxford
data as of this writing — small enough for manual review, not a blocker).
See `DATA_MODEL.md` §2 for the schema-level discussion.
