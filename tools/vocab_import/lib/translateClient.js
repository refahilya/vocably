'use strict';

const SYSTEM_PROMPT = `You are a bilingual English-Indonesian lexicographer helping populate a vocabulary-learning app for Indonesian students.

You will receive a JSON array of English word meanings, each with the word, its part of speech, its CEFR level, and the topic(s) it belongs to. For EACH item, produce the single most appropriate, natural Indonesian translation for that specific word used in that specific part of speech (not other senses of the word).

Respond with ONLY a JSON array (no markdown fences, no commentary), same length and same order as the input, where each element is: {"word": "...", "pos": "...", "translation": "..."}. The "translation" must be a short Indonesian word or short phrase (not a full sentence, not an explanation).`;

/**
 * Calls the configured OpenAI-compatible chat-completions endpoint for
 * one batch of translation requests. Retries on network failure or a
 * 429/5xx response with exponential backoff (honoring a `Retry-After`
 * header when present); anything else (4xx other than 429, malformed
 * response shape) is not retried and surfaces as a thrown error for the
 * caller to log and skip.
 *
 * Injectable `fetchImpl` (defaults to the global `fetch`, available on
 * Node >= 18) so tests can supply a fake implementation instead of
 * hitting the real network.
 */
async function translateBatch(
  items,
  { apiKey, baseUrl, apiPath, model, fetchImpl = fetch, maxRetries = 4 }
) {
  if (!apiKey) {
    throw new Error(
      'OPENAI_API_KEY is not set — see tools/vocab_import/README.md for ' +
        'where to configure it.'
    );
  }
  if (items.length === 0) return [];

  const url = `${baseUrl}${apiPath}`;
  const userContent = JSON.stringify(
    items.map((i) => ({
      word: i.word,
      pos: i.pos,
      cefrLevel: i.cefrLevel,
      topics: i.topics,
    }))
  );

  let attempt = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    attempt++;
    let response;
    try {
      response = await fetchImpl(url, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          temperature: 0.2,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: userContent },
          ],
        }),
      });
    } catch (networkError) {
      if (attempt > maxRetries) {
        throw new Error(
          `Network error calling translation API after ${attempt} attempts: ${networkError.message}`
        );
      }
      await backoff(attempt);
      continue;
    }

    if (response.status === 429 || response.status >= 500) {
      if (attempt > maxRetries) {
        throw new Error(
          `Translation API returned ${response.status} after ${attempt} attempts`
        );
      }
      const retryAfterHeader = response.headers?.get?.('retry-after');
      const retryAfterMs = retryAfterHeader
        ? Number(retryAfterHeader) * 1000
        : null;
      await backoff(attempt, retryAfterMs);
      continue;
    }

    if (!response.ok) {
      const bodyText = await safeText(response);
      throw new Error(
        `Translation API returned ${response.status}: ${bodyText.slice(0, 500)}`
      );
    }

    const json = await response.json();
    const content = json?.choices?.[0]?.message?.content;
    if (typeof content !== 'string') {
      throw new Error(
        `Translation API response had no message content: ${JSON.stringify(json).slice(0, 500)}`
      );
    }

    const parsed = parseModelJsonArray(content);
    if (!Array.isArray(parsed) || parsed.length !== items.length) {
      throw new Error(
        `Translation API response shape mismatch: expected an array of ` +
          `${items.length} items, got ${
            Array.isArray(parsed) ? parsed.length : typeof parsed
          }. Raw content: ${content.slice(0, 500)}`
      );
    }

    return parsed.map((entry, index) => ({
      word: items[index].word,
      pos: items[index].pos,
      translation: typeof entry?.translation === 'string' ? entry.translation.trim() : null,
    }));
  }
}

/** Strips a ```json ... ``` / ``` ... ``` fence if the model added one anyway. */
function parseModelJsonArray(content) {
  let text = content.trim();
  if (text.startsWith('```')) {
    text = text.replace(/^```(?:json)?\n?/, '').replace(/```$/, '').trim();
  }
  return JSON.parse(text);
}

async function safeText(response) {
  try {
    return await response.text();
  } catch {
    return '(unreadable response body)';
  }
}

function backoff(attempt, explicitMs) {
  const ms = explicitMs ?? Math.min(1000 * 2 ** (attempt - 1), 15000);
  return new Promise((resolve) => setTimeout(resolve, ms));
}

module.exports = { translateBatch, parseModelJsonArray };
