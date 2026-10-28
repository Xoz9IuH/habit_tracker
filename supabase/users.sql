/* Схема, демо-данные и пользователи для проекта «Трекер привычек».
   Выполнять в Supabase → SQL Editor по частям:

   1) migrations/20261029090000_init.sql — таблицы, роли, защита записей;
   2) seed.sql — справочники, привычки, отметки, купоны;
   3) секция «Пользователи» ниже — после того как создадите их в Authentication.

   Пароли по умолчанию: admin123, librarian123, reader123.
   Роли выдаются только через эту секцию: записывать свою роль из браузера нельзя. */

-- ===================================================== Пользователи
-- Внимание: auth.users доступна только в SQL Editor (service_role).
-- Замените пароли, если создаёте пользователей вручную в Authentication → Users.

create extension if not exists pgcrypto;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at)
values
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'admin@habit.local', crypt('admin123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}',
   '{"username":"admin","full_name":"Администратор"}', now(), now()),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'librarian@habit.local', crypt('librarian123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}',
   '{"username":"librarian","full_name":"Редактор"}', now(), now()),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'reader@habit.local', crypt('reader123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}',
   '{"username":"reader","full_name":"Читатель"}', now(), now());

-- Профили в public.app_users создаёт триггер handle_new_user.
-- Здесь выдаём роли и связываем читателя с демо-профилем.
update public.app_users set role = 'admin'     where lower(username) = 'admin';
update public.app_users set role = 'librarian' where lower(username) = 'librarian';
update public.app_users set role = 'reader', profile_id = 1 where lower(username) = 'reader';

select username, full_name, role from public.app_users order by role desc;
