# Supabase для «Трекера привычек»

Проект: `https://zjybwwremloqklaodeot.supabase.co`

## Порядок (один раз, 5 минут)

1. Откройте проект → **SQL Editor** → **New query**.
2. Вставьте целиком `migrations/20261029090000_init.sql` → **Run**.
   Создаются таблицы привычек, тегов, категорий, профилей, отметок, купонов,
   таблица пользователей с ролями и правила доступа на уровне записей (RLS).
3. Новый запрос: вставьте `seed.sql` → **Run**.
   Загрузятся 15 привычек, 12 отметок, 6 категорий, 8 тегов, 3 профиля и 2 купона.
4. Новый запрос: вставьте `users.sql` → **Run**.
   Появятся три пользователя: `admin@habit.local` / `admin123`,
   `librarian@habit.local` / `librarian123`, `reader@habit.local` / `reader123`.
5. Project Settings → API → скопируйте **Project URL** и ключ **anon public**.

## Что получилось

| Шаг | Что делает |
|---|---|
| миграция | схема, роли `reader` / `librarian` / `admin`, защита записей |
| seed | демо-данные для скриншотов и проверки |
| users | три учётные записи и роли |

## Проверка

```sql
select count(*) from public.habits;      -- 15
select username, role from public.app_users; -- три пользователя
```

После шага 5 ключи передаются в сборку приложения:

```
flutter build web --release \
  --dart-define=SUPABASE_URL=https://zjybwwremloqklaodeot.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

Ключ `anon` публичный: он уходит в браузер, но без входа не даёт читать данные —
доступ закрыт правилами RLS, описанными в миграции.
