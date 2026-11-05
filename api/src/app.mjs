import http from 'node:http';
import { mkdirSync, chmodSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { randomBytes, randomUUID, createHash, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { DatabaseSync } from 'node:sqlite';

const scrypt = promisify(scryptCallback);
const sessionMs = 7 * 24 * 60 * 60 * 1000;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const failLimit = 8;
const attempts = new Map();
const services = Object.freeze([
  { id: 'prodayzer', name: 'Продайзер', type: 'external', url: 'https://prodayzer.ru',
    description: 'Создание и улучшение объявлений. Единый вход пока не подключён.' },
]);

function json(res, status, value) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(value));
}
function error(res, status, code, message) { json(res, status, { error: { code, message } }); }
function digest(value) { return createHash('sha256').update(value).digest('hex'); }
function cleanEmail(value) { return typeof value === 'string' ? value.trim().toLowerCase() : ''; }
function publicUser(row) { return { id: row.id, email: row.email, name: row.name }; }
async function passwordHash(password) {
  const salt = randomBytes(16).toString('hex');
  const hash = await scrypt(password, Buffer.from(salt, 'hex'), 64);
  return 'scrypt$' + salt + '$' + hash.toString('hex');
}
async function comparePassword(password, stored) {
  const parts = (stored || '').split('$');
  if (parts.length !== 3 || parts[0] !== 'scrypt') return false;
  const expected = Buffer.from(parts[2], 'hex');
  if (expected.length !== 64) return false;
  const actual = await scrypt(password, Buffer.from(parts[1], 'hex'), 64);
  return timingSafeEqual(expected, actual);
}
function throttle(key, limit = failLimit) {
  const now = Date.now();
  if (attempts.size > 5000) {
    for (const [item, value] of attempts) if (value.until < now) attempts.delete(item);
  }
  let entry = attempts.get(key);
  if (!entry || entry.until < now) entry = { count: 0, until: now + 60_000 };
  entry.count++;
  attempts.set(key, entry);
  return entry.count > limit ? Math.max(1, Math.ceil((entry.until - now) / 1000)) : 0;
}
async function bodyOf(req) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 16 * 1024) {
      const ex = new Error('Body too large');
      ex.status = 413;
      throw ex;
    }
    chunks.push(chunk);
  }
  try {
    const result = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!result || typeof result !== 'object' || Array.isArray(result)) throw new Error();
    return result;
  } catch { const ex = new Error('Invalid JSON'); ex.status = 400; throw ex; }
}
function setupDb(path) {
  const filename = resolve(path);
  mkdirSync(dirname(filename), { recursive: true, mode: 0o700 });
  const db = new DatabaseSync(filename);
  chmodSync(filename, 0o600);
  db.exec(`PRAGMA foreign_keys=ON;
    PRAGMA busy_timeout=5000;
    PRAGMA journal_mode=WAL;
    CREATE TABLE IF NOT EXISTS users(
      id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
      password_hash TEXT NOT NULL, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS sessions(
      token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      expires_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);`);
  // Backward compatible migration: preserve login sessions created by earlier API releases.
  const columns = new Set(db.prepare('PRAGMA table_info(sessions)').all().map(row => row.name));
  if (!columns.has('session_id')) {
    db.exec("ALTER TABLE sessions ADD COLUMN session_id TEXT NOT NULL DEFAULT ''");
  }
  if (!columns.has('created_at')) {
    db.exec('ALTER TABLE sessions ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0');
  }
  if (!columns.has('last_seen_at')) {
    db.exec('ALTER TABLE sessions ADD COLUMN last_seen_at INTEGER NOT NULL DEFAULT 0');
  }
  if (!columns.has('device_label')) {
    db.exec("ALTER TABLE sessions ADD COLUMN device_label TEXT NOT NULL DEFAULT 'Неизвестное устройство'");
  }
  const migrateSession = db.prepare('UPDATE sessions SET session_id=?, created_at=?, last_seen_at=? WHERE token_hash=?');
  const legacySessions = db.prepare("SELECT token_hash, expires_at FROM sessions WHERE session_id=''").all();
  for (const previous of legacySessions) {
    const timestamp = Math.max(0, Number(previous.expires_at) - sessionMs);
    migrateSession.run(randomUUID(), timestamp, timestamp, previous.token_hash);
  }
  db.exec('CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_session_id ON sessions(session_id)');
  return db;
}
export function createApp(options = {}) {
  const db = setupDb(options.dbPath || process.env.ENET_DB_PATH || './data/enet.sqlite');
  const allowed = new Set((options.allowedOrigins ?? process.env.ENET_ALLOWED_ORIGINS ?? '')
    .split(',').map(x => x.trim()).filter(Boolean));
  const userByEmail = db.prepare('SELECT * FROM users WHERE email=?');
  const insertUser = db.prepare('INSERT INTO users(id,email,name,password_hash,created_at) VALUES(?,?,?,?,?)');
  const insertSession = db.prepare('INSERT INTO sessions(token_hash,user_id,expires_at,session_id,created_at,last_seen_at,device_label) VALUES(?,?,?,?,?,?,?)');
  const listSessions = db.prepare('SELECT session_id, device_label, created_at, last_seen_at, expires_at, token_hash FROM sessions WHERE user_id=? AND expires_at>? ORDER BY last_seen_at DESC LIMIT 100');
  const removeSelectedSession = db.prepare('DELETE FROM sessions WHERE session_id=? AND user_id=? AND token_hash<>?');
  const updateSessionActivity = db.prepare('UPDATE sessions SET last_seen_at=? WHERE token_hash=?');
  const updateProfile = db.prepare('UPDATE users SET name=? WHERE id=?');
  const findSession = db.prepare(`SELECT users.id,users.email,users.name,sessions.last_seen_at FROM sessions
    JOIN users ON sessions.user_id=users.id
    WHERE sessions.token_hash=? AND sessions.expires_at>?`);
  const revokeSession = db.prepare('DELETE FROM sessions WHERE token_hash=?');
  const revokeOtherSessions = db.prepare('DELETE FROM sessions WHERE user_id=? AND token_hash<>?');
  const updatePassword = db.prepare('UPDATE users SET password_hash=? WHERE id=?');
  const userById = db.prepare('SELECT * FROM users WHERE id=?');
  const clearSessions = db.prepare('DELETE FROM sessions WHERE expires_at<=?');
  function auth(req) {
    const match = /^Bearer ([A-Za-z0-9_-]{32,256})$/.exec(req.headers.authorization || '');
    if (!match) return null;
    const tokenHash = digest(match[1]);
    const now = Date.now();
    const row = findSession.get(tokenHash, now);
    if (!row) return null;
    if (now - Number(row.last_seen_at) > 5 * 60_000) {
      updateSessionActivity.run(now, tokenHash);
    }
    return { user: publicUser(row), tokenHash };
  }
  function newSession(user, req) {
    const now = Date.now();
    clearSessions.run(now);
    const token = randomBytes(32).toString('base64url');
    const expiresAt = now + sessionMs;
    const label = String(req.headers['x-enet-client'] || req.headers['user-agent'] || 'Неизвестное устройство')
      .replace(/[\x00-\x1f\x7f]/g, '').slice(0, 90) || 'Неизвестное устройство';
    insertSession.run(digest(token), user.id, expiresAt, randomUUID(), now, now, label);
    return { token, expires_at: new Date(expiresAt).toISOString(), user: publicUser(user) };
  }
  const server = http.createServer(async (req, res) => {
    const requestId = randomUUID();
    res.setHeader('X-Request-Id', requestId);
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
    res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
    res.setHeader('Cache-Control', 'no-store');
    const origin = req.headers.origin;
    if (origin && allowed.has(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
      res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-eNet-Client');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    }
    if (req.method === 'OPTIONS') {
      res.writeHead(origin && allowed.has(origin) ? 204 : 403);
      return res.end();
    }
    const path = new URL(req.url || '/', 'http://localhost').pathname;
    try {
      if (path === '/health' && req.method === 'GET') {
        return json(res, 200, { status: 'ok', service: 'enet-api', version: '0.4.0' });
      }
      if (path === '/ready' && req.method === 'GET') {
        try {
          const result = db.prepare('SELECT 1 AS ok').get();
          if (result?.ok === 1) return json(res, 200, { status: 'ready', service: 'enet-api' });
        } catch {}
        return error(res, 503, 'not_ready', 'Хранилище API недоступно.');
      }
      if (path === '/v1/auth/register' && req.method === 'POST') {
        const retryAfter = throttle('register:' + (req.socket.remoteAddress || 'unknown'), 8);
        if (retryAfter) {
          res.setHeader('Retry-After', String(retryAfter));
          return error(res, 429, 'rate_limited', 'Слишком много попыток регистрации. Попробуйте позже.');
        }
        const b = await bodyOf(req);
        const email = cleanEmail(b.email);
        const name = typeof b.name === 'string' ? b.name.trim() : '';
        if (!emailPattern.test(email) || email.length > 254 || name.length < 2 || name.length > 80 ||
            typeof b.password !== 'string' || b.password.length < 12 || b.password.length > 128) {
          return error(res, 400, 'invalid_input', 'Нужно имя, корректный email и пароль от 12 до 128 символов.');
        }
        if (userByEmail.get(email)) return error(res, 409, 'already_exists', 'Этот email уже зарегистрирован.');
        const user = { id: randomUUID(), email, name };
        const hashed = await passwordHash(b.password);
        try { insertUser.run(user.id, user.email, user.name, hashed, new Date().toISOString()); }
        catch (e) {
          if (String(e.code || '').startsWith('SQLITE_CONSTRAINT')) return error(res, 409, 'already_exists', 'Этот email уже зарегистрирован.');
          throw e;
        }
        return json(res, 201, newSession(user, req));
      }
      if (path === '/v1/auth/login' && req.method === 'POST') {
        const ipRetry = throttle('login-ip:' + (req.socket.remoteAddress || 'unknown'), 30);
        if (ipRetry) {
          res.setHeader('Retry-After', String(ipRetry));
          return error(res, 429, 'rate_limited', 'Слишком много запросов с этого адреса. Попробуйте позже.');
        }
        const b = await bodyOf(req);
        const email = cleanEmail(b.email);
        if (!emailPattern.test(email) || typeof b.password !== 'string' || b.password.length > 128) {
          return error(res, 400, 'invalid_input', 'Укажите email и пароль.');
        }
        const emailRetry = throttle('login-email:' + digest(email), 8);
        if (emailRetry) {
          res.setHeader('Retry-After', String(emailRetry));
          return error(res, 429, 'rate_limited', 'Слишком много попыток входа для этого аккаунта. Попробуйте позже.');
        }
        const user = userByEmail.get(email);
        if (!user || !(await comparePassword(b.password, user.password_hash))) {
          return error(res, 401, 'invalid_credentials', 'Неверная почта или пароль.');
        }
        attempts.delete('login-email:' + digest(email));
        return json(res, 200, newSession(user, req));
      }
      if (path === '/v1/auth/reset-password' && req.method === 'POST') {
        return error(res, 501, 'not_configured', 'Восстановление пароля пока не настроено.');
      }
      if (path === '/v1/auth/me' && req.method === 'GET') {
        const session = auth(req);
        return session ? json(res, 200, { user: session.user }) : error(res, 401, 'unauthorized', 'Требуется авторизация.');
      }
      if (path === '/v1/auth/profile' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const payload = await bodyOf(req);
        const name = typeof payload.name === 'string' ? payload.name.trim() : '';
        if (name.length < 2 || name.length > 80 || /[\x00-\x1f\x7f]/.test(name)) {
          return error(res, 400, 'invalid_name', 'Имя должно содержать от 2 до 80 символов.');
        }
        updateProfile.run(name, session.user.id);
        return json(res, 200, { user: publicUser(userById.get(session.user.id)) });
      }
      if (path === '/v1/auth/sessions' && req.method === 'GET') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const entries = listSessions.all(session.user.id, Date.now()).map(item => ({
          id: item.session_id,
          device: item.device_label,
          created_at: new Date(Number(item.created_at)).toISOString(),
          last_seen_at: new Date(Number(item.last_seen_at)).toISOString(),
          expires_at: new Date(Number(item.expires_at)).toISOString(),
          current: item.token_hash === session.tokenHash,
        }));
        return json(res, 200, { sessions: entries });
      }
      if (path === '/v1/auth/sessions/revoke' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const payload = await bodyOf(req);
        if (typeof payload.session_id !== 'string' ||
            !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(payload.session_id)) {
          return error(res, 400, 'invalid_input', 'Неизвестный идентификатор сеанса.');
        }
        const result = removeSelectedSession.run(payload.session_id, session.user.id, session.tokenHash);
        if (!result.changes) {
          return error(res, 404, 'not_found', 'Сеанс не найден или является текущим.');
        }
        return json(res, 200, { ok: true });
      }
      if (path === '/v1/auth/change-password' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const retryAfter = throttle('password:' + (req.socket.remoteAddress || 'unknown'), 8);
        if (retryAfter) {
          res.setHeader('Retry-After', String(retryAfter));
          return error(res, 429, 'rate_limited', 'Слишком много попыток смены пароля. Попробуйте позже.');
        }
        const body = await bodyOf(req);
        if (typeof body.current_password !== 'string' ||
            typeof body.new_password !== 'string' ||
            body.new_password.length < 12 || body.new_password.length > 128 ||
            body.current_password.length > 128 ||
            body.current_password === body.new_password) {
          return error(res, 400, 'invalid_input', 'Нужен текущий и новый пароль (от 12 до 128 символов).');
        }
        const account = userById.get(session.user.id);
        if (!account || !(await comparePassword(body.current_password, account.password_hash))) {
          return error(res, 403, 'invalid_password', 'Неверный текущий пароль.');
        }
        const hash = await passwordHash(body.new_password);
        db.exec('BEGIN IMMEDIATE');
        try {
          updatePassword.run(hash, account.id);
          revokeOtherSessions.run(account.id, session.tokenHash);
          db.exec('COMMIT');
        } catch (e) {
          db.exec('ROLLBACK');
          throw e;
        }
        return json(res, 200, { ok: true, other_sessions_revoked: true });
      }
      if (path === '/v1/auth/logout-others' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const result = revokeOtherSessions.run(session.user.id, session.tokenHash);
        return json(res, 200, { ok: true, revoked: Number(result.changes) });
      }
      if (path === '/v1/auth/logout' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        revokeSession.run(session.tokenHash);
        return json(res, 200, { ok: true });
      }
      if (path === '/v1/services' && req.method === 'GET') {
        if (!auth(req)) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        return json(res, 200, { services });
      }
      return error(res, 404, 'not_found', 'Маршрут не найден.');
    } catch (e) {
      if (e.status === 400 || e.status === 413) return error(res, e.status, 'bad_request', e.message);
      console.error(JSON.stringify({
        level: 'error', request_id: requestId, path,
        error: e?.name || 'Error',
      }));
      return error(res, 500, 'internal_error', 'Ошибка сервера.');
    }
  });
  server.headersTimeout = 10_000;
  server.requestTimeout = 20_000;
  server.keepAliveTimeout = 5_000;
  server.maxHeadersCount = 100;
  return {
    server,
    close: async () => {
      await new Promise((done, fail) => server.close(err => err ? fail(err) : done()));
      db.close();
    },
  };
}
