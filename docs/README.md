# Отчёт ПР6 — материалы

Адаптивная вёрстка, релизная сборка и публикация трекера привычек.
Этот же проект оформлен как итоговая работа: `docs/Итоговая - соответствие
требованиям.md` и отчёт `Итоговая работа - трекер привычек.docx` в папке `ПР6`.

## Что лежит в папке

| Путь | Содержимое |
| --- | --- |
| `Отчёт ПР6 - адаптив, сборка и публикация.docx` | отчёт по практике (адаптив 360/768/1280/1920, сборка, публикация, тесты) |
| `Итоговая - соответствие требованиям.md` | сверка проекта с требованиями итоговой работы |
| `screenshots/` | снимки экранов: заставка, вход, списки и главная на четырёх ширинах, офлайн-режим, тёмная тема |

Итоговый отчёт лежит в корне рабочей папки: `Итоговая работа - трекер привычек.docx`.

## Как запустить

**Ссылка на опубликованное приложение:**
<https://xoz9iuh.github.io/habit_tracker/>

Демо-аккаунты (данные в Supabase): `admin@habit.local / admin123`,
`librarian@habit.local / librarian123`, `reader@habit.local / reader123`.

Локально можно работать с учебным сервером:

```bash
# учебный сервер с данными и REST-API
node server-www/mock-server.js --port 8080

# клиент в браузере
flutter run -d chrome --web-port=5555 --dart-define=API_BASE_URL=http://localhost:8080/api
```

## Как собрать релиз

```bash
flutter build web --release --base-href /habit_tracker/
```

## Облачный режим (Supabase)

Клиент выбирает источник данных сам:

- заданы `SUPABASE_URL` и `SUPABASE_ANON_KEY` — работает `PostgREST` и `auth/v1`,
  роли берутся из таблицы `app_users`, права проверяет RLS на сервере;
- параметры не заданы — работает учебный сервер из `server-www`.

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://<проект>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

SQL для создания схемы, данных и пользователей лежит в `supabase/`:
`01-schema.sql`, `02-data.sql`, `02-users.sql`.

## Проверки

```bash
flutter analyze
dart format --set-exit-if-changed lib test
flutter test
```
