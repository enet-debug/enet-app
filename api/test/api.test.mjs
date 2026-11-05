import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';

test('registration, session, catalog and logout', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'enet-api-test-'));
  const { server, close } = createApp({ dbPath: join(dir, 'db.sqlite'), allowedOrigins: '' });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = 'http://127.0.0.1:' + server.address().port;
  const call = async (path, method = 'GET', data, token) => {
    const response = await fetch(base + path, {
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
    const healthResponse = await fetch(base + '/health');
    assert.equal(healthResponse.status, 200);
    assert.deepEqual(await healthResponse.json(), {
      status: 'ok', service: 'enet-api', version: '0.4.0',
    });
    assert.equal(healthResponse.headers.get('x-content-type-options'), 'nosniff');
    assert.equal(healthResponse.headers.get('cross-origin-resource-policy'), 'same-origin');
    assert.equal((await call('/v1/auth/me')).status, 401);
    assert.equal((await call('/v1/services')).status, 401);
    assert.equal((await call('/v1/auth/register', 'POST', {
      name: 'User', email: 'bad-address', password: 'LongEnoughPassword123!',
    })).status, 400);
    const created = await call('/v1/auth/register', 'POST', {
      name: 'Test User', email: 'test@example.org', password: 'LongEnoughPassword123!',
    });
    assert.equal(created.status, 201);
    assert.equal(created.data.user.email, 'test@example.org');
    assert.ok(created.data.token.length > 30);
    assert.equal((await call('/v1/auth/register', 'POST', {
      name: 'Test User', email: 'test@example.org', password: 'LongEnoughPassword123!',
    })).status, 409);
    assert.equal((await call('/v1/auth/login', 'POST', {
      email: 'test@example.org', password: 'wrongpassword',
    })).status, 401);
    const login = await call('/v1/auth/login', 'POST', {
      email: 'test@example.org', password: 'LongEnoughPassword123!',
    });
    assert.equal(login.status, 200);
    const token = login.data.token;
    assert.equal((await call('/v1/auth/me', 'GET', undefined, token)).data.user.name, 'Test User');
    assert.equal((await call('/v1/services', 'GET', undefined, token)).data.services[0].id, 'prodayzer');
    assert.equal((await call('/v1/auth/logout', 'POST', undefined, token)).status, 200);
    assert.equal((await call('/v1/auth/me', 'GET', undefined, token)).status, 401);
    assert.equal((await call('/v1/auth/reset-password', 'POST')).status, 501);
  } finally {
    await close();
    rmSync(dir, { recursive: true, force: true });
  }
});

test('change password and revoke other sessions', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'enet-security-test-'));
  const { server, close } = createApp({ dbPath: join(dir, 'db.sqlite'), allowedOrigins: '' });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = 'http://127.0.0.1:' + server.address().port;
  const call = async (route, data, token) => {
    const response = await fetch(base + route, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
      body: JSON.stringify(data ?? {}),
    });
    return { status: response.status, body: await response.json() };
  };
  const me = async token => (await fetch(base + '/v1/auth/me', {
    headers: { Authorization: 'Bearer ' + token },
  })).status;
  try {
    const account = { email: 'security@example.org', name: 'Security Test', password: 'Initial-Passphrase-123' };
    const registered = await call('/v1/auth/register', account);
    assert.equal(registered.status, 201);
    const first = registered.body.token;
    const second = (await call('/v1/auth/login', {
      email: account.email, password: account.password,
    })).body.token;
    assert.equal(await me(first), 200);
    assert.equal(await me(second), 200);
    assert.equal((await call('/v1/auth/logout-others', {}, undefined)).status, 401);
    const kicked = await call('/v1/auth/logout-others', {}, first);
    assert.deepEqual(kicked.body, { ok: true, revoked: 1 });
    assert.equal(await me(second), 401);
    assert.equal(await me(first), 200);
    const oldLogin = await call('/v1/auth/login', {
      email: account.email, password: account.password,
    });
    assert.equal(oldLogin.status, 200);
    assert.equal((await call('/v1/auth/change-password', {
      current_password: 'wrong-password', new_password: 'A-Different-Safe-Pass-456',
    }, first)).status, 403);
    assert.equal((await call('/v1/auth/change-password', {
      current_password: account.password, new_password: 'short',
    }, first)).status, 400);
    const changed = await call('/v1/auth/change-password', {
      current_password: account.password, new_password: 'A-Different-Safe-Pass-456',
    }, first);
    assert.equal(changed.status, 200);
    assert.equal(changed.body.other_sessions_revoked, true);
    assert.equal(await me(first), 200);
    assert.equal(await me(oldLogin.body.token), 401);
    assert.equal((await call('/v1/auth/login', {
      email: account.email, password: account.password,
    })).status, 401);
    assert.equal((await call('/v1/auth/login', {
      email: account.email, password: 'A-Different-Safe-Pass-456',
    })).status, 200);
  } finally {
    await close();
    rmSync(dir, { recursive: true, force: true });
  }
});
