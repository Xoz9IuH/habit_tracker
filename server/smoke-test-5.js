// -*- coding: utf-8 -*-
/** Smoke-тест ПР5: роли, пользователи, статистика. Запускает сервер сам. */
import { spawn } from 'node:child_process';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HOST = '127.0.0.1';
const PORT = Number(process.env.SMOKE_PORT || 8081);
const ORIGIN = 'http://localhost:5555';
const API = `http://${HOST}:${PORT}/api`;

const here = path.dirname(fileURLToPath(import.meta.url));

let passed = 0;
let failed = 0;

function check(name, ok, extra = '') {
  if (ok) {
    passed += 1;
    console.log('  ok   ' + name);
  } else {
    failed += 1;
    console.log('  FAIL ' + name + (extra ? ' -> ' + extra : ''));
  }
}

function call(method, url, { token, body } = {}) {
  return new Promise((resolve, reject) => {
    const payload = body === undefined ? null : JSON.stringify(body);
    const req = http.request(
      API + url,
      {
        method,
        headers: {
          ...(payload ? { 'Content-Type': 'application/json' } : {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => {
          raw += chunk;
        });
        res.on('end', () => {
          let data = null;
          try {
            data = raw ? JSON.parse(raw) : null;
          } catch {
            data = raw;
          }
          resolve({ status: res.statusCode, data });
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function login(username, password) {
  const res = await call('POST', '/auth/login', { body: { username, password } });
  if (res.status !== 200) throw new Error('вход ' + username + ': ' + res.status);
  return res.data;
}

async function run() {
  const admin = await login('admin', 'admin123');
  const librarian = await login('librarian', 'librarian123');
  const reader = await login('reader', 'reader123');
  const T = {
    admin: admin.accessToken,
    librarian: librarian.accessToken,
    reader: reader.accessToken,
  };

  console.log(`\nSmoke-тест ПР5: роли, пользователи, статистика  (${API})\n`);

  console.log('1. Регистрация');
  const suffix = String(Date.now()).slice(-6);
  const reg = await call('POST', '/auth/register-strict', {
    body: { username: 'user' + suffix, password: 'Passw0rd!', fullName: 'Новый читатель' },
  });
  check('register-strict -> 201', reg.status === 201, String(reg.status));
  check('новый пользователь получает роль reader', reg.data?.user?.role === 'reader');
  check('в ответе есть sessionTimeout', 'sessionTimeout' in (reg.data ?? {}));
  const newToken = reg.data?.accessToken;

  const weak = await call('POST', '/auth/register-strict', {
    body: { username: 'weak' + suffix, password: 'short' },
  });
  check('слабый пароль -> 422', weak.status === 422, String(weak.status));
  check('ошибка привязана к полю password', Boolean(weak.data?.errors?.password));

  console.log('\n2. Права на чтение');
  for (const role of ['admin', 'librarian', 'reader']) {
    const res = await call('GET', '/habits?size=5', { token: T[role] });
    check(role + ': список привычек -> 200', res.status === 200, String(res.status));
  }
  const anonymous = await call('GET', '/habits');
  check('без токена -> 401', anonymous.status === 401, String(anonymous.status));

  console.log('\n3. Права на изменение');
  const created = await call('POST', '/categories', {
    token: T.reader,
    body: { name: 'Читателю нельзя ' + suffix, description: 'проверка' },
  });
  check('reader создаёт категорию -> 403', created.status === 403, String(created.status));
  check('в сообщении указана роль', /читатель/.test(created.data?.message ?? ''), created.data?.message);

  const librarianCreate = await call('POST', '/categories', {
    token: T.librarian,
    body: { name: 'Редактор создаёт ' + suffix, description: 'проверка' },
  });
  check('librarian создаёт категорию -> 201', librarianCreate.status === 201, String(librarianCreate.status));
  const categoryId = librarianCreate.data?.id;

  const readerDelete = await call('DELETE', '/categories/' + categoryId, { token: T.reader });
  check('reader удаляет -> 403', readerDelete.status === 403, String(readerDelete.status));

  console.log('\n4. Безвозвратное удаление и восстановление');
  const soft = await call('DELETE', '/categories/' + categoryId, { token: T.librarian });
  check('librarian мягко удаляет -> 204', soft.status === 204, String(soft.status));

  const restoreLibrarian = await call('POST', '/categories/' + categoryId + '/restore', {
    token: T.librarian,
  });
  check('librarian восстанавливает -> 403', restoreLibrarian.status === 403, String(restoreLibrarian.status));

  const hardLibrarian = await call('DELETE', '/categories/' + categoryId + '?hard=true', {
    token: T.librarian,
  });
  check('librarian hard delete -> 403', hardLibrarian.status === 403, String(hardLibrarian.status));

  const bulkHard = await call('POST', '/categories/bulk-delete', {
    token: T.librarian,
    body: { ids: [categoryId], hard: true },
  });
  check('librarian bulk hard -> 403', bulkHard.status === 403, String(bulkHard.status));

  const restoreAdmin = await call('POST', '/categories/' + categoryId + '/restore', {
    token: T.admin,
  });
  check('admin восстанавливает -> 200', restoreAdmin.status === 200, String(restoreAdmin.status));
  check('после восстановления deletedAt = null', restoreAdmin.data?.deletedAt === null);

  const hardAdmin = await call('DELETE', '/categories/' + categoryId + '?hard=true', {
    token: T.admin,
  });
  check('admin hard delete -> 204', hardAdmin.status === 204, String(hardAdmin.status));
  const gone = await call('GET', `/categories/${categoryId}?includeDeleted=true`, {
    token: T.admin,
  });
  check('после hard delete запись недоступна -> 404', gone.status === 404, String(gone.status));

  console.log('\n5. Пользователи и роли');
  const usersAsReader = await call('GET', '/users', { token: T.reader });
  check('reader: /users -> 403', usersAsReader.status === 403, String(usersAsReader.status));

  const usersAsAdmin = await call('GET', '/users', { token: T.admin });
  check('admin: /users -> 200', usersAsAdmin.status === 200, String(usersAsAdmin.status));
  const roles = new Set((usersAsAdmin.data?.items ?? []).map((u) => u.role));
  check('в списке есть три роли', roles.size >= 3, [...roles].join(','));

  const promote = await call('PUT', '/users/' + reg.data.user.id + '/role', {
    token: T.admin,
    body: { role: 'librarian' },
  });
  check('admin меняет роль -> 200', promote.status === 200, String(promote.status));
  check('роль обновилась', promote.data?.role === 'librarian');

  const promoteAsLibrarian = await call('PUT', '/users/' + reg.data.user.id + '/role', {
    token: T.librarian,
    body: { role: 'admin' },
  });
  check('librarian меняет роль -> 403', promoteAsLibrarian.status === 403, String(promoteAsLibrarian.status));

  const badRole = await call('PUT', '/users/' + reg.data.user.id + '/role', {
    token: T.admin,
    body: { role: 'superuser' },
  });
  check('неизвестная роль -> 422', badRole.status === 422, String(badRole.status));

  const selfDemote = await call('PUT', '/users/1/role', {
    token: T.admin,
    body: { role: 'reader' },
  });
  check('нельзя понизить самого себя -> 409', selfDemote.status === 409, String(selfDemote.status));

  const deleteSelf = await call('DELETE', '/users/1', { token: T.admin });
  check('нельзя удалить самого себя -> 409', deleteSelf.status === 409, String(deleteSelf.status));

  const deleteNew = await call('DELETE', '/users/' + reg.data.user.id, { token: T.admin });
  check('admin удаляет пользователя -> 204', deleteNew.status === 204, String(deleteNew.status));

  const afterDelete = await call('GET', '/users', { token: T.admin });
  const stillThere = (afterDelete.data?.items ?? []).some(
    (u) => u.id === reg.data.user.id && !u.deletedAt,
  );
  check('удалённого пользователя нет в списке', !stillThere);

  const meAfterDelete = await call('GET', '/auth/me', { token: newToken });
  check('удалённый пользователь не проходит /auth/me -> 401', meAfterDelete.status === 401, String(meAfterDelete.status));

  const tokenAfterDelete = await call('GET', '/habits?size=1', { token: newToken });
  check('токен удалённого пользователя отозван -> 401', tokenAfterDelete.status === 401, String(tokenAfterDelete.status));

  console.log('\n6. Статистика');
  const statsReader = await call('GET', '/stats', { token: T.reader });
  check('reader: /stats -> 403', statsReader.status === 403, String(statsReader.status));
  const statsAdmin = await call('GET', '/stats', { token: T.admin });
  check('admin: /stats -> 200', statsAdmin.status === 200, String(statsAdmin.status));
  check('есть суммарные минуты', typeof statsAdmin.data?.totalMinutes === 'number');
  check('есть разрез по профилям', Array.isArray(statsAdmin.data?.perProfile));
  check('есть разрез по категориям', Array.isArray(statsAdmin.data?.perCategory));

  console.log('\n7. Жизненный цикл токена');
  const reader2 = await login('reader', 'reader123');

  const forged = await call('GET', '/habits?size=1', { token: 'eyJzdWIiOjF9.bad' });
  check('поддельный токен -> 401', forged.status === 401, String(forged.status));

  const refreshed = await call('POST', '/auth/refresh', {
    body: { refreshToken: reader2.refreshToken },
  });
  check('refresh -> 200 с новым токеном', refreshed.status === 200, String(refreshed.status));
  check('новый access-токен отличается', refreshed.data?.accessToken !== reader2.accessToken);

  const reused = await call('POST', '/auth/refresh', {
    body: { refreshToken: reader2.refreshToken },
  });
  check('повторное использование refresh-токена -> 401', reused.status === 401, String(reused.status));

  const newReader = await call('GET', '/habits?size=1', {
    token: refreshed.data.accessToken,
  });
  check('новый токен работает', newReader.status === 200, String(newReader.status));

  const logout = await call('POST', '/auth/logout', {
    body: { refreshToken: refreshed.data.refreshToken },
  });
  check('logout -> 204', logout.status === 204, String(logout.status));
  const afterLogout = await call('POST', '/auth/refresh', {
    body: { refreshToken: refreshed.data.refreshToken },
  });
  check('после logout refresh не работает -> 401', afterLogout.status === 401, String(afterLogout.status));

  const me = await call('GET', '/auth/me', { token: T.reader });
  check('/auth/me возвращает роль', me.data?.role === 'reader', me.data?.role);

  console.log('');
  console.log('Итого: пройдено ' + passed + ', провалено ' + failed);
  return failed === 0;
}

const server = spawn(
  process.execPath,
  [path.join(here, 'mock-server.js'), '--port', String(PORT), '--origin', ORIGIN, '--ttl', '900', '--session', '30'],
  { stdio: ['ignore', 'pipe', 'pipe'] },
);

const ready = new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error('сервер не поднялся')), 15000);
  server.stdout.on('data', (chunk) => {
    if (chunk.toString().includes('Mock API')) {
      clearTimeout(timer);
      resolve();
    }
  });
  server.on('exit', (code) => reject(new Error('сервер завершился: ' + code)));
});

ready
  .then(run)
  .then((ok) => {
    server.kill();
    process.exit(ok ? 0 : 1);
  })
  .catch((error) => {
    console.error('Ошибка:', error.message);
    server.kill();
    process.exit(1);
  });
