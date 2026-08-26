'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { translateBatch } = require('../lib/translateClient');

function jsonResponse(status, body, headers = {}) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: (name) => headers[name.toLowerCase()] ?? null },
    json: async () => body,
    text: async () => JSON.stringify(body),
  };
}

test('sends items and parses a well-formed model response', async () => {
  let capturedBody;
  const fakeFetch = async (url, options) => {
    capturedBody = JSON.parse(options.body);
    return jsonResponse(200, {
      choices: [
        {
          message: {
            content: JSON.stringify([
              { word: 'bank', pos: 'noun', translation: 'bank' },
            ]),
          },
        },
      ],
    });
  };

  const result = await translateBatch(
    [{ word: 'bank', pos: 'noun', topics: ['Money'], cefrLevel: 'A1' }],
    { apiKey: 'x', baseUrl: 'https://example.com', apiPath: '/chat', model: 'm', fetchImpl: fakeFetch }
  );

  assert.deepEqual(result, [{ word: 'bank', pos: 'noun', translation: 'bank' }]);
  assert.equal(capturedBody.model, 'm');
  assert.equal(capturedBody.messages[1].content.includes('"pos":"noun"'), true);
});

test('strips a markdown code fence if the model added one', async () => {
  const fakeFetch = async () =>
    jsonResponse(200, {
      choices: [
        {
          message: {
            content:
              '```json\n[{"word":"cat","pos":"noun","translation":"kucing"}]\n```',
          },
        },
      ],
    });

  const result = await translateBatch(
    [{ word: 'cat', pos: 'noun', topics: [], cefrLevel: 'A1' }],
    { apiKey: 'x', baseUrl: 'https://example.com', apiPath: '/chat', model: 'm', fetchImpl: fakeFetch }
  );

  assert.equal(result[0].translation, 'kucing');
});

test('returns an empty array immediately for an empty batch (no request made)', async () => {
  let called = false;
  const fakeFetch = async () => {
    called = true;
    throw new Error('should not be called');
  };
  const result = await translateBatch([], {
    apiKey: 'x',
    baseUrl: 'https://example.com',
    apiPath: '/chat',
    model: 'm',
    fetchImpl: fakeFetch,
  });
  assert.deepEqual(result, []);
  assert.equal(called, false);
});

test('throws immediately if apiKey is missing', async () => {
  await assert.rejects(
    () =>
      translateBatch([{ word: 'cat', pos: 'noun', topics: [], cefrLevel: 'A1' }], {
        apiKey: '',
        baseUrl: 'https://example.com',
        apiPath: '/chat',
        model: 'm',
        fetchImpl: async () => jsonResponse(200, {}),
      }),
    /OPENAI_API_KEY is not set/
  );
});

test('retries on 429 and eventually succeeds', async () => {
  let calls = 0;
  const fakeFetch = async () => {
    calls++;
    if (calls < 3) return jsonResponse(429, {}, { 'retry-after': '0' });
    return jsonResponse(200, {
      choices: [{ message: { content: '[{"word":"cat","pos":"noun","translation":"kucing"}]' } }],
    });
  };

  const result = await translateBatch(
    [{ word: 'cat', pos: 'noun', topics: [], cefrLevel: 'A1' }],
    { apiKey: 'x', baseUrl: 'https://example.com', apiPath: '/chat', model: 'm', fetchImpl: fakeFetch, maxRetries: 4 }
  );

  assert.equal(calls, 3);
  assert.equal(result[0].translation, 'kucing');
});

test('gives up after exhausting retries on repeated 500s', async () => {
  const fakeFetch = async () => jsonResponse(500, {});
  await assert.rejects(
    () =>
      translateBatch([{ word: 'cat', pos: 'noun', topics: [], cefrLevel: 'A1' }], {
        apiKey: 'x',
        baseUrl: 'https://example.com',
        apiPath: '/chat',
        model: 'm',
        fetchImpl: fakeFetch,
        maxRetries: 1,
      }),
    /after 2 attempts/
  );
});

test('throws (does not retry) on a non-retryable 4xx like 401', async () => {
  let calls = 0;
  const fakeFetch = async () => {
    calls++;
    return jsonResponse(401, { error: 'invalid key' });
  };
  await assert.rejects(
    () =>
      translateBatch([{ word: 'cat', pos: 'noun', topics: [], cefrLevel: 'A1' }], {
        apiKey: 'x',
        baseUrl: 'https://example.com',
        apiPath: '/chat',
        model: 'm',
        fetchImpl: fakeFetch,
      }),
    /401/
  );
  assert.equal(calls, 1);
});

test('throws on a response-length mismatch rather than silently truncating', async () => {
  const fakeFetch = async () =>
    jsonResponse(200, {
      choices: [{ message: { content: '[{"word":"cat","pos":"noun","translation":"kucing"}]' } }],
    });
  await assert.rejects(
    () =>
      translateBatch(
        [
          { word: 'cat', pos: 'noun', topics: [], cefrLevel: 'A1' },
          { word: 'dog', pos: 'noun', topics: [], cefrLevel: 'A1' },
        ],
        { apiKey: 'x', baseUrl: 'https://example.com', apiPath: '/chat', model: 'm', fetchImpl: fakeFetch }
      ),
    /shape mismatch/
  );
});
