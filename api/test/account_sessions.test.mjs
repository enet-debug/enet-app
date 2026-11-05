import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { createApp } from '../src/app.mjs';

function temporaryApp() {
  const directory = mkdtempSync(join(tmpdir(), 'enet-sessions-'));
  const dbPath = join(directory, 'enet.sqlite');
  return { directory, dbPath };
}

test('profile updates and selective session revocation enforce ownership', async () => {
  const { directory, dbPath } = temporaryApp();
  const { server, close } = createApp({ dbPath, allowedOrigins: '' });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const origin = 'http://127.0.0.1:' + server.address().port;

  async function call(route, method, token, payload, label = 'Test Client') {
    const response = await fetch(origin + route, {
      method,
      headers: {
        'X-eNet-Client': label,
        ...(token ? { Authorization: 'Bearer ' + token } : {}),
        ...(payload ? { 'Content-Type': 'application/json' } : {}),
      },
      body: payload ? JSON.stringify(payload) : undefined,
    });
    return { status: response.status, data: await response.json() };
  }

  try {
    const alice = await call('/v1/auth/register', 'POST', undefined,
      { name: 'Alice First', email: 'alice@example.org', password: 'Secure-Alice-Password-2026' }, 'Ubuntu Desktop');
    assert.equal(alice.status, 201);
    const first = alice.data.token;
    const second = (await call('/v1/auth/login', 'POST', undefined,
      { email: 'alice@example.org', password: 'Secure-Alice-Password-2026' }, 'Android Phone')).data.token;
    const bob = await call('/v1/auth/register', 'POST', undefined,
      { name: 'Bob', email: 'bob@example.org', password: 'Secure-Bob-Password-2026' }, 'Bob Device');
    assert.equal(bob.status, 201);
    assert.equal((await call('/v1/auth/sessions', 'GET')).status, 401);
    const list = await call('/v1/auth/sessions', 'GET', first);
    assert.equal(list.status, 200);
    assert.equal(list.data.sessions.length, 2);
    const mine = list.data.sessions.find(x => x.current);
    const other = list.data.sessions.find(x => !x.current);
    assert.equal(mine.device, 'Ubuntu Desktop');
    assert.equal(other.device, 'Android Phone');
    assert.match(other.id, /^[a-f0-9-]{36}$/);
    assert.ok(Date.parse(other.created_at));
    assert.ok(Date.parse(other.last_seen_at));
    assert.ok(Date.parse(other.expires_at));
    assert.equal((await call('/v1/auth/profile', 'POST', first, { name: 'X' })).status, 400);
    assert.equal((await call('/v1/auth/profile', 'POST', first, { name: ['Hello','World'].join(String.fromCharCode(10)) })).status, 400);
    const updated = await call('/v1/auth/profile', 'POST', first, { name: 'Alice Updated' });
    assert.equal(updated.status, 200);
    assert.equal(updated.data.user.name, 'Alice Updated');
    assert.equal((await call('/v1/auth/me', 'GET', second)).data.user.name, 'Alice Updated');
    assert.equal((await call('/v1/auth/me', 'GET', bob.data.token)).data.user.name, 'Bob');

    const bobs = await call('/v1/auth/sessions', 'GET', bob.data.token);
    assert.equal(bobs.data.sessions.length, 1);
    assert.equal((await call('/v1/auth/sessions/revoke', 'POST', first,
      { session_id: bobs.data.sessions[0].id })).status, 404);
    assert.equal((await call('/v1/auth/sessions/revoke', 'POST', first,
      { session_id: mine.id })).status, 404);
    assert.equal((await call('/v1/auth/sessions/revoke', 'POST', first,
      { session_id: 'not-a-uuid' })).status, 400);
    assert.equal((await call('/v1/auth/sessions/revoke', 'POST', first,
      { session_id: other.id })).status, 200);
    assert.equal((await call('/v1/auth/me', 'GET', second)).status, 401);
    assert.equal((await call('/v1/auth/me', 'GET', first)).status, 200);
    assert.equal((await call('/v1/auth/me', 'GET', bob.data.token)).status, 200);
    assert.equal((await call('/v1/auth/sessions', 'GET', first)).data.sessions.length, 1);
  } finally {
    await close();
    rmSync(directory, { recursive: true, force: true });
  }
});

test('existing SQLite sessions are migrated without logging users out', async () => {
  const { directory, dbPath } = temporaryApp();
  const legacy = new DatabaseSync(dbPath);
  const token = 'legacy-session-token-with-adequate-length-and-entropy';
  const hashed = createHash('sha256').update(token).digest('hex');
  const expiry = Date.now() + 12 * 60 * 60 * 1000;
  legacy.exec(`CREATE TABLE users(id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL, password_hash TEXT NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE sessions(token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL,
    expires_at INTEGER NOT NULL);`);
  legacy.prepare('INSERT INTO users(id,email,name,password_hash,created_at) VALUES (?,?,?,?,?)')
    .run('existing-user', 'existing@example.org', 'Existing', 'legacy-hash', new Date().toISOString());
  legacy.prepare('INSERT INTO sessions(token_hash,user_id,expires_at) VALUES (?,?,?)')
    .run(hashed, 'existing-user', expiry);
  legacy.close();
  const { server, close } = createApp({ dbPath, allowedOrigins: '' });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const origin = 'http://127.0.0.1:' + server.address().port;
  try {
    const response = await fetch(origin + '/v1/auth/sessions', {
      headers: { Authorization: 'Bearer ' + token },
    });
    assert.equal(response.status, 200);
    const { sessions } = await response.json();
    assert.equal(sessions.length, 1);
    assert.equal(sessions[0].current, true);
    assert.equal(sessions[0].device, 'Неизвестное устройство');
    assert.ok(sessions[0].id.length > 30);
  } finally {
    await close();
    rmSync(directory, { recursive: true, force: true });
  }
});
