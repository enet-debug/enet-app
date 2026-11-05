import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';

test('workspace tasks support create, update, completion, deletion and owner isolation', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'enet-tasks-test-'));
  const { server, close } = createApp({ dbPath: join(dir, 'db.sqlite') });
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
    assert.equal((await call('/v1/tasks')).status, 401);
    const first = await call('/v1/auth/register', 'POST', {
      name: 'Task Owner', email: 'tasks@example.org', password: 'LongEnoughPassword123!',
    });
    const second = await call('/v1/auth/register', 'POST', {
      name: 'Other User', email: 'other-tasks@example.org', password: 'LongEnoughPassword123!',
    });
    const ownerToken = first.data.token;
    const otherToken = second.data.token;

    assert.equal((await call('/v1/tasks', 'POST', {
      title: '   ', description: 'invalid',
    }, ownerToken)).status, 400);

    const created = await call('/v1/tasks', 'POST', {
      title: 'Подготовить релиз',
      description: 'Проверить сборки Windows и iOS',
      due_at: '2026-11-10T20:59:00.000Z',
    }, ownerToken);
    assert.equal(created.status, 201);
    const id = created.data.task.id;
    assert.equal(created.data.task.title, 'Подготовить релиз');
    assert.equal(created.data.task.completed, false);

    const ownerList = await call('/v1/tasks', 'GET', undefined, ownerToken);
    assert.equal(ownerList.data.summary.total, 1);
    assert.equal(ownerList.data.summary.open, 1);
    assert.equal(ownerList.data.tasks[0].id, id);

    const otherList = await call('/v1/tasks', 'GET', undefined, otherToken);
    assert.deepEqual(otherList.data.tasks, []);
    assert.equal((await call('/v1/tasks/update', 'POST', {
      id, title: 'Чужая задача', description: '', due_at: null,
    }, otherToken)).status, 404);
    assert.equal((await call('/v1/tasks/delete', 'POST', { id }, otherToken)).status, 404);

    const updated = await call('/v1/tasks/update', 'POST', {
      id, title: 'Подготовить eNet 0.9', description: 'Обновить документацию', due_at: null,
    }, ownerToken);
    assert.equal(updated.status, 200);
    assert.equal(updated.data.task.title, 'Подготовить eNet 0.9');
    assert.equal(updated.data.task.due_at, null);

    const completed = await call('/v1/tasks/toggle', 'POST', {
      id, completed: true,
    }, ownerToken);
    assert.equal(completed.status, 200);
    assert.equal(completed.data.task.completed, true);

    const summary = await call('/v1/tasks', 'GET', undefined, ownerToken);
    assert.deepEqual(summary.data.summary, { total: 1, completed: 1, open: 0 });

    assert.equal((await call('/v1/tasks/delete', 'POST', { id }, ownerToken)).status, 200);
    const empty = await call('/v1/tasks', 'GET', undefined, ownerToken);
    assert.deepEqual(empty.data.summary, { total: 0, completed: 0, open: 0 });
    assert.equal((await call('/v1/tasks/toggle', 'POST', {
      id, completed: false,
    }, ownerToken)).status, 404);
  } finally {
    await close();
    rmSync(dir, { recursive: true, force: true });
  }
});
