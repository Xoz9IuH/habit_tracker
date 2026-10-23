#!/usr/bin/env node
'use strict';

/**
 * Учебный REST API «Трекер привычек» (ПР4).
 *
 *   node mock-server.js
 *   node mock-server.js --port 8080 --origin http://localhost:5555
 *
 * Данные хранятся в памяти и сбрасываются POST /api/__reset.
 * Переключатели: ?__delay=1500 (задержка ответа), ?__fail=500 (учебная ошибка).
 */

const http = require('node:http');
const crypto = require('node:crypto');

const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf('--' + name);
  return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
}

const PORT = Number(arg('port', 8080));
const ORIGIN = arg('origin', '*');
const ACCESS_TTL = Number(arg('ttl', 900));
const REFRESH_TTL = 60 * 60 * 24 * 7;
const SECRET = 'habit-tracker-training-api-secret';

// ---------------------------------------------------------------- токены

function b64url(value) {
  return Buffer.from(value).toString('base64url');
}

function sign(payload) {
  const withId = { ...payload, jti: crypto.randomUUID() };
  const body = b64url(JSON.stringify(withId));
  const mac = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  return body + '.' + mac;
}

function verify(token) {
  if (typeof token !== 'string' || !token.includes('.')) return null;
  const [body, mac] = token.split('.');
  const expected = crypto
    .createHmac('sha256', SECRET)
    .update(body)
    .digest('base64url');
  if (mac !== expected) return null;

  let payload;
  try {
    payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (payload.exp && payload.exp * 1000 < Date.now()) return null;
  return payload;
}

function hashPassword(password) {
  return crypto.createHash('sha256').update('salt:' + password).digest('hex');
}

// ---------------------------------------------------------------- данные

let db;

function seed() {
  db = {
    seq: {
      categories: 6,
      tags: 8,
      profiles: 3,
      habits: 15,
      check_ins: 12,
      coupons: 2,
      users: 3,
    },
    categories: [],
    tags: [],
    profiles: [],
    habits: [],
    check_ins: [],
    coupons: [],
    users: [],
    refreshTokens: new Set(),
  };

  const categories = [
    ['Спорт', 'Физическая активность и выносливость'],
    ['Здоровье', 'Сон, питание и самочувствие'],
    ['Обучение', 'Чтение, языки и новые навыки'],
    ['Быт', 'Домашние дела и порядок'],
    ['Продуктивность', 'Фокус, планирование и ритуалы'],
    ['Творчество', 'Рисование, музыка и хобби'],
  ];
  for (const [name, description] of categories) {
    db.categories.push({ id: db.categories.length + 1, name, description, deletedAt: null });
  }

  const tags = [
    ['утро', 'оранжевый', null],
    ['вечер', 'фиолетовый', null],
    ['здоровье', 'зелёный', 2],
    ['дома', 'серый', 4],
    ['учёба', 'синий', 3],
    ['сложное', 'красный', null],
    ['быстро', 'зелёный', null],
    ['ритуал', 'серый', 5],
  ];
  for (const [name, color, categoryId] of tags) {
    db.tags.push({ id: db.tags.length + 1, name, color, categoryId, deletedAt: null });
  }

  const profiles = [
    ['Олег Бундович', 'oleg@example.com', 'Москва', 120, true, 1],
    ['Мария Петрова', 'maria@example.com', 'Казань', 60, false, null],
    ['Иван Сидоров', 'ivan@example.com', 'Москва', 90, true, 2],
  ];
  for (const [name, email, city, goal, reminders, couponId] of profiles) {
    db.profiles.push({
      id: db.profiles.length + 1,
      name,
      email,
      city,
      dailyGoalMinutes: goal,
      remindersEnabled: reminders,
      couponId,
      deletedAt: null,
    });
  }

  const coupons = [
    [1, 'START-20', 20, '2026-12-31T00:00:00.000Z'],
    [3, 'FRIEND-15', 15, '2026-11-30T00:00:00.000Z'],
  ];
  for (const [profileId, code, discountPercent, expiresAt] of coupons) {
    db.coupons.push({
      id: db.coupons.length + 1,
      profileId,
      code,
      discountPercent,
      expiresAt,
      deletedAt: null,
    });
  }

  const habits = [
    ['Утренняя зарядка', 'Все 7 дней в неделю', 1, 1, 15, 42, 1, [1, 7]],
    ['Пробежка 5 км', 'Темп лучше 7:30 / км', 1, 2, 35, 12, 1, [1, 6]],
    ['Медитация 10 минут', 'Спокойно досидеть таймер', 5, 1, 10, 63, 2, [2, 8]],
    ['Чтение 30 страниц', '12 книг за год', 3, 1, 30, 21, 1, [2, 5]],
    ['Английский по 20 минут', 'Уровень B2 к июню', 3, 1, 20, 35, 2, [5]],
    ['8 стаканов воды', 'Каждый день без напоминаний', 2, 1, 5, 49, 1, [3, 7]],
    ['Силовая тренировка', '3 тренировки в неделю', 1, 3, 60, 8, 3, [6]],
    ['Дневник благодарности', 'Три пункта каждый вечер', 5, 1, 5, 17, 1, [2, 8]],
    ['Уборка стола', 'Рабочая зона пустая к вечеру', 4, 4, 10, 3, 2, [4]],
    ['Отбой до 23:00', '7+ часов сна', 2, 1, 0, 6, 1, [2, 3]],
    ['День без сахара', 'Не сладкого с понедельника', 2, 1, 10, 15, 3, [3]],
    ['Скетчинг', 'Один набросок в два дня', 6, 2, 40, 9, 2, [2]],
    ['Изучение Dart', 'Каждый будний день', 3, 5, 45, 11, 1, [5, 6]],
    ['Стирка и сортировка', 'Бельё разложено в шкафу', 4, 4, 25, 2, 3, [4]],
    ['Соцсети до обеда', 'Отвыкнуть от утреннего скролла', 4, 1, 10, 0, 2, [4]],
  ];
  for (const [name, goal, categoryId, periodicityId, minutesPerDay, streak, profileId, tagIds] of habits) {
    db.habits.push({
      id: db.habits.length + 1,
      name,
      goal,
      categoryId,
      periodicityId,
      minutesPerDay,
      streak,
      profileId,
      tagIds,
      deletedAt: null,
    });
  }

  const checkIns = [
    [1, 1, '2026-10-18', 15, true, 'Легко вышло'],
    [1, 1, '2026-10-19', 15, true, ''],
    [6, 1, '2026-10-19', 5, true, 'Все 8 стаканов'],
    [4, 1, '2026-10-20', 30, false, 'Только 10 страниц'],
    [3, 2, '2026-10-20', 10, true, ''],
    [13, 1, '2026-10-20', 45, true, 'Разобрал коллекции'],
    [9, 2, '2026-10-20', 10, true, ''],
    [11, 3, '2026-10-20', 0, false, 'Сорвалась вечером'],
    [2, 1, '2026-10-21', 35, true, 'Рекорд сезона'],
    [5, 2, '2026-10-21', 20, true, ''],
    [12, 2, '2026-10-21', 40, false, 'Набросок не начал'],
    [14, 3, '2026-10-21', 25, true, ''],
  ];
  for (const [habitId, profileId, date, minutes, completed, note] of checkIns) {
    db.check_ins.push({
      id: db.check_ins.length + 1,
      habitId,
      profileId,
      date: date + 'T00:00:00.000Z',
      minutes,
      completed,
      note,
      deletedAt: null,
    });
  }

  const users = [
    ['admin', 'admin123', 'Администратор', 'admin'],
    ['librarian', 'librarian123', 'Редактор', 'librarian'],
    ['reader', 'reader123', 'Читатель', 'reader'],
  ];
  for (const [username, password, fullName, role] of users) {
    db.users.push({
      id: db.users.length + 1,
      username,
      fullName,
      role,
      passwordHash: hashPassword(password),
      deletedAt: null,
    });
  }
}

seed();

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
  return { id: payload.sub, username: payload.username, role: payload.role };
}

function requireUser(req, res) {
  const user = currentUser(req);
  if (!user) {
    fail(res, 401, 'Требуется авторизация: передайте Bearer-токен');
    return null;
  }
  return user;
}

const WRITE_ROLES = new Set(['admin', 'librarian']);

function requireWrite(req, res) {
  const user = requireUser(req, res);
  if (!user) return null;
  if (!WRITE_ROLES.has(user.role)) {
    fail(res, 403, 'Роль «читатель» не может изменять данные');
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
    const body = await readBody(req);
    const errors = {};
    const username = str(body.username).toLowerCase();
    const password = str(body.password);
    const fullName = str(body.fullName) || username;

    if (!/^[a-z0-9._-]{3,20}$/.test(username)) {
      errors.username = 'Логин: 3–20 символов, латиница, цифры, . _ -';
    } else if (
      db.users.some((item) => item.username.toLowerCase() === username)
    ) {
      errors.username = 'Логин занят';
    }
    if (password.length < 6) errors.password = 'Пароль не короче 6 символов';

    if (Object.keys(errors).length) {
      validationFail(res, errors);
      return true;
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
    send(res, 201, issueTokens(user));
    return true;
  }

  return false;
}

// ---------------------------------------------------------------- CRUD

async function handleCollection(req, res, segments, query) {
  const collection = segments[0];
  const schema = SCHEMAS[collection];
  if (!schema) return false;

  const second = segments[1];
  const third = segments[2];

  if (second === 'bulk-delete' && req.method === 'POST') {
    const user = requireWrite(req, res);
    if (!user) return true;

    const body = await readBody(req);
    const ids = Array.isArray(body.ids) ? body.ids.map((id) => int(id, 0)) : [];
    const hard = body.hard === true;

    if (hard && user.role !== 'admin') {
      fail(res, 403, 'Безвозвратное удаление доступно только администратору');
      return true;
    }

    let deleted = 0;
    for (const id of ids) {
      const row = findRow(collection, id);
      if (!row) continue;
      if (hard) {
        db[collection] = db[collection].filter((item) => item.id !== id);
      } else {
        row.deletedAt = nowIso();
      }
      if (schema.afterDelete) schema.afterDelete(row);
      deleted++;
    }

    send(res, 200, { deleted });
    return true;
  }

  if (second === undefined) {
    if (req.method === 'GET') {
      if (!requireUser(req, res)) return true;

      let rows = listRows(collection, query);
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
      if (!requireWrite(req, res)) return true;

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
      if (schema.afterCreate) schema.afterCreate(row);

      send(res, 201, schema.expand(row), {
        Location: `/api/${collection}/${row.id}`,
      });
      return true;
    }

    return false;
  }

  const id = int(second);
  if (id === null) {
    fail(res, 400, 'Некорректный идентификатор');
    return true;
  }

  if (third === 'restore' && req.method === 'POST') {
    const user = requireUser(req, res);
    if (!user) return true;

    const row = findRow(collection, id, true);
    if (!row) {
      fail(res, 404, 'Запись не найдена');
      return true;
    }

    row.deletedAt = null;
    if (collection === 'coupons' && schema.afterCreate) schema.afterCreate(row);
    send(res, 200, schema.expand(row));
    return true;
  }

  if (third !== undefined) {
    fail(res, 404, 'Метод не найден');
    return true;
  }

  if (req.method === 'GET') {
    if (!requireUser(req, res)) return true;

    const includeDeleted = query.get('includeDeleted') === 'true';
    const row = findRow(collection, id, includeDeleted);
    if (!row) {
      fail(res, 404, 'Запись не найдена');
      return true;
    }
    send(res, 200, schema.expand(row));
    return true;
  }

  if (req.method === 'PUT' || req.method === 'PATCH') {
    if (!requireWrite(req, res)) return true;

    const row = findRow(collection, id);
    if (!row) {
      fail(res, 404, 'Запись не найдена');
      return true;
    }

    const body = await readBody(req);
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
    if (schema.afterUpdate) schema.afterUpdate(row, previous);

    send(res, 200, schema.expand(row));
    return true;
  }

  if (req.method === 'DELETE') {
    const hard = query.get('hard') === 'true';

    const user = hard ? requireUser(req, res) : requireWrite(req, res);
    if (!user) return true;
    if (hard && user.role !== 'admin') {
      fail(res, 403, 'Безвозвратное удаление доступно только администратору');
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
    if (schema.afterDelete) schema.afterDelete(row);

    send(res, 204);
    return true;
  }

  return false;
}

// ---------------------------------------------------------------- сервер

const server = http.createServer(async (req, res) => {
  const startedAt = Date.now();

  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders());
    res.end();
    return;
  }

  let url;
  try {
    url = new URL(req.url, `http://localhost:${PORT}`);
  } catch {
    fail(res, 400, 'Некорректный адрес');
    return;
  }

  const path = url.pathname.replace(/\/+$/, '') || '/';
  if (!path.startsWith('/api')) {
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

  const segments = path.slice(4).split('/').filter(Boolean);

  try {
    if (segments.length === 1 && segments[0] === '__health' && req.method === 'GET') {
      send(res, 200, {
        status: 'ok',
        now: nowIso(),
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
      seed();
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

    if (segments[0] === 'users') {
      const user = requireUser(req, res);
      if (user) {
        if (user.role !== 'admin') {
          fail(res, 403, 'Список пользователей доступен только администратору');
        } else if (req.method === 'GET') {
          send(res, 200, {
            items: db.users.map((item) => ({
              ...publicUser(item),
              deletedAt: item.deletedAt,
            })),
          });
        } else {
          fail(res, 405, 'Метод не поддерживается');
        }
      }
      log(req, res.statusCode, startedAt);
      return;
    }

    const handled = await handleCollection(req, res, segments, url.searchParams);
    if (handled) {
      log(req, res.statusCode, startedAt);
      return;
    }

    fail(res, 404, 'Метод не найден');
    log(req, 404, startedAt);
  } catch (error) {
    fail(res, 400, error instanceof Error ? error.message : 'Некорректный запрос');
    log(req, 400, startedAt);
  }
});

function log(req, status, startedAt) {
  const duration = Date.now() - startedAt;
  console.log(`${req.method} ${req.url} → ${status} (${duration} мс)`);
}

server.listen(PORT, () => {
  console.log(`Mock API «Трекер привычек»: http://localhost:${PORT}/api`);
  console.log(`CORS origin: ${ORIGIN}`);
  console.log('Учётные записи: admin/admin123, librarian/librarian123, reader/reader123');
  console.log('Сброс данных: POST /api/__reset');
});
