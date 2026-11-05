import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';

test('notification history stays bounded and password changes create a security alert', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'enet-retention-'));
  const database = join(directory, 'api.sqlite');
  const app = createApp({
    dbPath: database,
    allowedOrigins: '',
    maxNotificationHistory: 3,
  });
  await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
  const base = 'http://127.0.0.1:' + app.server.address().port;
  const request = async (path, method, body, token) => {
    const response = await fetch(base + path, {
      method,
      headers: {
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: 'Bearer ' + token } : {}),
        'X-eNet-Client': 'eNet APP Test',
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: response.status, data: await response.json() };
  };
  try {
    const account = {
      name: 'Retention Tester',
      email: 'retention@example.org',
      password: 'Long-Password-For-Testing-123',
    };
    const first = await request('/v1/auth/register', 'POST', account);
    assert.equal(first.status, 201);
    for (let i = 0; i < 4; i++) {
      const logged = await request('/v1/auth/login', 'POST', {
        email: account.email, password: account.password,
      });
      assert.equal(logged.status, 200);
    }
    const feed = await request('/v1/notifications', 'GET', undefined, first.data.token);
    assert.equal(feed.status, 200);
    assert.equal(feed.data.notifications.length, 3);
    assert.equal(feed.data.unread_count, 3);
    assert.ok(feed.data.notifications.every(item => item.type === 'security'));
    const changed = await request('/v1/auth/change-password', 'POST', {
      current_password: account.password,
      new_password: 'Different-Long-Password-456',
    }, first.data.token);
    assert.equal(changed.status, 200);
    const updated = await request('/v1/notifications', 'GET', undefined, first.data.token);
    assert.equal(updated.data.notifications.length, 3);
    assert.equal(updated.data.unread_count, 3);
    assert.ok(updated.data.notifications.some(item => item.title === 'Пароль изменён'));
    assert.equal((await request('/v1/notifications/read-all', 'POST', undefined, first.data.token)).data.updated, 3);
    assert.equal((await request('/v1/notifications', 'GET', undefined, first.data.token)).data.unread_count, 0);
  } finally {
    await app.close();
    rmSync(directory, { recursive: true, force: true });
  }
});
