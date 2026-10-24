'use strict';

/**
 * Builds the `researchInstrument/{version}_{band}` documents that the
 * Firestore security rules read (via get()) to validate option IDs and
 * option texts. They hold only the PUBLIC data already shipped in
 * `assets/research/instrument_v1.json` — never the answer key.
 *
 * Used today by the emulator rules tests as trusted fixtures. A later,
 * separately approved researcher script will write the same documents to
 * production (Admin SDK) before the rules are deployed.
 */

const crypto = require('crypto');

function instrumentDocId(version, band) {
  return `${version}_${band}`;
}

/** Returns `[{ id, data }]`, one per band. */
function buildInstrumentDocs(bank, bankJson) {
  const bankSha256 = bankJson ? crypto.createHash('sha256').update(bankJson).digest('hex') : null;
  return bank.bands.map((band) => {
    const items = bank.items.filter((item) => item.band === band);
    return {
      id: instrumentDocId(bank.instrumentVersion, band),
      data: {
        instrumentVersion: bank.instrumentVersion,
        band,
        optionIds: Object.fromEntries(items.map((item) => [item.id, item.options.map((o) => o.id)])),
        optionTexts: Object.fromEntries(
          items.map((item) => [item.id, Object.fromEntries(item.options.map((o) => [o.id, o.text]))])
        ),
        sourceBankSha256: bankSha256,
      },
    };
  });
}

module.exports = { instrumentDocId, buildInstrumentDocs };
