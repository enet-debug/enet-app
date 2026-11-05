import http from 'node:http';
import { mkdirSync, chmodSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { randomBytes, randomUUID, createHash, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { DatabaseSync } from 'node:sqlite';

const scrypt = promisify(scryptCallback);
const sessionMs = 7 * 24 * 60 * 60 * 1000;
const emailPattern = /^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/;
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
function throttle(ip) {
  const now = Date.now();
  if (attempts.size > 5000) {
    for (const [key, value] of attempts) if (value.until < now) attempts.delete(key);
  }
  let entry = attempts.get(ip);
  if (!entry || entry.until < now) entry = { count: 0, until: now + 60_000 };
  entry.count++;
  attempts.set(ip, entry);
  return entry.count > failLimit;
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
  return db;
}
export function createApp(options = {}) {
  const db = setupDb(options.dbPath || process.env.ENET_DB_PATH || './data/enet.sqlite');
  const allowed = new Set((options.allowedOrigins ?? process.env.ENET_ALLOWED_ORIGINS ?? '')
    .split(',').map(x => x.trim()).filter(Boolean));
  const userByEmail = db.prepare('SELECT * FROM users WHERE email=?');
  const insertUser = db.prepare('INSERT INTO users(id,email,name,password_hash,created_at) VALUES(?,?,?,?,?)');
  const insertSession = db.prepare('INSERT INTO sessions(token_hash,user_id,expires_at) VALUES(?,?,?)');
  const findSession = db.prepare(`SELECT users.id,users.email,users.name FROM sessions
    JOIN users ON sessions.user_id=users.id
    WHERE sessions.token_hash=? AND sessions.expires_at>?`);
  const revokeSession = db.prepare('DELETE FROM sessions WHERE token_hash=?');
  const clearSessions = db.prepare('DELETE FROM sessions WHERE expires_at<=?');
  function auth(req) {
    const match = /^Bearer ([A-Za-z0-9_-]{32,256})$/.exec(req.headers.authorization || '');
    if (!match) return null;
    const row = findSession.get(digest(match[1]), Date.now());
    return row ? { user: publicUser(row), tokenHash: digest(match[1]) } : null;
  }
  function newSession(user) {
    clearSessions.run(Date.now());
    const token = randomBytes(32).toString('base64url');
    const expiresAt = Date.now() + sessionMs;
    insertSession.run(digest(token), user.id, expiresAt);
    return { token, expires_at: new Date(expiresAt).toISOString(), user: publicUser(user) };
  }
  const server = http.createServer(async (req, res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('X-Frame-Options', 'DENY');
    const origin = req.headers.origin;
    if (origin && allowed.has(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
      res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    }
    if (req.method === 'OPTIONS') {
      res.writeHead(origin && allowed.has(origin) ? 204 : 403);
      return res.end();
    }
    const path = new URL(req.url || '/', 'http://localhost').pathname;
    try {
      if (path === '/health' && req.method === 'GET') {
        return json(res, 200, { status: 'ok', service: 'enet-api', version: '0.1.0' });
      }
      if (path === '/v1/auth/register' && req.method === 'POST') {
        if (throttle('register:' + req.socket.remoteAddress)) return error(res, 429, 'rate_limited', 'Попробуйте через минуту.');
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
        return json(res, 201, newSession(user));
      }
      if (path === '/v1/auth/login' && req.method === 'POST') {
        if (throttle('login:' + req.socket.remoteAddress)) return error(res, 429, 'rate_limited', 'Попробуйте через минуту.');
        const b = await bodyOf(req);
        const email = cleanEmail(b.email);
        if (!emailPattern.test(email) || typeof b.password !== 'string' || b.password.length > 128) {
          return error(res, 400, 'invalid_input', 'Укажите email и пароль.');
        }
        const user = userByEmail.get(email);
        if (!user || !(await comparePassword(b.password, user.password_hash))) {
          return error(res, 401, 'invalid_credentials', 'Неверная почта или пароль.');
        }
        return json(res, 200, newSession(user));
      }
      if (path === '/v1/auth/reset-password' && req.method === 'POST') {
        return error(res, 501, 'not_configured', 'Восстановление пароля пока не настроено.');
      }
      if (path === '/v1/auth/me' && req.method === 'GET') {
        const session = auth(req);
        return session ? json(res, 200, { user: session.user }) : error(res, 401, 'unauthorized', 'Требуется авторизация.');
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
      console.error('API request error:', e);
      return error(res, 500, 'internal_error', 'Ошибка сервера.');
    }
  });
  return {
    server,
    close: async () => {
      await new Promise((done, fail) => server.close(err => err ? fail(err) : done()));
      db.close();
    },
  };
}
