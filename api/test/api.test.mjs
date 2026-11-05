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
    assert.equal((await call('/health')).status, 200);
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
