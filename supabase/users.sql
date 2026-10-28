/* Создание демо-пользователей «Трекера привычек» в Supabase.
   Выполнять в Supabase → SQL Editor → New query → вставить → Run.
   Пароли: admin123, librarian123, reader123.
   Повторный запуск безопасен: существующие пользователи пропускаются. */

create extension if not exists pgcrypto;

do $$
declare
  accounts text[][] := array[
    ['admin@habit.local',     'admin123',     'admin',     'Администратор', null],
    ['librarian@habit.local', 'librarian123', 'librarian', 'Редактор',      null],
    ['reader@habit.local',    'reader123',    'reader',    'Читатель',      1]
  ];
  item text[];
  new_id uuid;
begin
  foreach item slice 1 in array accounts loop
    select id into new_id from auth.users where email = item[1];

    if new_id is null then
      new_id := gen_random_uuid();

      insert into auth.users (
        id, instance_id, aud, role, email, encrypted_password,
        email_confirmed_at, created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data,
        confirmation_token, recovery_token, email_change_token_new, email_change
      ) values (
        new_id,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        item[1],
        crypt(item[2], gen_salt('bf')),
        now(), now(), now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('username', split_part(item[1], '@', 1), 'full_name', item[4]),
        '', '', '', ''
      );

      insert into auth.identities (
        id, user_id, provider_id, provider, identity_data,
        last_sign_in_at, created_at, updated_at
      ) values (
        gen_random_uuid(),
        new_id,
        new_id::text,
        'email',
        jsonb_build_object('sub', new_id::text, 'email', item[1], 'email_verified', true),
        now(), now(), now()
      );
    end if;

    -- роль и привязка к профилю
    update public.app_users
       set role = item[3],
           profile_id = item[5]::integer
     where id = new_id;
  end loop;
end $$;

select u.email, p.username, p.role, p.profile_id
  from auth.users u
  join public.app_users p on p.id = u.id
 order by p.role desc;
