import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';

async function start(dbPath, options = {}) {
  const app = createApp({ dbPath, allowedOrigins: '', ...options });
  await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
  return {
    ...app,
    base: 'http://127.0.0.1:' + app.server.address().port,
  };
}

async function post(base, route, payload) {
  const response = await fetch(base + route, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return { status: response.status, retryAfter: response.headers.get('retry-after'),
    body: await response.json() };
}

test('failed login limits persist across API restarts and return Retry-After', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'enet-rate-limit-'));
  const dbPath = join(directory, 'enet.sqlite');
  let api = await start(dbPath, { authRateLimitMax: 2, authRateLimitWindowMs: 60_000 });
  try {
    const registered = await post(api.base, '/v1/auth/register', {
      name: 'Rate Test', email: 'rate@example.org', password: 'A-Long-Rate-Test-Password-123',
    });
    assert.equal(registered.status, 201);

    const first = await post(api.base, '/v1/auth/login', {
      email: 'rate@example.org', password: 'wrong-password',
    });
    assert.equal(first.status, 401);

    const second = await post(api.base, '/v1/auth/login', {
      email: 'rate@example.org', password: 'wrong-password',
    });
    assert.equal(second.status, 429);
    assert.equal(second.body.error.code, 'rate_limited');
    assert.equal(second.retryAfter, '60');
  } finally {
    await api.close();
  }

  api = await start(dbPath, { authRateLimitMax: 2, authRateLimitWindowMs: 60_000 });
  try {
    const afterRestart = await post(api.base, '/v1/auth/login', {
      email: 'rate@example.org', password: 'A-Long-Rate-Test-Password-123',
    });
    assert.equal(afterRestart.status, 429);
    assert.equal(afterRestart.retryAfter, '60');
  } finally {
    await api.close();
    rmSync(directory, { recursive: true, force: true });
  }
});

test('registration abuse limit is independent from login failure buckets', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'enet-signup-limit-'));
  const api = await start(join(directory, 'enet.sqlite'), {
    registerRateLimitMax: 1, authRateLimitWindowMs: 60_000,
  });
  try {
    const first = await post(api.base, '/v1/auth/register', {
      name: 'First', email: 'first@example.org', password: 'A-Long-First-Password-123',
    });
    assert.equal(first.status, 201);

    const second = await post(api.base, '/v1/auth/register', {
      name: 'Second', email: 'second@example.org', password: 'A-Long-Second-Password-123',
    });
    assert.equal(second.status, 429);
    assert.equal(second.body.error.code, 'rate_limited');
  } finally {
    await api.close();
    rmSync(directory, { recursive: true, force: true });
  }
});
