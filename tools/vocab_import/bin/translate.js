#!/usr/bin/env node
'use strict';

/**
 * Stage 2 of the vocab import pipeline: fills in `meanings[].translation`
 * for every meaning in `output/canonical_vocab.json` that doesn't already
 * have one — via the OpenAI-compatible endpoint configured in the
 * project root's `.env` (never hardcoded, never logged).
 *
 * Resumable/idempotent by design: results are written to
 * `output/translations_cache.json` (keyed by word::pos) after EVERY
 * batch, not just at the end — an interrupted run loses at most one
 * in-flight batch, and rerunning skips everything already cached.
 *
 * Usage:
 *   node bin/translate.js                 # full run
 *   node bin/translate.js --limit 5        # smoke-test the first 5
 *                                           # missing translations only
 *   node bin/translate.js --batch-size 20  # override batch size (default 15)
 */

const fs = require('fs');
const path = require('path');

const { loadDotEnv } = require('../lib/dotenv');
const { loadCache, saveCache, cacheKey } = require('../lib/translationCache');
const { translateBatch } = require('../lib/translateClient');

const ROOT = path.join(__dirname, '..');
const REPO_ROOT = path.join(ROOT, '..', '..');
const OUTPUT_DIR = path.join(ROOT, 'output');
const CANONICAL_PATH = path.join(OUTPUT_DIR, 'canonical_vocab.json');
const CACHE_PATH = path.join(OUTPUT_DIR, 'translations_cache.json');
const TRANSLATED_PATH = path.join(OUTPUT_DIR, 'canonical_vocab_translated.json');

loadDotEnv(path.join(REPO_ROOT, '.env'));

function parseArgs(argv) {
  const args = { limit: null, batchSize: 15 };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--limit') args.limit = Number(argv[++i]);
    if (argv[i] === '--batch-size') args.batchSize = Number(argv[++i]);
  }
  return args;
}

function chunk(array, size) {
  const out = [];
  for (let i = 0; i < array.length; i += size) out.push(array.slice(i, i + size));
  return out;
}

async function main() {
  const { limit, batchSize } = parseArgs(process.argv.slice(2));

  if (!fs.existsSync(CANONICAL_PATH)) {
    console.error(
      `Missing ${path.relative(ROOT, CANONICAL_PATH)} — run "node bin/merge.js" first.`
    );
    process.exitCode = 1;
    return;
  }

  const apiKey = process.env.OPENAI_API_KEY;
  const baseUrl = process.env.OPENAI_BASE_URL;
  const apiPath = process.env.OPENAI_API_PATH;
  const model = process.env.OPENAI_MODEL;

  if (!apiKey || !baseUrl || !apiPath || !model) {
    console.error(
      'Missing translation API configuration. Expected all four of ' +
        'OPENAI_API_KEY, OPENAI_BASE_URL, OPENAI_API_PATH, OPENAI_MODEL ' +
        `to be set in ${path.relative(ROOT, path.join(REPO_ROOT, '.env'))}.`
    );
    process.exitCode = 1;
    return;
  }

  const documents = JSON.parse(fs.readFileSync(CANONICAL_PATH, 'utf8'));
  const cache = loadCache(CACHE_PATH);

  const needed = [];
  for (const doc of documents) {
    for (const meaning of doc.meanings) {
      const key = cacheKey(doc.word, meaning.pos);
      if (!(key in cache)) {
        needed.push({
          word: doc.word,
          pos: meaning.pos,
          topics: meaning._translationContext?.topics ?? doc.topics,
          cefrLevel: meaning._translationContext?.cefrLevel ?? doc.cefrLevel,
        });
      }
    }
  }

  const totalMeanings = documents.reduce((sum, d) => sum + d.meanings.length, 0);
  const alreadyCached = totalMeanings - needed.length;
  console.log(`Total meanings: ${totalMeanings}`);
  console.log(`Already cached (reused, not regenerated): ${alreadyCached}`);
  console.log(`Missing translations: ${needed.length}`);

  const toProcess = limit ? needed.slice(0, limit) : needed;
  if (limit) {
    console.log(`--limit ${limit}: processing only the first ${toProcess.length} of those.`);
  }

  if (toProcess.length === 0) {
    console.log('Nothing to generate.');
  } else {
    const batches = chunk(toProcess, batchSize);
    console.log(`Processing ${toProcess.length} meanings in ${batches.length} batch(es) of up to ${batchSize}...`);

    let generated = 0;
    let failed = 0;
    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      try {
        const results = await translateBatch(batch, { apiKey, baseUrl, apiPath, model });
        for (const r of results) {
          cache[cacheKey(r.word, r.pos)] = {
            translation: r.translation,
            generatedAt: new Date().toISOString(),
            model,
          };
        }
        saveCache(CACHE_PATH, cache);
        generated += results.length;
        console.log(
          `  batch ${i + 1}/${batches.length}: OK (${results.length} translations) — cache saved`
        );
      } catch (err) {
        failed += batch.length;
        console.error(`  batch ${i + 1}/${batches.length}: FAILED — ${err.message}`);
        console.error('  (already-cached translations from earlier batches are safe; rerun to retry this batch)');
      }
    }
    console.log(`\nGenerated: ${generated}. Failed (not cached, will retry next run): ${failed}.`);
  }

  // Apply the cache on top of the canonical documents and write the
  // translated snapshot — always, even on a --limit smoke-test run, so
  // the output reflects exactly what's in the cache right now.
  const translatedDocuments = documents.map((doc) => ({
    ...doc,
    meanings: doc.meanings.map((m) => {
      const cached = cache[cacheKey(doc.word, m.pos)];
      const { _translationContext, ...rest } = m;
      return { ...rest, translation: cached ? cached.translation : m.translation };
    }),
  }));
  fs.writeFileSync(TRANSLATED_PATH, JSON.stringify(translatedDocuments, null, 2));

  const stillMissing = translatedDocuments.reduce(
    (sum, d) => sum + d.meanings.filter((m) => m.translation === null).length,
    0
  );
  console.log(`\nWrote ${path.relative(ROOT, TRANSLATED_PATH)} (${stillMissing} meanings still without a translation).`);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exitCode = 1;
});
