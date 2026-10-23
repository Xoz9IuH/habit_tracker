# Контракт учебного API «Трекер привычек»

Документ описывает сервер `server/mock-server.js`, с которым работает клиент ПР4.
Базовый адрес по умолчанию: `http://localhost:8080/api`.

---

## 1. Общие соглашения

- Формат обмена — JSON, кодировка UTF-8.
- Заголовок `Content-Type: application/json` обязателен для запросов с телом.
- Идентификаторы целочисленные, начинаются с 1 и назначаются сервером.
- Даты и моменты времени передаются строкой ISO 8601: `2026-10-18T00:00:00.000Z`.
- Удаление мягкое: запись получает `deletedAt`, остаётся в базе и может быть восстановлена.
- Физическое удаление (`?hard=true`) доступно только роли `admin`.

### 1.1. Оболочка списка

```json
{
  "items": [],
  "page": 1,
  "size": 10,
  "total": 15,
  "totalPages": 2
}
```

### 1.2. Формат ошибки

| Код | Смысл | Тело |
|---|---|---|
| 400 | Некорректный запрос, битый JSON | `{ "message": "..." }` |
| 401 | Нет токена либо срок действия истёк | `{ "message": "..." }` |
| 403 | Роль не позволяет операцию | `{ "message": "..." }` |
| 404 | Запись не найдена | `{ "message": "..." }` |
| 409 | Нарушено ограничение целостности | `{ "message": "..." }` |
| 422 | Ошибки валидации по полям | `{ "message": "...", "errors": { "поле": "текст" } }` |
| 500 | Внутренняя ошибка / учебный `?__fail` | `{ "message": "..." }` |

Ключи `errors` совпадают с именами полей модели (`name`, `email`, `code`, `profileId` и т. д.), поэтому клиент показывает сообщение под нужным полем формы.

---

## 2. Авторизация и роли

| Метод | Адрес | Назначение |
|---|---|---|
| POST | `/auth/login` | Вход по логину и паролю |
| POST | `/auth/refresh` | Обновление пары токенов |
| POST | `/auth/logout` | Отзыв refresh-токена |
| GET | `/auth/me` | Текущий пользователь |
| POST | `/auth/register` | Регистрация читателя |
| GET | `/users` | Список пользователей (только admin) |

Вход:

```http
POST /api/auth/login
{ "username": "admin", "password": "admin123" }
```

Ответ:

```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "expiresIn": 900,
  "tokenType": "Bearer",
  "user": { "id": 1, "username": "admin", "fullName": "Администратор", "role": "admin" }
}
```

Все запросы к данным, кроме `/__health`, `/auth/login`, `/auth/refresh`, требуют заголовок
`Authorization: Bearer <accessToken>`.

| Роль | Чтение | Создание и изменение | Мягкое удаление, восстановление | Безвозвратное удаление |
|---|---|---|---|---|
| `reader` | да | нет (403) | нет (403) | нет (403) |
| `librarian` | да | да | да | нет (403) |
| `admin` | да | да | да | да |

Учётные записи: `admin/admin123`, `librarian/librarian123`, `reader/reader123`.
Access-токен живёт 900 секунд, refresh-токен — 7 суток. При истечении access-токена клиент один раз вызывает `/auth/refresh` и повторяет запрос.

---

## 3. Коллекции

`categories`, `tags`, `profiles`, `habits`, `check_ins`, `coupons`.

| Метод | Адрес | Права | Ответ |
|---|---|---|---|
| GET | `/{collection}` | любая роль | 200, оболочка списка |
| GET | `/{collection}/{id}?includeDeleted=true` | любая роль | 200 / 404 |
| POST | `/{collection}` | librarian, admin | 201, созданный объект |
| PUT | `/{collection}/{id}` | librarian, admin | 200, изменённый объект |
| DELETE | `/{collection}/{id}` | librarian, admin | 204 (мягкое удаление) |
| DELETE | `/{collection}/{id}?hard=true` | admin | 204 |
| POST | `/{collection}/{id}/restore` | librarian, admin | 200, восстановленный объект |
| POST | `/{collection}/bulk-delete` | librarian, admin | 200, `{ "deleted": n }` |

`bulk-delete` принимает `{ "ids": [1, 2, 3] }` и `{ "hard": true }` (только admin).

---

## 4. Параметры списка

| Параметр | Значение |
|---|---|
| `search` | Подстрока поиска без учёта регистра |
| `sort` | `поле,asc` или `поле,desc` |
| `page` | Номер страницы, с 1 |
| `size` | Размер страницы, 1–100 (по умолчанию 10) |
| `includeDeleted` | `true` — включить записи из корзины |

Поля поиска и сортировки:

| Коллекция | Поиск | Сортировка | Фильтры |
|---|---|---|---|
| `categories` | `name`, `description` | `id`, `name`, `description` | — |
| `tags` | `name`, `color` | `id`, `name`, `color` | `categoryId` |
| `profiles` | `name`, `email`, `city` | `id`, `name`, `email`, `city` | `city` |
| `habits` | `name`, `goal` | `id`, `name`, `goal`, `minutes`, `streak` | `categoryId`, `periodicityId`, `profileId`, `tagId`, `streakFrom`, `streakTo` |
| `check_ins` | `note` | `id`, `date`, `minutes` | `habitId`, `profileId`, `dateFrom`, `dateTo` |
| `coupons` | `code` | `id`, `code`, `discount` | `profileId`, `discountFrom`, `discountTo` |

---

## 5. Модели

### Category

```json
{ "id": 1, "name": "Спорт", "description": "Физическая активность", "deletedAt": null }
```

### Tag

```json
{ "id": 3, "name": "здоровье", "color": "зелёный", "categoryId": 2, "deletedAt": null }
```

### Profile

```json
{
  "id": 1,
  "name": "Олег Бундович",
  "email": "oleg@example.com",
  "city": "Москва",
  "dailyGoalMinutes": 120,
  "remindersEnabled": true,
  "couponId": 1,
  "deletedAt": null,
  "coupon": { "id": 1, "profileId": 1, "code": "START-20", "discountPercent": 20, "expiresAt": "..." }
}
```

### Habit

```json
{
  "id": 1,
  "name": "Утренняя зарядка",
  "goal": "Все 7 дней в неделю",
  "categoryId": 1,
  "periodicityId": 1,
  "minutesPerDay": 15,
  "streak": 42,
  "profileId": 1,
  "tagIds": [1, 7],
  "deletedAt": null,
  "category": { "id": 1, "name": "Спорт" },
  "profile": { "id": 1, "name": "Олег Бундович", "email": "...", "city": "Москва" },
  "tags": [{ "id": 1, "name": "утро", "color": "оранжевый" }]
}
```

### CheckIn

```json
{
  "id": 1,
  "habitId": 1,
  "profileId": 1,
  "date": "2026-10-18T00:00:00.000Z",
  "minutes": 15,
  "completed": true,
  "note": "Легко вышло",
  "deletedAt": null,
  "habit": { "id": 1, "name": "Утренняя зарядка", "goal": "..." },
  "profile": { "id": 1, "name": "Олег Бундович", "email": "...", "city": "Москва" }
}
```

### Coupon

```json
{
  "id": 1,
  "profileId": 1,
  "code": "START-20",
  "discountPercent": 20,
  "expiresAt": "2026-12-31T00:00:00.000Z",
  "deletedAt": null,
  "profile": { "id": 1, "name": "Олег Бундович", "email": "...", "city": "Москва" }
}
```

**Связи.** Запись содержит и идентификатор связи (`categoryId`, `profileId`, `tagIds`), и развёрнутый объект (`category`, `profile`, `tags`, `coupon`). Идентификатор нужен для отправки формы, развёрнутый объект — для чтения. Связь «профиль ↔ купон» — один к одному: сервер сам проставляет `Profile.couponId` при создании купона и снимает его при удалении.

---

## 6. Правила валидации (422)

| Коллекция | Поле | Правило |
|---|---|---|
| categories | `name` | Обязательно, до 60 символов, уникально |
| | `description` | Обязательно, до 200 символов |
| tags | `name` | Обязательно, до 40 символов, уникально |
| | `color` | Обязательно |
| | `categoryId` | Если задан — категория должна существовать |
| profiles | `name` | Обязательно, до 60 символов |
| | `email` | Обязательно, корректный адрес, уникален |
| | `city` | Обязательно, до 60 символов |
| | `dailyGoalMinutes` | Целое от 1 до 1440 |
| | `couponId` | Если задан — купон существует и принадлежит профилю |
| habits | `name` | Обязательно, до 80 символов, уникально |
| | `goal` | Обязательно, до 200 символов |
| | `categoryId` | Категория должна существовать |
| | `periodicityId` | От 1 до 5 |
| | `profileId` | Профиль должен существовать |
| | `minutesPerDay` | 0–600 |
| | `streak` | 0–3650 |
| | `tagIds` | Все теги должны существовать |
| check_ins | `habitId`, `profileId` | Должны существовать |
| | `date` | Обязательна, корректная дата |
| | `minutes` | 0–1440 |
| | `note` | До 200 символов |
| coupons | `code` | Обязателен, `A-Z0-9-`, 4–20 символов, уникален |
| | `discountPercent` | 1–100 |
| | `expiresAt` | Обязательна, корректная дата |
| | `profileId` | Должен существовать, у профиля ещё нет купона |

---

## 7. Ограничения целостности (409)

| Операция | Условие |
|---|---|
| Удаление категории | Есть активные привычки этой категории |
| Удаление тега | Тег используется в привычках |
| Удаление профиля | Есть привычки, отметки или купон |
| Удаление привычки | Есть отметки (check_ins) |
| Создание отметки | Отметка этой привычки за эту дату уже есть |

`bulk-delete` переносит записи в корзину без проверки ссылок: операция обратима, а восстанавливаются записи по одной.

---

## 8. Служебные возможности

| Приём | Поведение |
|---|---|
| `GET /api/__health` | `{ "status": "ok", "counts": { ... } }` |
| `POST /api/__reset` | Возвращает исходные данные |
| `?__delay=1500` | Задерживает ответ на 1,5 с — для демонстрации индикатора загрузки |
| `?__fail=500` | Немедленно отвечает ошибкой с указанным кодом |

Параметры действуют на любой запрос, включая POST и DELETE, и применяются до обработки маршрута.

---

## 9. CORS

Сервер отвечает заголовками:

```http
Access-Control-Allow-Origin: http://localhost:5555
Access-Control-Allow-Methods: GET,POST,PUT,PATCH,DELETE,OPTIONS
Access-Control-Allow-Headers: Content-Type,Authorization
```

Origin задаётся при запуске: `--origin http://localhost:5555`. Клиент обязан работать на этом же порту (`flutter run -d chrome --web-port=5555`), иначе браузер отклонит запрос. Preflight `OPTIONS` обрабатывается до проверки токена и всегда отвечает 204.

---

## 10. Примеры

```bash
curl http://localhost:8080/api/__health

curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

curl "http://localhost:8080/api/habits?search=вод&sort=streak,desc&page=1&size=5" \
  -H "Authorization: Bearer <accessToken>"

curl -X POST http://localhost:8080/api/habits \
  -H "Authorization: Bearer <accessToken>" \
  -H "Content-Type: application/json" \
  -d '{"name":"Новая привычка","goal":"Цель","categoryId":1,"periodicityId":1,"minutesPerDay":10,"streak":0,"profileId":1,"tagIds":[1]}'

curl -X DELETE "http://localhost:8080/api/habits/15" -H "Authorization: Bearer <accessToken>"
curl -X POST "http://localhost:8080/api/habits/15/restore" -H "Authorization: Bearer <accessToken>"
curl "http://localhost:8080/api/categories?__delay=1500" -H "Authorization: Bearer <accessToken>"
```
