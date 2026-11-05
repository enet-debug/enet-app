import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';

test('API exposes readiness and security response headers', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'enet-ready-test-'));
  const { server, close } = createApp({
    dbPath: join(directory, 'api.sqlite'),
    allowedOrigins: 'https://client.example.org',
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = 'http://127.0.0.1:' + server.address().port;
  try {
    const health = await fetch(base + '/health');
    assert.equal(health.status, 200);
    assert.equal((await health.json()).version, '0.4.0');
    const ready = await fetch(base + '/ready');
    assert.equal(ready.status, 200);
    assert.deepEqual(await ready.json(), { status: 'ready', service: 'enet-api' });
    assert.match(ready.headers.get('x-request-id'), /^[0-9a-f-]{36}$/i);
    assert.equal(ready.headers.get('x-content-type-options'), 'nosniff');
    assert.equal(ready.headers.get('x-frame-options'), 'DENY');
    assert.equal(ready.headers.get('referrer-policy'), 'no-referrer');
    assert.equal(ready.headers.get('permissions-policy'), 'camera=(), microphone=(), geolocation=()');
    assert.equal(ready.headers.get('cache-control'), 'no-store');
    const preflight = await fetch(base + '/v1/auth/login', {
      method: 'OPTIONS',
      headers: { Origin: 'https://client.example.org', 'Access-Control-Request-Method': 'POST' },
    });
    assert.equal(preflight.status, 204);
    assert.equal(preflight.headers.get('access-control-allow-origin'), 'https://client.example.org');
  } finally {
    await close();
    rmSync(directory, { recursive: true, force: true });
  }
});

test('login attempts are throttled by account and return Retry-After', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'enet-rate-test-'));
  const { server, close } = createApp({ dbPath: join(directory, 'api.sqlite'), allowedOrigins: '' });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = 'http://127.0.0.1:' + server.address().port;
  try {
    const statuses = [];
    let limited;
    for (let i = 0; i < 9; i++) {
      const response = await fetch(base + '/v1/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'rate-limit-account@example.org',
          password: 'Definitely-Wrong-Password',
        }),
      });
      statuses.push(response.status);
      if (i === 8) limited = response;
    }
    assert.deepEqual(statuses, [401, 401, 401, 401, 401, 401, 401, 401, 429]);
    assert.ok(Number(limited.headers.get('retry-after')) >= 1);
    assert.equal((await limited.json()).error.code, 'rate_limited');
  } finally {
    await close();
    rmSync(directory, { recursive: true, force: true });
  }
});
