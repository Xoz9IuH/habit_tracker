/* Пользователи «Трекера привычек» — одним запросом, без DO-блока.
   SQL Editor → вставить целиком → Run. Повторный запуск безопасен. */

create extension if not exists pgcrypto;

insert into auth.users (
  id, instance_id, aud, role, email,
  encrypted_password, email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  v.id,
  '00000000-0000-0000-0000-000000000000'::uuid,
  'authenticated',
  'authenticated',
  v.email,
  crypt(v.password, gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('username', v.username, 'full_name', v.full_name),
  '', '', '', ''
from (values
  (gen_random_uuid(), 'admin',     'admin@habit.local',     'admin123',     'Администратор'),
  (gen_random_uuid(), 'librarian', 'librarian@habit.local', 'librarian123', 'Редактор'),
  (gen_random_uuid(), 'reader',    'reader@habit.local',    'reader123',    'Читатель')
) as v(id, username, email, password, full_name)
where not exists (select 1 from auth.users u where u.email = v.email);

insert into auth.identities (
  id, user_id, provider_id, provider, identity_data,
  last_sign_in_at, created_at, updated_at
)
select
  gen_random_uuid(),
  u.id,
  u.id::text,
  'email',
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  now(), now(), now()
from auth.users u
where u.email in ('admin@habit.local', 'librarian@habit.local', 'reader@habit.local')
  and not exists (select 1 from auth.identities i where i.user_id = u.id);

insert into public.app_users (id, username, full_name, role, profile_id)
select
  u.id,
  split_part(u.email, '@', 1),
  coalesce(u.raw_user_meta_data ->> 'full_name', ''),
  case split_part(u.email, '@', 1)
    when 'admin' then 'admin'
    when 'librarian' then 'librarian'
    else 'reader'
  end,
  case when split_part(u.email, '@', 1) = 'reader' then 1 else null end
from auth.users u
where u.email in ('admin@habit.local', 'librarian@habit.local', 'reader@habit.local')
on conflict (id) do update
  set role = excluded.role,
      profile_id = excluded.profile_id,
      username = excluded.username;

select u.email, p.username, p.role, p.profile_id
  from auth.users u
  join public.app_users p on p.id = u.id
 order by p.role desc;
