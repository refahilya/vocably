'use strict';

const fs = require('fs');

/**
 * Minimal `.env` loader — deliberately hand-rolled instead of adding the
 * `dotenv` npm package as a new dependency for ~15 lines of parsing.
 * Only sets a variable if it isn't already present in `process.env`
 * (so a real shell-exported value always wins over the file), and never
 * logs the values it reads.
 */
function loadDotEnv(filePath) {
  if (!fs.existsSync(filePath)) return;
  const text = fs.readFileSync(filePath, 'utf8');
  for (const rawLine of text.split('\n')) {
    const line = rawLine.trim();
    if (line === '' || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
}

module.exports = { loadDotEnv };
