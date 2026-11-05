import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';

async function withApp(run, options = {}) {
  const directory = mkdtempSync(join(tmpdir(), 'enet-api-sec-'));
  const app = createApp({ dbPath: join(directory, 'api.sqlite'), allowedOrigins: 'https://enet-dev.ru', ...options });
  await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
  try {
    const base = 'http://127.0.0.1:' + app.server.address().port;
    await run(base);
  } finally {
    await app.close();
    rmSync(directory, { recursive: true, force: true });
  }
}

test('readiness, request headers and preflight are reliable', async () => {
  await withApp(async base => {
    const res = await fetch(base + '/ready');
    assert.equal(res.status, 200);
    assert.equal((await res.json()).status, 'ready');
    assert.match(res.headers.get('x-request-id'), /^[0-9a-f-]{36}$/i);
    assert.equal(res.headers.get('permissions-policy'), 'camera=(), microphone=(), geolocation=()');
    const preflight = await fetch(base + '/v1/auth/login', {
      method: 'OPTIONS', headers: { Origin: 'https://enet-dev.ru' },
    });
    assert.equal(preflight.status, 204);
    assert.equal(preflight.headers.get('access-control-expose-headers'), 'X-Request-Id, Retry-After');
  });
});

test('password guessing is limited by email and isolated across app instances', async () => {
  async function attempt(base) {
    return fetch(base + '/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'rate-account@example.org', password: 'Incorrect-Password-1234' }),
    });
  }
  await withApp(async base => {
    for (let n = 0; n < 8; n++) assert.equal((await attempt(base)).status, 401);
    const limited = await attempt(base);
    assert.equal(limited.status, 429);
    assert.ok(Number(limited.headers.get('retry-after')) > 0);
  });
  await withApp(async base => {
    assert.equal((await attempt(base)).status, 401);
  });
});

test('trusted proxy header controls IP-specific login limits', async () => {
  await withApp(async base => {
    for (let i = 0; i < 31; i++) {
      const response = await fetch(base + '/v1/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Real-IP': '203.0.113.30' },
        body: JSON.stringify({ email: 'different-' + i + '@example.org', password: 'Bad-Password-1234' }),
      });
      assert.equal(response.status, i < 30 ? 401 : 429);
    }
    const different = await fetch(base + '/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Real-IP': '203.0.113.31' },
      body: JSON.stringify({ email: 'another@example.org', password: 'Bad-Password-1234' }),
    });
    assert.equal(different.status, 401);
  }, { trustProxy: true });
});
