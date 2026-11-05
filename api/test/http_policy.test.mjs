import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';

async function listen(options) {
  const directory = mkdtempSync(join(tmpdir(), 'enet-http-policy-'));
  const app = createApp({ dbPath: join(directory, 'enet.sqlite'), ...options });
  await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
  return {
    ...app,
    directory,
    base: 'http://127.0.0.1:' + app.server.address().port,
    dispose: async () => {
      await app.close();
      rmSync(directory, { recursive: true, force: true });
    },
  };
}

test('CORS preflight is restricted to configured browser origins', async () => {
  const app = await listen({ allowedOrigins: 'https://enet-dev.ru,https://www.enet-dev.ru' });
  try {
    const allowed = await fetch(app.base + '/v1/auth/login', {
      method: 'OPTIONS',
      headers: {
        Origin: 'https://enet-dev.ru',
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'authorization,content-type',
      },
    });
    assert.equal(allowed.status, 204);
    assert.equal(allowed.headers.get('access-control-allow-origin'), 'https://enet-dev.ru');
    assert.match(allowed.headers.get('x-request-id') || '', /^[0-9a-f-]{36}$/i);

    const denied = await fetch(app.base + '/v1/auth/login', {
      method: 'OPTIONS',
      headers: { Origin: 'https://attacker.example' },
    });
    assert.equal(denied.status, 403);
    assert.equal(denied.headers.get('access-control-allow-origin'), null);
  } finally {
    await app.dispose();
  }
});

test('trusted proxy client IP is used only when proxy trust is enabled', async () => {
  const app = await listen({
    trustProxy: true,
    loginIpRateLimitMax: 1,
    authRateLimitMax: 100,
    authRateLimitWindowMs: 60_000,
  });
  const post = async (route, payload, ip) => {
    const response = await fetch(app.base + route, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Real-IP': ip,
      },
      body: JSON.stringify(payload),
    });
    return { status: response.status, retryAfter: response.headers.get('retry-after') };
  };
  try {
    const registration = await post('/v1/auth/register', {
      name: 'Proxy Test',
      email: 'proxy@example.org',
      password: 'A-Long-Proxy-Test-Password-123',
    }, '198.51.100.10');
    assert.equal(registration.status, 201);

    const first = await post('/v1/auth/login', {
      email: 'proxy@example.org', password: 'incorrect',
    }, '203.0.113.10');
    assert.equal(first.status, 401);

    const sameProxyIp = await post('/v1/auth/login', {
      email: 'proxy@example.org', password: 'incorrect',
    }, '203.0.113.10');
    assert.equal(sameProxyIp.status, 429);
    assert.equal(sameProxyIp.retryAfter, '60');

    const otherProxyIp = await post('/v1/auth/login', {
      email: 'proxy@example.org', password: 'incorrect',
    }, '203.0.113.11');
    assert.equal(otherProxyIp.status, 401);
  } finally {
    await app.dispose();
  }
});
