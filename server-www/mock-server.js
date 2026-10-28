const http = require('node:http');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf('--' + name);
  return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
}

const PORT = Number(arg('port', process.env.PORT || 8080));
const ORIGIN = arg('origin', '*');
const ACCESS_TTL = Number(arg('ttl', 900));
const REFRESH_TTL = 60 * 60 * 24 * 7;
const SESSION_TTL = Number(arg('session', 0));
const SECRET = process.env.API_SECRET || 'habit-tracker-training-api-secret';
const SITE_DIR = path.resolve(arg('site', path.join(__dirname, '..', 'build', 'web')));
const SPA = fs.existsSync(path.join(SITE_DIR, 'index.html'));

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.map': 'application/json',
  '.txt': 'text/plain; charset=utf-8',
  '.bin': 'application/octet-stream',
};

function serveStatic(req, res, pathname) {
  const clean = decodeURIComponent(pathname);
  const target = path.join(SITE_DIR, path.normalize(clean).replace(/^([/\\])+/, ''));
  const inside = target.startsWith(SITE_DIR);

  if (inside && fs.existsSync(target) && fs.statSync(target).isFile()) {
    const ext = path.extname(target).toLowerCase();
    const body = fs.readFileSync(target);
    res.writeHead(200, {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Content-Length': body.length,
      'Cache-Control': ext === '.html' ? 'no-cache' : 'public, max-age=600',
    });
    res.end(req.method === 'HEAD' ? undefined : body);
    return;
  }

  if (path.extname(clean) === '') {
    const index = path.join(SITE_DIR, 'index.html');
    if (fs.existsSync(index)) {
      const body = fs.readFileSync(index);
      res.writeHead(200, {
        'Content-Type': 'text/html; charset=utf-8',
        'Content-Length': body.length,
        'Cache-Control': 'no-cache',
      });
      res.end(body);
      return;
    }
  }

  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('Не найдено: ' + clean);
}

// ---------------------------------------------------------------- хранилище

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const DB_FILE = path.join(DATA_DIR, 'habit-tracker.db');

function openStore() {
  let Database = null;
  try {
    const modulePath = path.join(__dirname, 'node_modules', 'better-sqlite3');
    if (!fs.existsSync(modulePath)) throw new Error('модуль не установлен');
    Database = require(modulePath);
  } catch (error) {
    console.log('SQLite недоступен (' + error.message + ') — данные в памяти');
    return null;
  }

  try {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    const database = new Database(DB_FILE);
    database.pragma('journal_mode = WAL');
    database.exec(
      'CREATE TABLE IF NOT EXISTS collections (' +
        'name TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at TEXT NOT NULL)',
    );
    return database;
  } catch (error) {
    console.log('SQLite не открылся (' + error.message + ') — данные в памяти');
    return null;
  }
}

const store = openStore();

function loadSaved() {
  if (!store) return null;
  const rows = store.prepare('SELECT name, payload FROM collections').all();
  if (!rows.length) return null;
  const data = {};
  for (const row of rows) data[row.name] = JSON.parse(row.payload);
  return data;
}

function persist(name, value) {
  if (!store) return;
  store
    .prepare(
      'INSERT INTO collections (name, payload, updated_at) VALUES (?, ?, ?) ' +
        'ON CONFLICT(name) DO UPDATE SET payload = excluded.payload, ' +
        'updated_at = excluded.updated_at',
    )
    .run(name, JSON.stringify(value), nowIso());
}

function persistAll() {
  for (const key of Object.keys(db)) {
    if (Array.isArray(db[key])) persist(key, db[key]);
  }
}

// ---------------------------------------------------------------- утилиты

function nowIso() {
  return new Date().toISOString();
}

function str(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function int(value, fallback = null) {
  if (value === null || value === undefined || value === '') return fallback;
  const n = Number(value);
  return Number.isInteger(n) ? n : fallback;
}

function bool(value, fallback = false) {
  return typeof value === 'boolean' ? value : fallback;
}

function isEmail(value) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value);
}

function isDate(value) {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value));
}

function activeRows(collection) {
  return db[collection].filter((row) => !row.deletedAt);
}

function findRow(collection, id, includeDeleted = false) {
  const row = db[collection].find((item) => item.id === id);
  if (!row) return null;
  if (row.deletedAt && !includeDeleted) return null;
  return row;
}

function lower(value) {
  return String(value ?? '').toLowerCase();
}

function uniqueViolation(rows, field, value, excludeId) {
  return rows.some(
    (row) =>
      row.id !== excludeId &&
      !row.deletedAt &&
      lower(row[field]) === lower(value),
  );
}
// ---------------------------------------------------------------- ответы

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': ORIGIN,
    'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Max-Age': '86400',
  };
}

function send(res, status, body, extraHeaders = {}) {
  const headers = { ...corsHeaders(), ...extraHeaders };
  if (body === undefined) {
    res.writeHead(status, headers);
    res.end();
    return;
  }
  const text = JSON.stringify(body);
  headers['Content-Type'] = 'application/json; charset=utf-8';
  headers['Content-Length'] = Buffer.byteLength(text);
  res.writeHead(status, headers);
  res.end(text);
}

function fail(res, status, message) {
  send(res, status, { message });
}

function deny(res, user, action) {
  const label = {
    reader: 'читатель',
    librarian: 'редактор',
    admin: 'администратор',
  }[user?.role] ?? 'эта роль';
  fail(res, 403, `Роль «${label}» не может выполнить действие: ${action}`);
}

function canPurge(user) {
  return user?.role === 'admin';
}

function isAdmin(req) {
  return currentUser(req)?.role === 'admin';
}

function statistics() {
  const minutes = activeRows('check_ins').reduce(
    (sum, row) => sum + (Number(row.minutes) || 0),
    0,
  );
  const habits = activeRows('habits');
  const checkIns = activeRows('check_ins');
  return {
    generatedAt: nowIso(),
    collections: {
      categories: activeRows('categories').length,
      tags: activeRows('tags').length,
      profiles: activeRows('profiles').length,
      habits: habits.length,
      check_ins: checkIns.length,
      coupons: activeRows('coupons').length,
      users: activeRows('users').length,
    },
    totalMinutes: minutes,
    completed: checkIns.filter((c) => c.completed).length,
    completionRate: checkIns.length
      ? Math.round((checkIns.filter((c) => c.completed).length * 100) / checkIns.length)
      : 0,
    topHabits: [...habits]
      .map((habit) => ({
        habitId: habit.id,
        name: habit.name,
        checkIns: checkIns.filter((c) => c.habitId === habit.id).length,
      }))
      .sort((a, b) => b.checkIns - a.checkIns || a.name.localeCompare(b.name))
      .slice(0, 5),
    perProfile: activeRows('profiles').map((profile) => ({
      profileId: profile.id,
      name: profile.name,
      habits: habits.filter((h) => h.profileId === profile.id).length,
      checkIns: checkIns.filter((c) => c.profileId === profile.id).length,
      minutes: checkIns
        .filter((c) => c.profileId === profile.id)
        .reduce((sum, c) => sum + (Number(c.minutes) || 0), 0),
    })),
    perCategory: activeRows('categories').map((category) => ({
      categoryId: category.id,
      name: category.name,
      habits: habits.filter((h) => h.categoryId === category.id).length,
    })),
  };
}

function validationFail(res, errors) {
  send(res, 422, { message: 'Ошибка валидации', errors });
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 1_000_000) {
        reject(new Error('Слишком большое тело запроса'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!raw.trim()) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new Error('Некорректный JSON'));
      }
    });
    req.on('error', reject);
  });
}
// ---------------------------------------------------------------- список

function applySearch(rows, fields, search) {
  const needle = lower(search);
  if (!needle) return rows;
  return rows.filter((row) =>
    fields.some((field) => lower(row[field]).includes(needle)),
  );
}

function applySort(rows, sortParam, allowed) {
  const [rawField, rawDirection] = String(sortParam || '').split(',');
  const field = allowed[rawField] ? rawField : 'id';
  const direction = rawDirection === 'desc' ? -1 : 1;

  return [...rows].sort((a, b) => {
    const left = a[field];
    const right = b[field];
    if (typeof left === 'number' && typeof right === 'number') {
      return (left - right) * direction;
    }
    return String(left ?? '').localeCompare(String(right ?? ''), 'ru') * direction;
  });
}

function paginate(rows, query) {
  const page = Math.max(1, int(query.get('page'), 1));
  const size = Math.min(100, Math.max(1, int(query.get('size'), 10)));
  const total = rows.length;
  const totalPages = Math.max(1, Math.ceil(total / size));
  const start = (page - 1) * size;

  return {
    items: rows.slice(start, start + size),
    page,
    size,
    total,
    totalPages,
  };
}

function listRows(collection, query) {
  return query.get('includeDeleted') === 'true'
    ? [...db[collection]]
    : activeRows(collection);
}
// ---------------------------------------------------------------- схемы

function categorySchema() {
  return {
    collection: 'categories',
    searchFields: ['name', 'description'],
    sortFields: { id: 'id', name: 'name', description: 'description' },
    filter: (rows) => rows,
    validate(body, current) {
      const errors = {};
      const name = str(body.name);
      const description = str(body.description);

      if (!name) errors.name = 'Название обязательно';
      else if (name.length > 60) errors.name = 'Не длиннее 60 символов';
      else if (
        uniqueViolation(db.categories, 'name', name, current?.id)
      ) {
        errors.name = 'Категория с таким названием уже есть';
      }

      if (!description) errors.description = 'Описание обязательно';
      else if (description.length > 200) {
        errors.description = 'Не длиннее 200 символов';
      }

      return { errors, values: { name, description } };
    },
    expand: (row) => ({ ...row }),
    afterDelete(row) {
      return null;
    },
    integrity(row) {
      const linked = activeRows('habits').filter(
        (habit) => habit.categoryId === row.id,
      );
      return linked.length
        ? `На категорию ссылаются привычки: ${linked.length}`
        : null;
    },
  };
}

function tagSchema() {
  return {
    collection: 'tags',
    searchFields: ['name', 'color'],
    sortFields: { id: 'id', name: 'name', color: 'color' },
    filter(rows, query) {
      const categoryId = int(query.get('categoryId'));
      return categoryId === null
        ? rows
        : rows.filter((row) => row.categoryId === categoryId);
    },
    validate(body, current) {
      const errors = {};
      const name = str(body.name);
      const color = str(body.color);
      const categoryId = body.categoryId === null || body.categoryId === undefined
        ? null
        : int(body.categoryId, 0);

      if (!name) errors.name = 'Название обязательно';
      else if (name.length > 40) errors.name = 'Не длиннее 40 символов';
      else if (uniqueViolation(db.tags, 'name', name, current?.id)) {
        errors.name = 'Тег с таким названием уже есть';
      }

      if (!color) errors.color = 'Выберите цвет';

      if (categoryId !== null && !findRow('categories', categoryId)) {
        errors.categoryId = 'Категория не найдена';
      }

      return { errors, values: { name, color, categoryId } };
    },
    expand: (row) => ({ ...row }),
    afterDelete(row) {
      return null;
    },
    integrity(row) {
      const linked = activeRows('habits').filter((habit) =>
        habit.tagIds.includes(row.id),
      );
      return linked.length ? `Тег используется в привычках: ${linked.length}` : null;
    },
  };
}

function profileSchema() {
  return {
    collection: 'profiles',
    searchFields: ['name', 'email', 'city'],
    sortFields: { id: 'id', name: 'name', email: 'email', city: 'city' },
    filter(rows, query) {
      const city = str(query.get('city'));
      return city ? rows.filter((row) => row.city === city) : rows;
    },
    validate(body, current) {
      const errors = {};
      const name = str(body.name);
      const email = str(body.email).toLowerCase();
      const city = str(body.city);
      const dailyGoalMinutes = int(body.dailyGoalMinutes, -1);
      const remindersEnabled = bool(body.remindersEnabled, false);
      let couponId = body.couponId === null || body.couponId === undefined
        ? null
        : int(body.couponId, 0);

      if (!name) errors.name = 'Имя обязательно';
      else if (name.length > 60) errors.name = 'Не длиннее 60 символов';

      if (!email) errors.email = 'Почта обязательна';
      else if (!isEmail(email)) errors.email = 'Некорректный адрес почты';
      else if (uniqueViolation(db.profiles, 'email', email, current?.id)) {
        errors.email = 'Почта уже занята другим профилем';
      }

      if (!city) errors.city = 'Город обязателен';
      else if (city.length > 60) errors.city = 'Не длиннее 60 символов';

      if (dailyGoalMinutes < 1 || dailyGoalMinutes > 1440) {
        errors.dailyGoalMinutes = 'Цель от 1 до 1440 минут';
      }

      if (couponId !== null) {
        const coupon = findRow('coupons', couponId);
        if (!coupon) errors.couponId = 'Купон не найден';
        else if (current && coupon.profileId !== current.id) {
          errors.couponId = 'Купон принадлежит другому профилю';
        }
      }

      return {
        errors,
        values: { name, email, city, dailyGoalMinutes, remindersEnabled, couponId },
      };
    },
    expand(row) {
      const coupon = activeRows('coupons').find((item) => item.profileId === row.id);
      return { ...row, coupon: coupon ? couponPayload(coupon) : null };
    },
    scope(row, user) {
      return row.ownerId === user.id ? row : null;
    },
    afterDelete(row) {
      for (const coupon of activeRows('coupons')) {
        if (coupon.profileId === row.id) coupon.deletedAt = nowIso();
      }
    },
    integrity(row) {
      const habits = activeRows('habits').filter((h) => h.profileId === row.id);
      if (habits.length) return `На профиль ссылаются привычки: ${habits.length}`;

      const checkIns = activeRows('check_ins').filter(
        (c) => c.profileId === row.id,
      );
      if (checkIns.length) {
        return `На профиль ссылаются отметки: ${checkIns.length}`;
      }

      const coupon = activeRows('coupons').find((c) => c.profileId === row.id);
      if (coupon) return 'У профиля есть скидочный купон — сначала удалите купон';

      return null;
    },
  };
}

function habitSchema() {
  return {
    collection: 'habits',
    searchFields: ['name', 'goal'],
    sortFields: {
      id: 'id',
      name: 'name',
      goal: 'goal',
      minutes: 'minutesPerDay',
      minutesPerDay: 'minutesPerDay',
      streak: 'streak',
    },
    filter(rows, query) {
      let result = rows;
      const categoryId = int(query.get('categoryId'));
      const periodicityId = int(query.get('periodicityId'));
      const profileId = int(query.get('profileId'));
      const tagId = int(query.get('tagId'));
      const streakFrom = int(query.get('streakFrom'));
      const streakTo = int(query.get('streakTo'));

      if (categoryId !== null) {
        result = result.filter((row) => row.categoryId === categoryId);
      }
      if (periodicityId !== null) {
        result = result.filter((row) => row.periodicityId === periodicityId);
      }
      if (profileId !== null) {
        result = result.filter((row) => row.profileId === profileId);
      }
      if (tagId !== null) {
        result = result.filter((row) => row.tagIds.includes(tagId));
      }
      if (streakFrom !== null) {
        result = result.filter((row) => row.streak >= streakFrom);
      }
      if (streakTo !== null) {
        result = result.filter((row) => row.streak <= streakTo);
      }
      return result;
    },
    validate(body, current) {
      const errors = {};
      const name = str(body.name);
      const goal = str(body.goal);
      const categoryId = int(body.categoryId, 0);
      const periodicityId = int(body.periodicityId, 0);
      const minutesPerDay = int(body.minutesPerDay, -1);
      const streak = int(body.streak, -1);
      const profileId = int(body.profileId, 0);
      const tagIds = Array.isArray(body.tagIds)
        ? [...new Set(body.tagIds.map((id) => int(id, 0)).filter((id) => id > 0))]
        : [];

      if (!name) errors.name = 'Название обязательно';
      else if (name.length > 80) errors.name = 'Не длиннее 80 символов';
      else if (uniqueViolation(db.habits, 'name', name, current?.id)) {
        errors.name = 'Привычка с таким названием уже есть';
      }

      if (!goal) errors.goal = 'Цель обязательна';
      else if (goal.length > 200) errors.goal = 'Не длиннее 200 символов';

      if (!findRow('categories', categoryId)) {
        errors.categoryId = 'Категория не найдена';
      }
      if (periodicityId < 1 || periodicityId > 5) {
        errors.periodicityId = 'Периодичность от 1 до 5';
      }
      if (!findRow('profiles', profileId)) {
        errors.profileId = 'Профиль не найден';
      }
      if (minutesPerDay < 0 || minutesPerDay > 600) {
        errors.minutesPerDay = 'Минуты от 0 до 600';
      }
      if (streak < 0 || streak > 3650) {
        errors.streak = 'Серия от 0 до 3650';
      }
      const missingTag = tagIds.find((id) => !findRow('tags', id));
      if (missingTag) errors.tagIds = 'Один из тегов не найден';

      return {
        errors,
        values: {
          name,
          goal,
          categoryId,
          periodicityId,
          minutesPerDay,
          streak,
          profileId,
          tagIds,
        },
      };
    },
    ownerOf(body, current) {
      const profileId = int(body?.profileId);
      if (profileId !== null) return activeRows('profiles').find((p) => p.id === profileId) ?? null;
      return current ? activeRows('profiles').find((p) => p.id === current.profileId) ?? null : null;
    },
    scope(row, user) {
      const profile = activeRows('profiles').find((p) => p.id === row.profileId);
      return profile?.ownerId === user.id ? row : null;
    },
    expand(row) {
      return {
        ...row,
        category: categoryPayload(findRow('categories', row.categoryId)),
        profile: profilePayload(findRow('profiles', row.profileId)),
        tags: row.tagIds
          .map((id) => findRow('tags', id))
          .filter(Boolean)
          .map((tag) => ({ id: tag.id, name: tag.name, color: tag.color })),
      };
    },
    afterDelete(row) {
      return null;
    },
    integrity(row) {
      const linked = activeRows('check_ins').filter(
        (checkIn) => checkIn.habitId === row.id,
      );
      return linked.length ? `У привычки есть отметки: ${linked.length}` : null;
    },
  };
}

function checkInSchema() {
  return {
    collection: 'check_ins',
    searchFields: ['note'],
    sortFields: { id: 'id', date: 'date', minutes: 'minutes' },
    filter(rows, query) {
      let result = rows;
      const habitId = int(query.get('habitId'));
      const profileId = int(query.get('profileId'));
      const dateFrom = str(query.get('dateFrom'));
      const dateTo = str(query.get('dateTo'));

      if (habitId !== null) {
        result = result.filter((row) => row.habitId === habitId);
      }
      if (profileId !== null) {
        result = result.filter((row) => row.profileId === profileId);
      }
      if (dateFrom) {
        result = result.filter((row) => row.date.slice(0, 10) >= dateFrom);
      }
      if (dateTo) {
        result = result.filter((row) => row.date.slice(0, 10) <= dateTo);
      }
      return result;
    },
    conflict(body, current) {
      const habitId = int(body.habitId, 0);
      const date = str(body.date).slice(0, 10);
      const duplicate = activeRows('check_ins').find(
        (row) =>
          row.id !== current?.id &&
          row.habitId === habitId &&
          row.date.slice(0, 10) === date,
      );
      return duplicate
        ? 'Отметка этой привычки за эту дату уже существует'
        : null;
    },
    validate(body, current) {
      const errors = {};
      const habitId = int(body.habitId, 0);
      const profileId = int(body.profileId, 0);
      const date = str(body.date);
      const minutes = int(body.minutes, -1);
      const completed = bool(body.completed, false);
      const note = str(body.note);

      if (!findRow('habits', habitId)) errors.habitId = 'Привычка не найдена';
      if (!findRow('profiles', profileId)) errors.profileId = 'Профиль не найден';

      if (!date) errors.date = 'Дата обязательна';
      else if (!isDate(date)) errors.date = 'Некорректная дата';

      if (minutes < 0 || minutes > 1440) errors.minutes = 'Минуты от 0 до 1440';
      if (note.length > 200) errors.note = 'Не длиннее 200 символов';

      return {
        errors,
        values: { habitId, profileId, date, minutes, completed, note },
      };
    },
    expand(row) {
      return {
        ...row,
        habit: habitPayload(findRow('habits', row.habitId)),
        profile: profilePayload(findRow('profiles', row.profileId)),
      };
    },
    afterDelete(row) {
      return null;
    },
    integrity() {
      return null;
    },
  };
}

function couponSchema() {
  return {
    collection: 'coupons',
    searchFields: ['code'],
    sortFields: { id: 'id', code: 'code', discount: 'discountPercent' },
    filter(rows, query) {
      let result = rows;
      const profileId = int(query.get('profileId'));
      const discountFrom = int(query.get('discountFrom'));
      const discountTo = int(query.get('discountTo'));

      if (profileId !== null) {
        result = result.filter((row) => row.profileId === profileId);
      }
      if (discountFrom !== null) {
        result = result.filter((row) => row.discountPercent >= discountFrom);
      }
      if (discountTo !== null) {
        result = result.filter((row) => row.discountPercent <= discountTo);
      }
      return result;
    },
    validate(body, current) {
      const errors = {};
      const profileId = int(body.profileId, 0);
      const code = str(body.code).toUpperCase();
      const discountPercent = int(body.discountPercent, -1);
      const expiresAt = str(body.expiresAt);

      if (!findRow('profiles', profileId)) {
        errors.profileId = 'Профиль не найден';
      } else {
        const busy = activeRows('coupons').find(
          (row) => row.profileId === profileId && row.id !== current?.id,
        );
        if (busy) errors.profileId = 'У профиля уже есть купон';
      }

      if (!code) errors.code = 'Промокод обязателен';
      else if (!/^[A-Z0-9-]{4,20}$/.test(code)) {
        errors.code = 'От 4 до 20 символов: латиница, цифры, дефис';
      } else if (uniqueViolation(db.coupons, 'code', code, current?.id)) {
        errors.code = 'Такой промокод уже есть';
      }

      if (discountPercent < 1 || discountPercent > 100) {
        errors.discountPercent = 'Скидка от 1 до 100 %';
      }

      if (!expiresAt) errors.expiresAt = 'Укажите срок действия';
      else if (!isDate(expiresAt)) errors.expiresAt = 'Некорректная дата';

      return {
        errors,
        values: { profileId, code, discountPercent, expiresAt },
      };
    },
    expand(row) {
      return {
        ...row,
        profile: profilePayload(findRow('profiles', row.profileId)),
      };
    },
    afterCreate(row) {
      const profile = findRow('profiles', row.profileId);
      if (profile) profile.couponId = row.id;
    },
    afterUpdate(row, previous) {
      if (previous && previous.profileId !== row.profileId) {
        const oldProfile = findRow('profiles', previous.profileId);
        if (oldProfile) oldProfile.couponId = null;
      }
      const profile = findRow('profiles', row.profileId);
      if (profile) profile.couponId = row.id;
    },
    afterDelete(row) {
      const profile = findRow('profiles', row.profileId);
      if (profile && profile.couponId === row.id) profile.couponId = null;
    },
    integrity() {
      return null;
    },
  };
}

function categoryPayload(row) {
  return row ? { id: row.id, name: row.name } : null;
}

function tagPayload(row) {
  return row ? { id: row.id, name: row.name, color: row.color } : null;
}

function profilePayload(row) {
  return row
    ? { id: row.id, name: row.name, email: row.email, city: row.city }
    : null;
}

function habitPayload(row) {
  return row ? { id: row.id, name: row.name, goal: row.goal } : null;
}

function couponPayload(row) {
  return row
    ? {
        id: row.id,
        profileId: row.profileId,
        code: row.code,
        discountPercent: row.discountPercent,
        expiresAt: row.expiresAt,
      }
    : null;
}

const SCHEMAS = {
  categories: categorySchema(),
  tags: tagSchema(),
  profiles: profileSchema(),
  habits: habitSchema(),
  check_ins: checkInSchema(),
  coupons: couponSchema(),
};
// ---------------------------------------------------------------- права

function currentUser(req) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) return null;
  const payload = verify(header.slice(7));
  if (!payload || payload.role === undefined) return null;

  const row = db.users.find((item) => item.id === payload.sub && !item.deletedAt);
  if (!row) return null;

  return {
    id: row.id,
    username: row.username,
    role: row.role,
    profileId: row.profileId ?? null,
  };
}

function requireUser(req, res) {
  const user = currentUser(req);
  if (!user) {
    fail(res, 401, 'Требуется авторизация: передайте актуальный Bearer-токен');
    return null;
  }
  return user;
}

const WRITE_ROLES = new Set(['admin', 'librarian']);

function requireWrite(req, res) {
  const user = requireUser(req, res);
  if (!user) return null;
  if (!WRITE_ROLES.has(user.role)) {
    deny(res, user, 'изменение данных');
    return null;
  }
  return user;
}

function requireAdmin(req, res) {
  const user = requireUser(req, res);
  if (!user) return null;
  if (!canPurge(user)) {
    deny(res, user, 'операция только для администратора');
    return null;
  }
  return user;
}

function publicUser(user) {
  return {
    id: user.id,
    username: user.username,
    fullName: user.fullName,
    role: user.role,
    profileId: user.profileId ?? null,
  };
}

function issueTokens(user) {
  const accessToken = sign({
    sub: user.id,
    username: user.username,
    role: user.role,
    exp: Math.floor(Date.now() / 1000) + ACCESS_TTL,
  });
  const refreshToken = sign({
    sub: user.id,
    type: 'refresh',
    exp: Math.floor(Date.now() / 1000) + REFRESH_TTL,
  });
  const payload = verify(refreshToken);
  db.refreshTokens.add(payload.jti);

  return {
    accessToken,
    refreshToken,
    expiresIn: ACCESS_TTL,
    sessionTimeout: SESSION_TTL || null,
    tokenType: 'Bearer',
    user: publicUser(user),
  };
}
// ---------------------------------------------------------------- auth

async function handleAuth(req, res, segments) {
  const action = segments[1];

  if (req.method === 'POST' && action === 'login') {
    const body = await readBody(req);
    const username = str(body.username).toLowerCase();
    const password = str(body.password);

    const user = db.users.find(
      (item) => item.username.toLowerCase() === username && !item.deletedAt,
    );

    if (!user || user.passwordHash !== hashPassword(password)) {
      fail(res, 401, 'Неверный логин или пароль');
      return true;
    }

    send(res, 200, issueTokens(user));
    return true;
  }

  if (req.method === 'POST' && action === 'refresh') {
    const body = await readBody(req);
    const payload = verify(str(body.refreshToken));
    if (!payload || payload.type !== 'refresh' || !db.refreshTokens.has(payload.jti)) {
      fail(res, 401, 'Сессия истекла, войдите заново');
      return true;
    }

    db.refreshTokens.delete(payload.jti);
    const user = db.users.find((item) => item.id === payload.sub && !item.deletedAt);
    if (!user) {
      fail(res, 401, 'Пользователь не найден');
      return true;
    }

    send(res, 200, issueTokens(user));
    return true;
  }

  if (req.method === 'POST' && action === 'logout') {
    const body = await readBody(req);
    const payload = verify(str(body.refreshToken));
    if (payload?.jti) db.refreshTokens.delete(payload.jti);
    send(res, 204);
    return true;
  }

  if (req.method === 'GET' && action === 'me') {
    const user = requireUser(req, res);
    if (!user) return true;
    const row = db.users.find((item) => item.id === user.id);
    if (!row) {
      fail(res, 401, 'Пользователь не найден');
      return true;
    }
    send(res, 200, publicUser(row));
    return true;
  }

  if (req.method === 'POST' && action === 'register') {
    return registerUser(req, res, false);
  }

  if (req.method === 'POST' && action === 'register-strict') {
    return registerUser(req, res, true);
  }

  return false;
}

function registerUser(req, res, strict) {
  return readBody(req).then((body) => {
    const errors = {};
    const username = str(body.username).toLowerCase();
    const password = String(body.password ?? '');
    const fullName = str(body.fullName) || username;

    if (!/^[a-z0-9._-]{3,20}$/.test(username)) {
      errors.username = 'Логин: 3–20 символов, латиница, цифры, . _ -';
    } else if (
      db.users.some((item) => item.username.toLowerCase() === username)
    ) {
      errors.username = 'Логин занят';
    }

    if (strict) {
      if (password.length < 8) {
        errors.password = 'Пароль не короче 8 символов';
      } else if (!/[0-9]/.test(password)) {
        errors.password = 'Добавьте в пароль хотя бы одну цифру';
      } else if (!/[^A-Za-z0-9]/.test(password)) {
        errors.password = 'Добавьте специальный символ: ! @ # $ % и т. п.';
      }
    } else if (password.length < 6) {
      errors.password = 'Пароль не короче 6 символов';
    }

    if (Object.keys(errors).length) {
      validationFail(res, errors);
      return;
    }

    const user = {
      id: ++db.seq.users,
      username,
      fullName,
      role: 'reader',
      passwordHash: hashPassword(password),
      deletedAt: null,
    };
    db.users.push(user);
    persist('users', db.users);
    send(res, 201, issueTokens(user));
  });
}
// ---------------------------------------------------------------- CRUD

async function handleCollection(req, res, segments, query) {
  if (res.writableEnded) return true;

  const collection = segments[0];
  const schema = SCHEMAS[collection];
  if (!schema && collection !== 'users') {
    return false;
  }

  const second = segments[1];
  const third = segments[2];

  if (collection === 'users') {
    if (second === undefined) {
      if (req.method !== 'GET') {
        fail(res, 405, 'Метод не поддерживается');
        return true;
      }
      const user = requireUser(req, res);
      if (!user) return true;
      if (!canPurge(user)) {
        deny(res, user, 'просмотр пользователей');
        return true;
      }
      send(res, 200, {
        items: db.users.map((row) => ({
          ...publicUser(row),
          deletedAt: row.deletedAt,
        })),
      });
      return true;
    }

    const id = int(second);
    if (id === null) {
      fail(res, 400, 'Некорректный идентификатор');
      return true;
    }

    if (third === 'role' && (req.method === 'PUT' || req.method === 'PATCH')) {
      const user = requireUser(req, res);
      if (!user) return true;
      if (!canPurge(user)) {
        deny(res, user, 'изменение ролей');
        return true;
      }
      const row = db.users.find((item) => item.id === id);
      if (!row) {
        fail(res, 404, 'Пользователь не найден');
        return true;
      }
      const body = await readBody(req);
      const role = str(body.role);
      if (!['admin', 'librarian', 'reader'].includes(role)) {
        validationFail(res, { role: 'Допустимые роли: admin, librarian, reader' });
        return true;
      }
      if (row.id === user.id && role !== 'admin') {
        fail(res, 409, 'Нельзя понизить собственную роль администратора');
        return true;
      }
      row.role = role;
      persist('users', db.users);
      db.refreshTokens.clear();
      send(res, 200, { ...publicUser(row), deletedAt: row.deletedAt });
      return true;
    }

    if (req.method === 'DELETE') {
      const user = requireUser(req, res);
      if (!user) return true;
      if (!canPurge(user)) {
        deny(res, user, 'удаление пользователя');
        return true;
      }
      const row = db.users.find((item) => item.id === id);
      if (!row) {
        fail(res, 404, 'Пользователь не найден');
        return true;
      }
      if (row.id === user.id) {
        fail(res, 409, 'Нельзя удалить самого себя');
        return true;
      }
      row.deletedAt = nowIso();
      persist('users', db.users);
      db.refreshTokens.clear();
      send(res, 204);
      return true;
    }

    fail(res, 405, 'Метод не поддерживается');
    return true;
  }

  if (second === 'bulk-delete' && req.method === 'POST') {
    const user = requireUser(req, res);
    if (!user) return true;

      const body = await readBody(req);
      let ids = [];
      if (Array.isArray(body.ids)) {
        ids = body.ids.map((id) => int(id, 0));
      }
      const hard = body.hard === true;

      if (!canPurge(user)) {
        deny(res, user, 'массовое удаление');
        return true;
      }

      let deleted = 0;
      for (const id of ids) {
        const row = findRow(collection, id, true);
        if (!row) continue;
        if (hard) {
          db[collection] = db[collection].filter((item) => item.id !== id);
        } else {
          row.deletedAt = nowIso();
        }
        if (schema.afterDelete) schema.afterDelete(row);
        deleted++;
      }

    persist(collection, db[collection]);
    send(res, 200, { deleted });
    return true;
  }

  if (second === undefined) {
    if (req.method === 'GET') {
      const user = requireUser(req, res);
      if (!user) return true;

      let rows = listRows(collection, query);
      if (user.role === 'reader') {
        const ownProfiles = activeRows('profiles')
          .filter((p) => p.ownerId === user.id)
          .map((p) => p.id);
        if (ownProfiles.length) {
          if (collection === 'habits') {
            rows = rows.filter((row) => ownProfiles.includes(row.profileId));
          } else if (collection === 'check_ins') {
            rows = rows.filter((row) => ownProfiles.includes(row.profileId));
          } else if (collection === 'coupons') {
            rows = rows.filter((row) => ownProfiles.includes(row.profileId));
          }
        }
      }
      rows = applySearch(rows, schema.searchFields, query.get('search'));
      rows = schema.filter(rows, query);
      rows = applySort(rows, query.get('sort'), schema.sortFields);

      const page = paginate(rows, query);
      send(res, 200, {
        items: page.items.map(schema.expand),
        page: page.page,
        size: page.size,
        total: page.total,
        totalPages: page.totalPages,
      });
      return true;
    }

    if (req.method === 'POST') {
      const user = requireWrite(req, res);
      if (!user) return true;

      const body = await readBody(req);
      if (schema.conflict) {
        const conflict = schema.conflict(body, null);
        if (conflict) {
          fail(res, 409, conflict);
          return true;
        }
      }

      const { errors, values } = schema.validate(body, null);
      if (Object.keys(errors).length) {
        validationFail(res, errors);
        return true;
      }

      const row = { id: ++db.seq[collection], ...values, deletedAt: null };
      db[collection].push(row);
      persist(collection, db[collection]);
      if (schema.afterCreate) schema.afterCreate(row);

      send(res, 201, schema.expand(row), {
        Location: `/api/${collection}/${row.id}`,
      });
      return true;
    }

    if (second !== undefined) {
      return false;
    }
  }

  const id = int(second);
  if (id === null) {
    fail(res, 400, 'Некорректный идентификатор');
    return true;
  }

  if (third === 'restore' && req.method === 'POST') {
    const user = requireUser(req, res);
    if (!user) return true;
    if (!canPurge(user)) {
      deny(res, user, 'восстановление из корзины');
      return true;
    }

    const row = findRow(collection, id, true);
    if (!row) {
      fail(res, 404, 'Запись не найдена');
      return true;
    }

    row.deletedAt = null;
    persist(collection, db[collection]);
    if (collection === 'coupons' && schema.afterCreate) schema.afterCreate(row);
    send(res, 200, schema.expand(row));
    return true;
  }

  if (third !== undefined) {
    fail(res, 404, 'Метод не найден');
    return true;
  }

  if (req.method === 'GET') {
    const user = requireUser(req, res);
    if (!user) return true;

    const includeDeleted = query.get('includeDeleted') === 'true';
    const row = findRow(collection, id, includeDeleted);
    if (!row || (schema.scope && !schema.scope(row, user))) {
      fail(res, 404, 'Запись не найдена');
      return true;
    }
    send(res, 200, schema.expand(row));
    return true;
  }

  if (req.method === 'PUT' || req.method === 'PATCH') {
    const user = requireWrite(req, res);
    if (!user) return true;

    const row = findRow(collection, id);
    if (!row || (schema.scope && !schema.scope(row, user))) {
      fail(res, 404, 'Запись не найдена');
      return true;
    }

    const body = await readBody(req);
    if (user.role === 'reader' && schema.ownerOf) {
      const owner = schema.ownerOf(body, row);
      if (!owner || owner.ownerId !== user.id) {
        deny(res, user, 'изменение записи чужого профиля');
        return true;
      }
    }
    const previous = { ...row };

    if (schema.conflict) {
      const conflict = schema.conflict(body, row);
      if (conflict) {
        fail(res, 409, conflict);
        return true;
      }
    }

    const { errors, values } = schema.validate(body, row);
    if (Object.keys(errors).length) {
      validationFail(res, errors);
      return true;
    }

    Object.assign(row, values);
    persist(collection, db[collection]);
    if (schema.afterUpdate) schema.afterUpdate(row, previous);

    send(res, 200, schema.expand(row));
    return true;
  }

  if (req.method === 'DELETE') {
    const hard = query.get('hard') === 'true';
    const user = requireWrite(req, res);
    if (!user) return true;
    if (hard && !canPurge(user)) {
      deny(res, user, 'безвозвратное удаление');
      return true;
    }

    const row = findRow(collection, id);
    if (!row) {
      fail(res, 404, 'Запись не найдена');
      return true;
    }

    const problem = schema.integrity ? schema.integrity(row) : null;
    if (problem) {
      fail(res, 409, problem);
      return true;
    }

    if (hard) {
      db[collection] = db[collection].filter((item) => item.id !== id);
    } else {
      row.deletedAt = nowIso();
    }
    persist(collection, db[collection]);
    if (schema.afterDelete) schema.afterDelete(row);

    send(res, 204);
    return true;
  }

  return false;
}
// ---------------------------------------------------------------- запуск

const server = http.createServer(async (req, res) => {
  const startedAt = Date.now();
  let url;

  try {
    url = new URL(req.url, `http://localhost:${PORT}`);
  } catch {
    res.writeHead(400, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Некорректный адрес');
    return;
  }

  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders());
    res.end();
    return;
  }

  if (!url.pathname.startsWith('/api')) {
    if (SPA) {
      serveStatic(req, res, url.pathname);
      return;
    }
    fail(res, 404, 'Используйте префикс /api');
    return;
  }

  if (url.searchParams.get('__delay')) {
    const delay = Math.min(10_000, Math.max(0, int(url.searchParams.get('__delay'), 0)));
    await new Promise((resolve) => setTimeout(resolve, delay));
  }

  if (url.searchParams.get('__fail')) {
    const code = Math.min(599, Math.max(400, int(url.searchParams.get('__fail'), 500)));
    fail(res, code, `Учебная ошибка ${code} (параметр __fail)`);
    log(req, code, startedAt);
    return;
  }

  const segments = url.pathname
    .replace(/\/+$/, '')
    .slice(4)
    .split('/')
    .filter(Boolean);

  try {
    if (segments.length === 1 && segments[0] === '__health' && req.method === 'GET') {
      send(res, 200, {
        status: 'ok',
        now: nowIso(),
        storage: store ? 'sqlite' : 'memory',
        uptimeSeconds: Math.round(process.uptime()),
        counts: {
          categories: activeRows('categories').length,
          tags: activeRows('tags').length,
          profiles: activeRows('profiles').length,
          habits: activeRows('habits').length,
          check_ins: activeRows('check_ins').length,
          coupons: activeRows('coupons').length,
          users: activeRows('users').length,
        },
      });
      log(req, 200, startedAt);
      return;
    }

    if (segments.length === 1 && segments[0] === '__reset' && req.method === 'POST') {
      const users = db.users;
      seed();
      db.users = users;
      persistAll();
      send(res, 200, { status: 'ok', message: 'Данные восстановлены' });
      log(req, 200, startedAt);
      return;
    }

    if (segments[0] === 'auth') {
      const handled = await handleAuth(req, res, segments);
      if (handled) {
        log(req, res.statusCode, startedAt);
        return;
      }
      fail(res, 404, 'Метод авторизации не найден');
      log(req, 404, startedAt);
      return;
    }

    if (segments[0] === 'stats' && segments.length === 1 && req.method === 'GET') {
      const user = requireUser(req, res);
      if (user) {
        if (!canPurge(user)) {
          deny(res, user, 'просмотр статистики');
        } else {
          send(res, 200, statistics());
        }
      }
      log(req, res.statusCode, startedAt);
      return;
    }

    const handled = await handleCollection(req, res, segments, url.searchParams);
    if (handled || res.writableEnded) {
      persistChanged(res);
      log(req, res.statusCode, startedAt);
      return;
    }

    fail(res, 404, 'Метод не найден');
    log(req, 404, startedAt);
  } catch (error) {
    if (!res.headersSent) {
      fail(res, 400, error instanceof Error ? error.message : 'Некорректный запрос');
    }
    log(req, res.statusCode, startedAt);
  }
});

function persistChanged() {
  if (!store) return;
  persistAll();
}

function log(req, status, startedAt) {
  const duration = Date.now() - startedAt;
  console.log(`${req.method} ${req.url} → ${status} (${duration} мс)`);
}

server.listen(PORT, () => {
  console.log(`API «Трекер привычек»: http://localhost:${PORT}/api`);
  console.log(`Хранилище: ${store ? 'SQLite (' + DB_FILE + ')' : 'память'}`);
  console.log(SPA ? `Клиент: ${SITE_DIR}` : 'Клиент не найден — только API');
  console.log(`CORS origin: ${ORIGIN}`);
  console.log(`Токен доступа: ${ACCESS_TTL} с (--ttl), сессия: ${SESSION_TTL || 'без ограничения'}`);
  console.log('Учётные записи: admin/admin123, librarian/librarian123, reader/reader123');
});
