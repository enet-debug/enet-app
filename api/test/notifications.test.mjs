import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';

test('notifications persist and cannot be read across users', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'enet-notifications-'));
  const database = join(directory, 'enet.sqlite');
  async function boot() {
    const app = createApp({ dbPath: database, allowedOrigins: '' });
    await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
    return { ...app, url: 'http://127.0.0.1:' + app.server.address().port };
  }
  let api = await boot();
  const call = async (route, method = 'GET', body, token) => {
    const response = await fetch(api.url + route, {
      method,
      headers: {
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: 'Bearer ' + token } : {}),
        'X-eNet-Client': 'eNet APP Linux',
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: response.status, json: await response.json() };
  };
  try {
    assert.equal((await call('/v1/notifications')).status, 401);
    const primary = await call('/v1/auth/register', 'POST', {
      name: 'Primary', email: 'primary@example.org', password: 'Very-Long-Test-Password-101',
    });
    assert.equal(primary.status, 201);
    const token1 = primary.json.token;
    const welcome = await call('/v1/notifications', 'GET', undefined, token1);
    assert.equal(welcome.status, 200);
    assert.equal(welcome.json.unread_count, 1);
    assert.equal(welcome.json.notifications[0].type, 'welcome');
    assert.equal(welcome.json.notifications[0].title, 'Добро пожаловать в eNet');
    const welcomeId = welcome.json.notifications[0].id;
    assert.equal((await call('/v1/notifications/read', 'POST', { id: 'oops' }, token1)).status, 400);
    assert.equal((await call('/v1/notifications/read', 'POST', { id: welcomeId }, token1)).status, 200);
    assert.equal((await call('/v1/notifications/read', 'POST', { id: welcomeId }, token1)).status, 200);
    assert.equal((await call('/v1/notifications', 'GET', undefined, token1)).json.unread_count, 0);

    const secondary = await call('/v1/auth/register', 'POST', {
      name: 'Secondary', email: 'secondary@example.org', password: 'Very-Long-Test-Password-102',
    });
    assert.equal(secondary.status, 201);
    assert.equal((await call('/v1/notifications/read', 'POST', { id: welcomeId }, secondary.json.token)).status, 404);

    const login = await call('/v1/auth/login', 'POST', {
      email: 'primary@example.org', password: 'Very-Long-Test-Password-101',
    });
    assert.equal(login.status, 200);
    const updated = await call('/v1/notifications', 'GET', undefined, token1);
    assert.equal(updated.json.unread_count, 1);
    assert.equal(updated.json.notifications.length, 2);
    assert.equal(updated.json.notifications[0].type, 'security');
    assert.ok(updated.json.notifications[0].body.includes('eNet APP Linux'));
    assert.deepEqual((await call('/v1/notifications/read-all', 'POST', undefined, token1)).json,
      { ok: true, updated: 1 });
    assert.equal((await call('/v1/notifications', 'GET', undefined, token1)).json.unread_count, 0);
    await api.close();

    api = await boot();
    const persisted = await call('/v1/notifications', 'GET', undefined, token1);
    assert.equal(persisted.status, 200);
    assert.equal(persisted.json.notifications.length, 2);
    assert.equal(persisted.json.unread_count, 0);
    const meta = await call('/v1/meta');
    assert.ok(meta.json.capabilities.includes('notifications'));
  } finally {
    await api.close().catch(() => {});
    rmSync(directory, { recursive: true, force: true });
  }
});
