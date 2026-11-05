import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';

test('favorite services persist across sessions and never leak between accounts', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'enet-favorite-test-'));
  const { server, close } = createApp({ dbPath: join(directory, 'api.sqlite'), allowedOrigins: '' });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = 'http://127.0.0.1:' + server.address().port;
  const call = async (route, method, token, data) => {
    const response = await fetch(base + route, {
      method,
      headers: {
        ...(data ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: 'Bearer ' + token } : {}),
      },
      body: data ? JSON.stringify(data) : undefined,
    });
    return { status: response.status, data: await response.json() };
  };
  try {
    const first = (await call('/v1/auth/register', 'POST', null, {
      email: 'favorites-first@example.org', name: 'First User',
      password: 'Safe-Password-One-2026',
    })).data.token;
    const second = (await call('/v1/auth/register', 'POST', null, {
      email: 'favorites-second@example.org', name: 'Second User',
      password: 'Safe-Password-Two-2026',
    })).data.token;
    assert.equal((await call('/v1/services/favorite', 'POST', null,
      { service_id: 'prodayzer', favorite: true })).status, 401);
    assert.equal((await call('/v1/services/favorite', 'POST', first,
      { service_id: 'unknown-service', favorite: true })).status, 400);
    assert.equal((await call('/v1/services/favorite', 'POST', first,
      { service_id: 'prodayzer', favorite: 'yes' })).status, 400);
    assert.equal((await call('/v1/services', 'GET', first)).data.services[0].favorite, false);
    assert.equal((await call('/v1/services/favorite', 'POST', first,
      { service_id: 'prodayzer', favorite: true })).status, 200);
    assert.equal((await call('/v1/services/favorite', 'POST', first,
      { service_id: 'prodayzer', favorite: true })).status, 200);
    assert.equal((await call('/v1/services', 'GET', first)).data.services[0].favorite, true);
    assert.equal((await call('/v1/services', 'GET', second)).data.services[0].favorite, false);
    const newSession = (await call('/v1/auth/login', 'POST', null, {
      email: 'favorites-first@example.org', password: 'Safe-Password-One-2026',
    })).data.token;
    assert.equal((await call('/v1/services', 'GET', newSession)).data.services[0].favorite, true);
    assert.equal((await call('/v1/services/favorite', 'POST', newSession,
      { service_id: 'prodayzer', favorite: false })).status, 200);
    assert.equal((await call('/v1/services', 'GET', first)).data.services[0].favorite, false);
  } finally {
    await close();
    rmSync(directory, { recursive: true, force: true });
  }
});
