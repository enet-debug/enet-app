import http from 'node:http';
import { isIP } from 'node:net';
import { mkdirSync, chmodSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { randomBytes, randomUUID, createHash, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { DatabaseSync } from 'node:sqlite';

const scrypt = promisify(scryptCallback);
const sessionMs = 7 * 24 * 60 * 60 * 1000;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const failLimit = 8;
const registerLimit = 5;
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
    CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);
    CREATE TABLE IF NOT EXISTS user_preferences (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      favorite_services TEXT NOT NULL DEFAULT '[]',
      updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS auth_rate_limits(
      bucket TEXT PRIMARY KEY,
      attempts INTEGER NOT NULL,
      window_started_at INTEGER NOT NULL,
      blocked_until INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_expiry
      ON auth_rate_limits(blocked_until, window_started_at);
    CREATE TABLE IF NOT EXISTS notifications(
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      type TEXT NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at TEXT NOT NULL,
      read_at TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_notifications_user_created
      ON notifications(user_id, created_at DESC);
    CREATE TABLE IF NOT EXISTS tasks(
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0,1)),
      due_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_tasks_user_status_due
      ON tasks(user_id, completed, due_at, created_at DESC);`);
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
  const trustProxy = options.trustProxy ?? process.env.ENET_TRUST_PROXY === 'true';
  const rateWindowMs = options.authRateLimitWindowMs ?? 60_000;
  const authLimit = options.authRateLimitMax ?? failLimit;
  const signupLimit = options.registerRateLimitMax ?? registerLimit;
  const rateLimitRow = db.prepare(
    'SELECT attempts,window_started_at,blocked_until FROM auth_rate_limits WHERE bucket=?');
  const saveRateLimit = db.prepare(
    'INSERT INTO auth_rate_limits(bucket,attempts,window_started_at,blocked_until) VALUES(?,?,?,?) ' +
    'ON CONFLICT(bucket) DO UPDATE SET attempts=excluded.attempts, ' +
    'window_started_at=excluded.window_started_at, blocked_until=excluded.blocked_until');
  const clearRateLimit = db.prepare('DELETE FROM auth_rate_limits WHERE bucket=?');
  const cleanupRateLimits = db.prepare(
    'DELETE FROM auth_rate_limits WHERE window_started_at<? AND blocked_until<?');
  let lastRateLimitCleanup = 0;

  function clientIp(req) {
    if (trustProxy) {
      const forwarded = req.headers['x-real-ip'];
      if (typeof forwarded === 'string' && isIP(forwarded.trim())) {
        return forwarded.trim();
      }
    }
    return req.socket.remoteAddress || 'unknown';
  }
  function rateLimitWait(bucket, now = Date.now()) {
    if (now - lastRateLimitCleanup > rateWindowMs * 5) {
      cleanupRateLimits.run(now - rateWindowMs * 4, now);
      lastRateLimitCleanup = now;
    }
    const row = rateLimitRow.get(bucket);
    if (!row) return 0;
    if (Number(row.blocked_until) > now) return Number(row.blocked_until) - now;
    if (now - Number(row.window_started_at) >= rateWindowMs) clearRateLimit.run(bucket);
    return 0;
  }
  function recordAttempt(bucket, limit, now = Date.now(), blockAtLimit = true) {
    const currentWait = rateLimitWait(bucket, now);
    if (currentWait > 0) return currentWait;
    const previous = rateLimitRow.get(bucket);
    const inWindow = previous && now - Number(previous.window_started_at) < rateWindowMs;
    const count = inWindow ? Number(previous.attempts) + 1 : 1;
    const started = inWindow ? Number(previous.window_started_at) : now;
    const blockedUntil = count >= limit && blockAtLimit ? now + rateWindowMs : 
      count > limit ? now + rateWindowMs : 0;
    saveRateLimit.run(bucket, count, started, blockedUntil);
    return blockedUntil > now ? blockedUntil - now : 0;
  }
  function denyRateLimited(res, wait) {
    res.setHeader('Retry-After', String(Math.max(1, Math.ceil(wait / 1000))));
    return error(res, 429, 'rate_limited', 'Слишком много попыток. Попробуйте позже.');
  }

  const userByEmail = db.prepare('SELECT * FROM users WHERE email=?');
  const insertUser = db.prepare('INSERT INTO users(id,email,name,password_hash,created_at) VALUES(?,?,?,?,?)');
  const insertSession = db.prepare('INSERT INTO sessions(token_hash,user_id,expires_at,session_id,created_at,last_seen_at,device_label) VALUES(?,?,?,?,?,?,?)');
  const listSessions = db.prepare('SELECT session_id, device_label, created_at, last_seen_at, expires_at, token_hash FROM sessions WHERE user_id=? AND expires_at>? ORDER BY last_seen_at DESC LIMIT 100');
  const removeSelectedSession = db.prepare('DELETE FROM sessions WHERE session_id=? AND user_id=? AND token_hash<>?');
  const updateSessionActivity = db.prepare('UPDATE sessions SET last_seen_at=? WHERE token_hash=?');
  const updateProfile = db.prepare('UPDATE users SET name=? WHERE id=?');
  const getPreferences = db.prepare('SELECT favorite_services, updated_at FROM user_preferences WHERE user_id=?');
  const savePreferences = db.prepare(`INSERT INTO user_preferences(user_id,favorite_services,updated_at)
    VALUES(?,?,?) ON CONFLICT(user_id) DO UPDATE SET
    favorite_services=excluded.favorite_services, updated_at=excluded.updated_at`);
  const findSession = db.prepare(`SELECT users.id,users.email,users.name,sessions.last_seen_at FROM sessions
    JOIN users ON sessions.user_id=users.id
    WHERE sessions.token_hash=? AND sessions.expires_at>?`);
  const revokeSession = db.prepare('DELETE FROM sessions WHERE token_hash=?');
  const revokeOtherSessions = db.prepare('DELETE FROM sessions WHERE user_id=? AND token_hash<>?');
  const updatePassword = db.prepare('UPDATE users SET password_hash=? WHERE id=?');
  const userById = db.prepare('SELECT * FROM users WHERE id=?');
  const clearSessions = db.prepare('DELETE FROM sessions WHERE expires_at<=?');
  const insertNotification = db.prepare(
    'INSERT INTO notifications(id,user_id,type,title,body,created_at,read_at) VALUES(?,?,?,?,?,?,NULL)');
  const listNotifications = db.prepare(
    'SELECT id,type,title,body,created_at,read_at FROM notifications ' +
    'WHERE user_id=? ORDER BY created_at DESC, rowid DESC LIMIT 50');
  const unreadNotifications = db.prepare(
    'SELECT COUNT(*) AS count FROM notifications WHERE user_id=? AND read_at IS NULL');
  const ownNotification = db.prepare('SELECT id FROM notifications WHERE user_id=? AND id=?');
  const markNotification = db.prepare(
    'UPDATE notifications SET read_at=COALESCE(read_at,?) WHERE user_id=? AND id=?');
  const markAllNotifications = db.prepare(
    'UPDATE notifications SET read_at=? WHERE user_id=? AND read_at IS NULL');
  const listTasks = db.prepare(
    'SELECT id,title,description,completed,due_at,created_at,updated_at FROM tasks ' +
    'WHERE user_id=? ORDER BY completed ASC, ' +
    'CASE WHEN due_at IS NULL THEN 1 ELSE 0 END, due_at ASC, created_at DESC');
  const countTasks = db.prepare('SELECT COUNT(*) AS count FROM tasks WHERE user_id=?');
  const getTask = db.prepare(
    'SELECT id,title,description,completed,due_at,created_at,updated_at FROM tasks WHERE id=? AND user_id=?');
  const insertTask = db.prepare(
    'INSERT INTO tasks(id,user_id,title,description,completed,due_at,created_at,updated_at) VALUES(?,?,?,?,0,?,?,?)');
  const updateTask = db.prepare(
    'UPDATE tasks SET title=?,description=?,due_at=?,updated_at=? WHERE id=? AND user_id=?');
  const setTaskCompleted = db.prepare(
    'UPDATE tasks SET completed=?,updated_at=? WHERE id=? AND user_id=?');
  const deleteTask = db.prepare('DELETE FROM tasks WHERE id=? AND user_id=?');
  function taskDto(item) {
    return {
      id: item.id,
      title: item.title,
      description: item.description,
      completed: Boolean(item.completed),
      due_at: item.due_at,
      created_at: item.created_at,
      updated_at: item.updated_at,
    };
  }
  // Keep unread totals consistent with the finite history returned to clients.
  // This prevents repeated logins from growing the SQLite database without a limit.
  const maxNotificationHistory = Number.isInteger(options.maxNotificationHistory) &&
      options.maxNotificationHistory > 0 && options.maxNotificationHistory <= 1000
    ? options.maxNotificationHistory : 200;
  const pruneNotifications = db.prepare(
    'DELETE FROM notifications WHERE user_id=? AND id NOT IN (' +
    'SELECT id FROM notifications WHERE user_id=? ' +
    'ORDER BY created_at DESC, rowid DESC LIMIT ?)');
  function recordNotification(userId, type, title, body) {
    insertNotification.run(
      randomUUID(), userId, type, title, body, new Date().toISOString(),
    );
    pruneNotifications.run(userId, userId, maxNotificationHistory);
  }
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
  function newSession(user, req, firstLogin = false) {
    const now = Date.now();
    clearSessions.run(now);
    const token = randomBytes(32).toString('base64url');
    const expiresAt = now + sessionMs;
    const label = String(req.headers['x-enet-client'] || req.headers['user-agent'] || 'Неизвестное устройство')
      .replace(/[\x00-\x1f\x7f]/g, '').slice(0, 90) || 'Неизвестное устройство';
    insertSession.run(digest(token), user.id, expiresAt, randomUUID(), now, now, label);
    recordNotification(
      user.id, firstLogin ? 'welcome' : 'security',
      firstLogin ? 'Добро пожаловать в eNet' : 'Новый вход в eNet ID',
      firstLogin
        ? 'Аккаунт создан. Вы можете управлять сервисами и безопасностью в одном приложении.'
        : 'Выполнен вход с устройства: ' + label,
    );
    return { token, expires_at: new Date(expiresAt).toISOString(), user: publicUser(user) };
  }
  const server = http.createServer(async (req, res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-Request-Id', randomUUID());
    res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
    res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
    res.setHeader('Cache-Control', 'no-store');
    const origin = req.headers.origin;
    if (origin && allowed.has(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
      res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-eNet-Client');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      res.setHeader('Access-Control-Expose-Headers', 'X-Request-Id, Retry-After');
    }
    if (req.method === 'OPTIONS') {
      res.writeHead(origin && allowed.has(origin) ? 204 : 403);
      return res.end();
    }
    const path = new URL(req.url || '/', 'http://localhost').pathname;
    try {
      if (path === '/health' && req.method === 'GET') {
        return json(res, 200, { status: 'ok', service: 'enet-api', version: '0.5.0' });
      }
      if (path === '/ready' && req.method === 'GET') {
        try {
          db.prepare('SELECT 1').get();
          return json(res, 200, { status: 'ready', storage: 'sqlite' });
        } catch {
          return error(res, 503, 'unavailable', 'База данных недоступна.');
        }
      }
      if (path === '/v1/meta' && req.method === 'GET') {
        return json(res, 200, {
          api: 'enet', version: '0.5.0', auth: 'bearer',
          capabilities: ['accounts', 'sessions', 'services', 'favorites', 'notifications', 'tasks'],
          services: { catalog: true, single_sign_on: false },
        });
      }
      if (path === '/v1/auth/register' && req.method === 'POST') {
        const ipBucket = 'register:' + digest(clientIp(req));
        const registerWait = recordAttempt(ipBucket, signupLimit, Date.now(), false);
        if (registerWait > 0) return denyRateLimited(res, registerWait);
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
        db.exec('BEGIN IMMEDIATE');
        try {
          insertUser.run(user.id, user.email, user.name, hashed, new Date().toISOString());
          const session = newSession(user, req, true);
          db.exec('COMMIT');
          return json(res, 201, session);
        } catch (e) {
          db.exec('ROLLBACK');
          if (String(e.code || '').startsWith('SQLITE_CONSTRAINT')) {
            return error(res, 409, 'already_exists', 'Этот email уже зарегистрирован.');
          }
          throw e;
        }
      }
      if (path === '/v1/auth/login' && req.method === 'POST') {
        const b = await bodyOf(req);
        const email = cleanEmail(b.email);
        if (!emailPattern.test(email) || typeof b.password !== 'string' ||
            b.password.length === 0 || b.password.length > 128) {
          return error(res, 400, 'invalid_input', 'Укажите email и пароль.');
        }
        const ipBucket = 'login-ip:' + digest(clientIp(req));
        const accountBucket = 'login-account:' + digest(email);
        const wait = Math.max(rateLimitWait(ipBucket), rateLimitWait(accountBucket));
        if (wait > 0) return denyRateLimited(res, wait);
        const user = userByEmail.get(email);
        const valid = user
          ? await comparePassword(b.password, user.password_hash)
          : (await scrypt(b.password, Buffer.alloc(16), 64), false);
        if (!valid) {
          const ipWait = recordAttempt(ipBucket, 30, Date.now(), false);
          const accountWait = recordAttempt(accountBucket, authLimit);
          const retry = Math.max(ipWait, accountWait);
          if (retry > 0) return denyRateLimited(res, retry);
          return error(res, 401, 'invalid_credentials', 'Неверная почта или пароль.');
        }
        clearRateLimit.run(accountBucket);
        db.exec('BEGIN IMMEDIATE');
        try {
          const session = newSession(user, req);
          db.exec('COMMIT');
          return json(res, 200, session);
        } catch (e) {
          db.exec('ROLLBACK');
          throw e;
        }
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
        const ipBucket = 'password-ip:' + digest(clientIp(req));
        const accountBucket = 'password-account:' + digest(session.user.id);
        const wait = Math.max(rateLimitWait(ipBucket), rateLimitWait(accountBucket));
        if (wait > 0) return denyRateLimited(res, wait);
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
          const ipWait = recordAttempt(ipBucket, 30, Date.now(), false);
          const accountWait = recordAttempt(accountBucket, authLimit);
          const retry = Math.max(ipWait, accountWait);
          if (retry > 0) return denyRateLimited(res, retry);
          return error(res, 403, 'invalid_password', 'Неверный текущий пароль.');
        }
        clearRateLimit.run(accountBucket);
        const hash = await passwordHash(body.new_password);
        db.exec('BEGIN IMMEDIATE');
        try {
          updatePassword.run(hash, account.id);
          revokeOtherSessions.run(account.id, session.tokenHash);
          recordNotification(account.id, 'security', 'Пароль изменён',
            'Пароль eNet ID изменён. Остальные активные сеансы были завершены.');
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
      if (path === '/v1/notifications' && req.method === 'GET') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        return json(res, 200, {
          notifications: listNotifications.all(session.user.id),
          unread_count: Number(unreadNotifications.get(session.user.id).count),
        });
      }
      if (path === '/v1/notifications/read' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const body = await bodyOf(req);
        if (typeof body.id !== 'string' ||
            !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.id)) {
          return error(res, 400, 'invalid_input', 'Некорректный идентификатор уведомления.');
        }
        if (!ownNotification.get(session.user.id, body.id)) {
          return error(res, 404, 'not_found', 'Уведомление не найдено.');
        }
        markNotification.run(new Date().toISOString(), session.user.id, body.id);
        return json(res, 200, { ok: true });
      }
      if (path === '/v1/notifications/read-all' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const result = markAllNotifications.run(new Date().toISOString(), session.user.id);
        return json(res, 200, { ok: true, updated: Number(result.changes) });
      }
      if (path === '/v1/me/preferences' && req.method === 'GET') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const row = getPreferences.get(session.user.id);
        return json(res, 200, {
          favorite_services: row ? JSON.parse(row.favorite_services) : [],
          updated_at: row?.updated_at || null,
        });
      }
      if (path === '/v1/me/preferences' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const payload = await bodyOf(req);
        const favorites = payload.favorite_services;
        const validServices = new Set(services.map(service => service.id));
        if (!Array.isArray(favorites) || favorites.length > 20 ||
            favorites.some(id => typeof id !== 'string' || !validServices.has(id)) ||
            new Set(favorites).size !== favorites.length) {
          return error(res, 400, 'invalid_preferences',
            'Избранное должно содержать уникальные ID существующих сервисов (не более 20).');
        }
        const updated = new Date().toISOString();
        savePreferences.run(session.user.id, JSON.stringify(favorites), updated);
        return json(res, 200, { favorite_services: favorites, updated_at: updated });
      }
      if (path === '/v1/tasks' && req.method === 'GET') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const entries = listTasks.all(session.user.id).map(taskDto);
        const completed = entries.filter(item => item.completed).length;
        return json(res, 200, {
          tasks: entries,
          summary: { total: entries.length, completed, open: entries.length - completed },
        });
      }
      if (path === '/v1/tasks' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const body = await bodyOf(req);
        const title = typeof body.title === 'string' ? body.title.trim() : '';
        const description = typeof body.description === 'string' ? body.description.trim() : '';
        const dueAt = body.due_at == null || body.due_at === '' ? null : body.due_at;
        if (title.length < 1 || title.length > 120 ||
            /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(title) ||
            description.length > 1000 ||
            /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(description) ||
            (dueAt !== null && (typeof dueAt !== 'string' || dueAt.length > 40 ||
              Number.isNaN(Date.parse(dueAt))))) {
          return error(res, 400, 'invalid_task', 'Проверьте название, описание и срок задачи.');
        }
        if (Number(countTasks.get(session.user.id).count) >= 500) {
          return error(res, 409, 'task_limit', 'Достигнут лимит в 500 задач для аккаунта.');
        }
        const id = randomUUID();
        const now = new Date().toISOString();
        insertTask.run(id, session.user.id, title, description, dueAt, now, now);
        return json(res, 201, { task: taskDto(getTask.get(id, session.user.id)) });
      }
      if (path === '/v1/tasks/update' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const body = await bodyOf(req);
        const id = body.id;
        const title = typeof body.title === 'string' ? body.title.trim() : '';
        const description = typeof body.description === 'string' ? body.description.trim() : '';
        const dueAt = body.due_at == null || body.due_at === '' ? null : body.due_at;
        if (typeof id !== 'string' ||
            !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id) ||
            title.length < 1 || title.length > 120 ||
            /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(title) ||
            description.length > 1000 ||
            /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(description) ||
            (dueAt !== null && (typeof dueAt !== 'string' || dueAt.length > 40 ||
              Number.isNaN(Date.parse(dueAt))))) {
          return error(res, 400, 'invalid_task', 'Некорректные данные задачи.');
        }
        const now = new Date().toISOString();
        const result = updateTask.run(title, description, dueAt, now, id, session.user.id);
        if (!result.changes) return error(res, 404, 'not_found', 'Задача не найдена.');
        return json(res, 200, { task: taskDto(getTask.get(id, session.user.id)) });
      }
      if (path === '/v1/tasks/toggle' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const body = await bodyOf(req);
        if (typeof body.id !== 'string' ||
            !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.id) ||
            typeof body.completed !== 'boolean') {
          return error(res, 400, 'invalid_task', 'Некорректный статус задачи.');
        }
        const result = setTaskCompleted.run(
          Number(body.completed), new Date().toISOString(), body.id, session.user.id,
        );
        if (!result.changes) return error(res, 404, 'not_found', 'Задача не найдена.');
        return json(res, 200, { task: taskDto(getTask.get(body.id, session.user.id)) });
      }
      if (path === '/v1/tasks/delete' && req.method === 'POST') {
        const session = auth(req);
        if (!session) return error(res, 401, 'unauthorized', 'Требуется авторизация.');
        const body = await bodyOf(req);
        if (typeof body.id !== 'string' ||
            !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.id)) {
          return error(res, 400, 'invalid_task', 'Некорректный идентификатор задачи.');
        }
        const result = deleteTask.run(body.id, session.user.id);
        if (!result.changes) return error(res, 404, 'not_found', 'Задача не найдена.');
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
        level: 'error',
        request_id: res.getHeader('X-Request-Id'),
        path,
        error: e?.name || 'Error',
      }));
      return error(res, 500, 'internal_error', 'Ошибка сервера.');
    }
  });
  server.requestTimeout = 20_000;
  server.headersTimeout = 10_000;
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
