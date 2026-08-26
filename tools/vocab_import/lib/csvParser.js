'use strict';

/**
 * Minimal RFC4180-ish CSV parser — handles quoted fields with embedded
 * commas and doubled-quote escaping ("") inside quotes, which the Oxford
 * CSVs' `topics`/`pos` JSON-array-looking columns rely on. Carried over
 * from the audit script used for the Milestone 4 CSV audit (same parser,
 * promoted from a scratchpad one-off into this pipeline's real code).
 */
function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;
  let i = 0;
  const len = text.length;
  while (i < len) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 2;
          continue;
        } else {
          inQuotes = false;
          i++;
          continue;
        }
      } else {
        field += c;
        i++;
        continue;
      }
    } else {
      if (c === '"') {
        inQuotes = true;
        i++;
        continue;
      } else if (c === ',') {
        row.push(field);
        field = '';
        i++;
        continue;
      } else if (c === '\r') {
        i++;
        continue;
      } else if (c === '\n') {
        row.push(field);
        rows.push(row);
        row = [];
        field = '';
        i++;
        continue;
      } else {
        field += c;
        i++;
        continue;
      }
    }
  }
  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

/**
 * Parses CSV text into an array of {header: value} record objects, plus
 * the raw header row. Throws if the header doesn't exactly match
 * `expectedHeaders` (order-sensitive) — the import pipeline should fail
 * loudly on a header mismatch rather than silently misreading columns.
 */
function loadCsvRecords(text, expectedHeaders) {
  const rows = parseCsv(text);
  if (rows.length === 0) {
    throw new Error('CSV is empty (no header row found)');
  }
  const header = rows[0];
  if (
    expectedHeaders &&
    (header.length !== expectedHeaders.length ||
      header.some((h, idx) => h !== expectedHeaders[idx]))
  ) {
    throw new Error(
      `Unexpected CSV header. Expected [${expectedHeaders.join(
        ', '
      )}], got [${header.join(', ')}]`
    );
  }

  const dataRows = rows
    .slice(1)
    .filter((r) => r.length > 1 || (r.length === 1 && r[0] !== ''));

  const records = dataRows.map((r) => {
    const obj = {};
    header.forEach((h, idx) => {
      obj[h] = r[idx] !== undefined ? r[idx] : '';
    });
    return obj;
  });

  return { header, records };
}

/**
 * Parses a column that's supposed to hold a JSON array of strings (the
 * `topics`/`pos` columns). Returns `{ ok: true, value }` or
 * `{ ok: false, error }` — never throws, so a single malformed row's
 * bad JSON can be reported and skipped rather than crashing the whole
 * import (`IMPORT PIPELINE REQUIREMENTS`: "Do not silently discard
 * malformed source data" — the caller records skipped rows, this
 * function just never becomes the reason the whole process dies).
 */
function parseJsonStringArray(raw) {
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (e) {
    return { ok: false, error: `invalid JSON: ${e.message} (raw="${raw}")` };
  }
  if (!Array.isArray(parsed)) {
    return { ok: false, error: `not a JSON array (raw="${raw}")` };
  }
  if (!parsed.every((v) => typeof v === 'string' && v.length > 0)) {
    return {
      ok: false,
      error: `array contains a non-string or empty element (raw="${raw}")`,
    };
  }
  return { ok: true, value: parsed };
}

module.exports = { parseCsv, loadCsvRecords, parseJsonStringArray };
