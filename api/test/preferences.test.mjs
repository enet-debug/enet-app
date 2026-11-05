import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';

test('readiness, capability discovery and account-isolated favorites', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'enet-favorites-'));
  const dbPath = join(dir, 'db.sqlite');
  const { server, close } = createApp({ dbPath });
  await new Promise(done => server.listen(0, '127.0.0.1', done));
  const url = 'http://127.0.0.1:' + server.address().port;

  async function call(path, method = 'GET', token, body) {
    const response = await fetch(url + path, {
      method,
      headers: {
        ...(token ? { Authorization: 'Bearer ' + token } : {}),
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: response.status, body: await response.json(), requestId: response.headers.get('x-request-id') };
  }

  try {
    const health = await call('/health');
    assert.equal(health.status, 200);
    assert.equal(health.body.version, '0.4.0');
    assert.match(health.requestId, /^[a-f\d-]{36}$/i);
    assert.deepEqual((await call('/ready')).body, { status: 'ready', storage: 'sqlite' });
    const meta = await call('/v1/meta');
    assert.equal(meta.body.services.single_sign_on, false);
    assert.ok(meta.body.capabilities.includes('favorites'));

    const first = await call('/v1/auth/register', 'POST', undefined, {
      email: 'first@example.org', name: 'First', password: 'Password-First-2026!',
    });
    const second = await call('/v1/auth/register', 'POST', undefined, {
      email: 'second@example.org', name: 'Second', password: 'Password-Second-2026!',
    });
    assert.equal(first.status, 201);
    assert.equal(second.status, 201);
    const a = first.body.token;
    const b = second.body.token;
    assert.equal((await call('/v1/me/preferences')).status, 401);
    assert.deepEqual((await call('/v1/me/preferences', 'GET', a)).body.favorite_services, []);
    assert.equal((await call('/v1/me/preferences', 'POST', a, { favorite_services: ['invalid'] })).status, 400);
    assert.equal((await call('/v1/me/preferences', 'POST', a, { favorite_services: ['prodayzer', 'prodayzer'] })).status, 400);
    assert.equal((await call('/v1/me/preferences', 'POST', a, { favorite_services: 'prodayzer' })).status, 400);
    assert.deepEqual((await call('/v1/me/preferences', 'POST', a, {
      favorite_services: ['prodayzer'],
    })).body.favorite_services, ['prodayzer']);
    assert.deepEqual((await call('/v1/me/preferences', 'GET', a)).body.favorite_services, ['prodayzer']);
    assert.deepEqual((await call('/v1/me/preferences', 'GET', b)).body.favorite_services, []);
    assert.deepEqual((await call('/v1/me/preferences', 'POST', a, { favorite_services: [] })).body.favorite_services, []);
  } finally {
    await close();
  }
  // Preferences and accounts survive an API restart.
  const restarted = createApp({ dbPath });
  await new Promise(done => restarted.server.listen(0, '127.0.0.1', done));
  try {
    const response = await fetch('http://127.0.0.1:' + restarted.server.address().port + '/ready');
    assert.equal(response.status, 200);
  } finally {
    await restarted.close();
    rmSync(dir, { recursive: true, force: true });
  }
});
