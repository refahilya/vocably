'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { loadDotEnv } = require('../lib/dotenv');

function withTempEnvFile(contents, fn) {
  const filePath = path.join(os.tmpdir(), `vocab-import-dotenv-test-${Date.now()}-${Math.random()}.env`);
  fs.writeFileSync(filePath, contents);
  try {
    return fn(filePath);
  } finally {
    fs.unlinkSync(filePath);
  }
}

test('loads KEY=VALUE pairs into process.env', () => {
  withTempEnvFile('FOO_TEST_VAR=bar\n', (filePath) => {
    delete process.env.FOO_TEST_VAR;
    loadDotEnv(filePath);
    assert.equal(process.env.FOO_TEST_VAR, 'bar');
    delete process.env.FOO_TEST_VAR;
  });
});

test('does not override an already-set environment variable', () => {
  withTempEnvFile('FOO_TEST_VAR=from-file\n', (filePath) => {
    process.env.FOO_TEST_VAR = 'from-shell';
    loadDotEnv(filePath);
    assert.equal(process.env.FOO_TEST_VAR, 'from-shell');
    delete process.env.FOO_TEST_VAR;
  });
});

test('ignores blank lines and comments', () => {
  withTempEnvFile('\n# a comment\nFOO_TEST_VAR=bar\n\n', (filePath) => {
    delete process.env.FOO_TEST_VAR;
    loadDotEnv(filePath);
    assert.equal(process.env.FOO_TEST_VAR, 'bar');
    delete process.env.FOO_TEST_VAR;
  });
});

test('strips matching surrounding quotes', () => {
  withTempEnvFile('FOO_TEST_VAR="quoted value"\n', (filePath) => {
    delete process.env.FOO_TEST_VAR;
    loadDotEnv(filePath);
    assert.equal(process.env.FOO_TEST_VAR, 'quoted value');
    delete process.env.FOO_TEST_VAR;
  });
});

test('does nothing (no throw) if the file does not exist', () => {
  assert.doesNotThrow(() => loadDotEnv(path.join(os.tmpdir(), 'definitely-does-not-exist.env')));
});
