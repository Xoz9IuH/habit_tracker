#!/usr/bin/env node
'use strict';

/**
 * Проверка учебного API: коды ответов, права, валидация и связи.
 * Запуск (сервер уже работает):
 *   node smoke-test.js
 */

const BASE = process.env.API_URL || 'http://localhost:8080/api';

let passed = 0;
let failed = 0;

function check(name, condition, detail = '') {
  if (condition) {
    passed++;
    console.log(`  ok   ${name}`);
  } else {
    failed++;
    console.log(`  FAIL ${name} ${detail}`);
  }
}

async function call(method, path, { token, body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(BASE + path, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }
  return { status: response.status, data };
}

async function login(username, password) {
  const result = await call('POST', '/auth/login', {
    body: { username, password },
  });
  return result.data;
}

async function main() {
  console.log(`Проверка API: ${BASE}\n`);

  console.log('1. Служебные методы');
  const health = await call('GET', '/__health');
  check('GET /__health → 200', health.status === 200);
  check('в базе 15 привычек', health.data?.counts?.habits === 15);

  console.log('\n2. Авторизация и роли');
  const admin = await login('admin', 'admin123');
  const librarian = await login('librarian', 'librarian123');
  const reader = await login('reader', 'reader123');
  check('вход администратора', admin?.user?.role === 'admin');
  check('вход редактора', librarian?.user?.role === 'librarian');
  check('вход читателя', reader?.user?.role === 'reader');

  const anonymous = await call('GET', '/habits');
  check('без токена → 401', anonymous.status === 401);

  const forbidden = await call('POST', '/habits', {
    token: reader.accessToken,
    body: { name: 'Тест', goal: 'Тест', categoryId: 1, periodicityId: 1, minutesPerDay: 1, streak: 0, profileId: 1 },
  });
  check('читатель создаёт привычку → 403', forbidden.status === 403);

  console.log('\n3. Списки: поиск, фильтры, сортировка, страницы');
  const page = await call('GET', '/habits?page=2&size=5&sort=streak,desc', {
    token: admin.accessToken,
  });
  check('страница 2 из 5', page.data?.page === 2 && page.data?.totalPages === 3);
  check('в странице 5 записей', page.data?.items?.length === 5);

  const sorted = await call('GET', '/habits?sort=streak,desc&size=100', {
    token: admin.accessToken,
  });
  const streaks = sorted.data.items.map((h) => h.streak);
  check(
    'сортировка по серии убывает',
    streaks.every((value, index) => index === 0 || streaks[index - 1] >= value),
  );

  const search = await call('GET', '/habits?search=вод&size=100', {
    token: admin.accessToken,
  });
  check('поиск «вод» находит 1', search.data?.total === 1);

  const filtered = await call('GET', '/habits?categoryId=1&size=100', {
    token: admin.accessToken,
  });
  check('фильтр по категории', filtered.data?.total === 3);

  const byTag = await call('GET', '/habits?tagId=6&size=100', {
    token: admin.accessToken,
  });
  check('фильтр по тегу', byTag.data?.total === 3);

  console.log('\n4. Развёрнутые связи');
  const habit = await call('GET', '/habits/1', { token: admin.accessToken });
  check('привычка отдаёт категорию', habit.data?.category?.name === 'Спорт');
  check('привычка отдаёт профиль', habit.data?.profile?.name === 'Олег Бундович');
  check('привычка отдаёт теги', habit.data?.tags?.length === 2);

  const profile = await call('GET', '/profiles/1', { token: admin.accessToken });
  check('профиль отдаёт купон', profile.data?.coupon?.code === 'START-20');

  console.log('\n5. Валидация 422');
  const duplicate = await call('POST', '/categories', {
    token: admin.accessToken,
    body: { name: 'Спорт', description: 'Дубль' },
  });
  check('дубль категории → 422', duplicate.status === 422);
  check('ошибка в поле name', Boolean(duplicate.data?.errors?.name));

  const badHabit = await call('POST', '/habits', {
    token: admin.accessToken,
    body: { name: '', goal: '', categoryId: 999, periodicityId: 9, profileId: 999, minutesPerDay: -5, streak: -1, tagIds: [999] },
  });
  check('пустая привычка → 422', badHabit.status === 422);
  check('ошибки по шести полям', Object.keys(badHabit.data?.errors ?? {}).length >= 6);

  console.log('\n6. Ограничения целостности 409');
  const categoryConflict = await call('DELETE', '/categories/1', {
    token: admin.accessToken,
  });
  check('удаление категории с привычками → 409', categoryConflict.status === 409);

  const checkInConflict = await call('POST', '/check_ins', {
    token: admin.accessToken,
    body: { habitId: 1, profileId: 1, date: '2026-10-18T00:00:00.000Z', minutes: 10, completed: true, note: '' },
  });
  check('повторная отметка за дату → 409', checkInConflict.status === 409);

  console.log('\n7. CRUD');
  const created = await call('POST', '/habits', {
    token: librarian.accessToken,
    body: { name: 'Проверка API', goal: 'Пройти smoke-test', categoryId: 3, periodicityId: 1, minutesPerDay: 5, streak: 0, profileId: 2, tagIds: [5] },
  });
  check('создание → 201', created.status === 201);
  check('сервер выдал id', Number.isInteger(created.data?.id));
  const id = created.data.id;

  const updated = await call('PUT', `/habits/${id}`, {
    token: librarian.accessToken,
    body: { name: 'Проверка API 2', goal: 'Пройти smoke-test', categoryId: 3, periodicityId: 1, minutesPerDay: 7, streak: 1, profileId: 2, tagIds: [5] },
  });
  check('изменение → 200', updated.status === 200 && updated.data?.minutesPerDay === 7);

  const softly = await call('DELETE', `/habits/${id}`, {
    token: librarian.accessToken,
  });
  check('мягкое удаление → 204', softly.status === 204);

  const gone = await call('GET', `/habits/${id}`, { token: admin.accessToken });
  check('удалённая запись → 404', gone.status === 404);

  const withDeleted = await call('GET', `/habits/${id}?includeDeleted=true`, {
    token: admin.accessToken,
  });
  check('includeDeleted отдаёт запись', withDeleted.status === 200);

  const restored = await call('POST', `/habits/${id}/restore`, {
    token: librarian.accessToken,
  });
  check('восстановление → 200', restored.status === 200 && restored.data?.deletedAt === null);

  const hardAsLibrarian = await call('DELETE', `/habits/${id}?hard=true`, {
    token: librarian.accessToken,
  });
  check('жёсткое удаление редактором → 403', hardAsLibrarian.status === 403);

  const hard = await call('DELETE', `/habits/${id}?hard=true`, {
    token: admin.accessToken,
  });
  check('жёсткое удаление администратором → 204', hard.status === 204);

  console.log('\n8. Массовое удаление');
  const bulk = await call('POST', '/habits/bulk-delete', {
    token: admin.accessToken,
    body: { ids: [15] },
  });
  check('bulk-delete → 200, deleted=1', bulk.status === 200 && bulk.data?.deleted === 1);

  console.log('\n9. Связь 1:1 профиль ↔ купон');
  const coupon = await call('POST', '/coupons', {
    token: admin.accessToken,
    body: { profileId: 2, code: 'TEST-30', discountPercent: 30, expiresAt: '2027-01-31T00:00:00.000Z' },
  });
  check('создание купона → 201', coupon.status === 201);
  const linked = await call('GET', '/profiles/2', { token: admin.accessToken });
  check('профиль получил couponId', linked.data?.couponId === coupon.data?.id);

  const second = await call('POST', '/coupons', {
    token: admin.accessToken,
    body: { profileId: 2, code: 'TEST-31', discountPercent: 10, expiresAt: '2027-01-31T00:00:00.000Z' },
  });
  check('второй купон профилю → 422', second.status === 422);

  await call('DELETE', `/coupons/${coupon.data.id}`, { token: admin.accessToken });
  const unlinked = await call('GET', '/profiles/2', { token: admin.accessToken });
  check('после удаления купона связь снята', unlinked.data?.couponId === null);

  console.log('\n10. Учебные переключатели');
  const started = Date.now();
  await call('GET', '/categories?__delay=700', { token: admin.accessToken });
  const elapsed = Date.now() - started;
  check('__delay задерживает ответ', elapsed >= 650, `(${elapsed} мс)`);

  const forced = await call('GET', '/categories?__fail=500', {
    token: admin.accessToken,
  });
  check('__fail=500 → 500', forced.status === 500);

  console.log('\n11. CORS');
  const preflight = await fetch(BASE + '/habits', {
    method: 'OPTIONS',
    headers: {
      Origin: 'http://localhost:5555',
      'Access-Control-Request-Method': 'POST',
    },
  });
  check(
    'preflight отвечает 204',
    preflight.status === 204,
    `(код ${preflight.status})`,
  );

  console.log('\n12. Сброс данных');
  const reset = await call('POST', '/__reset');
  check('POST /__reset → 200', reset.status === 200);
  const afterReset = await call('GET', '/__health');
  check('после сброса снова 15 привычек', afterReset.data?.counts?.habits === 15);

  console.log(`\nИтого: ${passed} успешно, ${failed} с ошибкой`);
  if (failed > 0) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
