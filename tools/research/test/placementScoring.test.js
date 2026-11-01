'use strict';

/**
 * K2 placement decision (PT-V1.1) — boundaries, exhaustive properties and
 * the quality flags. Band scores only; no item or key data.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { k2LevelIndex, k0LevelIndex, decide, suspiciousPattern, bandScores, resultFromIndex } = require('../lib/placement/scoring');

const LEVEL = { A1s: -1, A1: 0, A2: 1, B1: 2, B2: 3, C1: 4 };

function* allProfiles() {
  const s = [0, 0, 0, 0, 0];
  for (s[0] = 0; s[0] <= 10; s[0]++)
    for (s[1] = 0; s[1] <= 10; s[1]++)
      for (s[2] = 0; s[2] <= 10; s[2]++)
        for (s[3] = 0; s[3] <= 10; s[3]++)
          for (s[4] = 0; s[4] <= 10; s[4]++) yield s.slice();
}

describe('K2 decision rule', () => {
  it('a band passes at 7, not at 6 (candidate threshold)', () => {
    assert.equal(k2LevelIndex([7, 0, 0, 0, 0]), LEVEL.A1);
    assert.equal(k2LevelIndex([6, 0, 0, 0, 0]), LEVEL.A1s);
    assert.equal(k2LevelIndex([10, 7, 0, 0, 0]), LEVEL.A2);
    assert.equal(k2LevelIndex([10, 6, 0, 0, 0]), LEVEL.A1);
  });

  it('every prerequisite band needs at least 6', () => {
    assert.equal(k2LevelIndex([5, 10, 10, 10, 10]), LEVEL.A1s);
    assert.equal(k2LevelIndex([10, 10, 5, 10, 10]), LEVEL.A2);
    assert.equal(k2LevelIndex([10, 10, 10, 5, 10]), LEVEL.B1);
    assert.equal(k2LevelIndex([10, 10, 10, 10, 10]), LEVEL.C1);
  });

  it('at most one prerequisite band may be exactly 6', () => {
    assert.equal(k2LevelIndex([6, 7, 0, 0, 0]), LEVEL.A2);
    assert.equal(k2LevelIndex([6, 6, 7, 0, 0]), LEVEL.A1s);
    assert.equal(k2LevelIndex([7, 6, 7, 0, 0]), LEVEL.B1);
    assert.equal(k2LevelIndex([7, 6, 6, 6, 7]), LEVEL.A1);
    assert.equal(k2LevelIndex([7, 6, 7, 6, 7]), LEVEL.B1);
    assert.equal(k2LevelIndex([10, 10, 6, 6, 7]), LEVEL.A2);
    assert.equal(k2LevelIndex([10, 10, 6, 7, 7]), LEVEL.C1);
    assert.equal(k2LevelIndex([6, 7, 7, 7, 7]), LEVEL.C1);
  });

  it('selects the highest passing band', () => {
    assert.equal(k2LevelIndex([10, 6, 6, 7, 2]), LEVEL.A1);
    assert.equal(k2LevelIndex([7, 7, 7, 7, 0]), LEVEL.B2);
    assert.equal(k2LevelIndex([7, 7, 7, 0, 7]), LEVEL.B1);
  });

  it('falls back to A1* (A1 + belowA1Threshold, target A2) when no band passes', () => {
    assert.deepEqual(decide([6, 6, 7, 0, 0]), {
      resultLevel: 'A1',
      belowA1Threshold: true,
      pretestTargetBand: 'A2',
      flags: ['below_a1_threshold', 'near_threshold', 'inconsistent_profile'],
    });
    assert.deepEqual(resultFromIndex(-1), { resultLevel: 'A1', belowA1Threshold: true, pretestTargetBand: 'A2' });
  });

  it('maps the research target band = level + 1, and C1 to no band', () => {
    assert.equal(resultFromIndex(LEVEL.A1).pretestTargetBand, 'A2');
    assert.equal(resultFromIndex(LEVEL.A2).pretestTargetBand, 'B1');
    assert.equal(resultFromIndex(LEVEL.B1).pretestTargetBand, 'B2');
    assert.equal(resultFromIndex(LEVEL.B2).pretestTargetBand, 'C1');
    assert.equal(resultFromIndex(LEVEL.C1).pretestTargetBand, null);
  });

  it('is deterministic, monotone, never above PT-V1.0, and matches the recorded distribution', () => {
    const counts = { '-1': 0, 0: 0, 1: 0, 2: 0, 3: 0, 4: 0 };
    let changed = 0;
    for (const s of allProfiles()) {
      const level = k2LevelIndex(s);
      counts[level]++;
      const k0 = k0LevelIndex(s);
      assert.ok(level <= k0, `K2 above PT-V1.0 for ${s}`);
      if (level !== k0) changed++;
      for (let k = 0; k < 5; k++) {
        if (s[k] < 10) {
          const up = s.slice();
          up[k]++;
          assert.ok(k2LevelIndex(up) >= level, `not monotone at ${s} (+1 in band ${k})`);
        }
      }
    }
    // The exhaustive comparison recorded in the decision dossier (161,051 profiles).
    assert.deepEqual(counts, { '-1': 97163, 0: 35332, 1: 16236, 2: 7136, 3: 3136, 4: 2048 });
    assert.equal(changed, 1108);
  });

  it('rejects malformed band scores', () => {
    assert.throws(() => k2LevelIndex([7, 7, 7, 7]));
    assert.throws(() => k2LevelIndex([11, 0, 0, 0, 0]));
    assert.throws(() => k2LevelIndex([1.5, 0, 0, 0, 0]));
  });
});

describe('quality flags (recorded only)', () => {
  it('near_threshold looks at the band above the result (s[0] for A1*), never for C1', () => {
    assert.ok(decide([7, 5, 0, 0, 0]).flags.includes('near_threshold'));
    assert.ok(!decide([7, 4, 0, 0, 0]).flags.includes('near_threshold'));
    assert.ok(decide([5, 0, 0, 0, 0]).flags.includes('near_threshold'));
    assert.deepEqual(decide([10, 10, 10, 10, 10]).flags, []);
  });

  it('inconsistent_profile marks an uncounted band >= 7 above the result', () => {
    assert.ok(decide([7, 6, 6, 6, 7]).flags.includes('inconsistent_profile'));
    assert.ok(!decide([7, 7, 0, 0, 0]).flags.includes('inconsistent_profile'));
  });

  it('suspicious_pattern needs 6 identical non-E letters in a row; E interrupts the run', () => {
    const order = Array.from({ length: 12 }, (_, i) => `i${i}`);
    const answers = (letters) => Object.fromEntries(order.map((id, i) => [id, letters[i]]));
    assert.equal(suspiciousPattern(order, answers('AAAAAABCDABC')), true);
    assert.equal(suspiciousPattern(order, answers('AAAAABCDABCD')), false);
    assert.equal(suspiciousPattern(order, answers('AAAEAAABCDAB')), false);
    assert.equal(suspiciousPattern(order, answers('EEEEEEEEEEEE')), false);
    assert.equal(suspiciousPattern(order, answers('BAAAAAAEBCDA')), true);
  });
});

describe('band scores from answers', () => {
  it('counts only exact key matches; E and wrong letters score 0', () => {
    const bandOf = { a: 'A1', b: 'A1', c: 'A2', d: 'C1' };
    const key = { a: 'A', b: 'B', c: 'C', d: 'D' };
    assert.deepEqual(bandScores({ a: 'A', b: 'E', c: 'C', d: 'A' }, key, bandOf), [1, 1, 0, 0, 0]);
  });
});
