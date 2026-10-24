'use strict';

/**
 * Synthetic instrument fixtures. Every word and option here is invented
 * (letters only, e.g. "wab", "Opsi ab ac c") so no real item, option or
 * answer ever appears in a test name, assertion message or fixture.
 */

const { BANDS, LETTERS, DONT_KNOW_TEXT } = require('../lib/constants');

function alpha(n) {
  const chars = 'abcdefghijklmnopqrstuvwxyz';
  return chars[Math.floor(n / 26)] + chars[n % 26];
}

/** Synthetic §3.4 composition used by every fixture band. */
const FIXTURE_COMPOSITION = { noun: 10, verb: 5, adjective: 5 };

function posLabelFor(index) {
  if (index < FIXTURE_COMPOSITION.noun) return 'kata benda';
  if (index < FIXTURE_COMPOSITION.noun + FIXTURE_COMPOSITION.verb) return 'kata kerja';
  return 'kata sifat';
}

/** 80 parsed-shape items + a balanced key (letter i % 4 → 5 per letter per band). */
function makeFixture() {
  const items = [];
  const keyLetters = new Map();
  BANDS.forEach((band, b) => {
    for (let i = 0; i < 20; i += 1) {
      const number = i + 1;
      const id = `${band}-${String(number).padStart(2, '0')}`;
      const tag = `${alpha(b)} ${alpha(i)}`;
      items.push({
        id,
        band,
        number,
        word: `w${alpha(b * 20 + i)}`,
        posLabel: posLabelFor(i),
        options: Object.fromEntries(LETTERS.map((l) => [l, `Opsi ${tag} ${l}`])),
        dontKnowText: DONT_KNOW_TEXT,
      });
      keyLetters.set(id, LETTERS[i % 4]);
    }
  });
  const composition = Object.fromEntries(BANDS.map((band) => [band, { ...FIXTURE_COMPOSITION, total: 20 }]));
  return { items, keyLetters, composition };
}

const FOOTER = 'Rancangan Instrumen Pretest–Posttest Vocably · Halaman 5 dari 15';

/** Text shaped like pdftotext's raw output for §3.2 + §6 + the §7 heading. */
function rawText(items) {
  const parts = [
    '3.2 Prinsip penyusunan butir • Pada urutan acuan, kunci tersebar seimbang (a, b, c, d masing-masing 5 butir per band).',
    '6. Bentuk pretest (versi siswa)',
    'Berikut tampilan tes sebagaimana dilihat siswa.',
  ];
  BANDS.forEach((band, b) => {
    parts.push(`6.${b + 1} Pretest band ${band} (20 butir)`);
    items
      .filter((item) => item.band === band)
      .forEach((item, i) => {
        parts.push(
          `${item.number}. ${item.word} (${item.posLabel}) ` +
            `${LETTERS.map((l) => `${l}) ${item.options[l]}`).join(' ')} e) ${item.dontKnowText}`
        );
        if (i === 9) parts.push('', FOOTER, '\f');
      });
  });
  parts.push('7. Kunci jawaban (hanya untuk peneliti)', '8. Rubrik penilaian');
  return parts.join('\n');
}

/**
 * Text shaped like §7 in `-layout` mode; [wrapIds] wrap their key text
 * after its first word onto the next line, like a wrapping table cell.
 */
function keyText(items, keyLetters, { wrapIds = [] } = {}) {
  const lines = ['7. Kunci jawaban (hanya untuk peneliti)', 'No   Band A2   Band B1   Band B2   Band C1'];
  for (const item of items) {
    const letter = keyLetters.get(item.id);
    const text = item.options[letter];
    if (wrapIds.includes(item.id)) {
      const [first, ...rest] = text.split(' ');
      lines.push(`${item.number} ${item.word} → ${letter}) ${first}      next cell`);
      lines.push(`                ${rest.join(' ')}`);
    } else {
      lines.push(`${item.number} ${item.word} → ${letter}) ${text}`);
    }
  }
  lines.push('Skor maksimum tiap band: 20.', '8. Rubrik penilaian');
  return lines.join('\n');
}

function compositionText(composition) {
  return [
    'Komposisi kelas kata per band:',
    'Band   Kata benda   Kata kerja   Kata sifat   Total',
    ...BANDS.map((band) => {
      const c = composition[band];
      return `${band}    ${c.noun}    ${c.verb}    ${c.adjective}    ${c.noun + c.verb + c.adjective}`;
    }),
    'Daftar kata target tiap band dapat dilihat pada Bagian 6.',
  ].join('\n');
}

module.exports = { makeFixture, rawText, keyText, compositionText, FIXTURE_COMPOSITION };
