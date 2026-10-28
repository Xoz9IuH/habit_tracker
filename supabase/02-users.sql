/* Демо-пользователи «Трекера привычек» (шаг 02 из 02)
   SQL Editor → вставить целиком → Run. Повторный запуск безопасен.

   Пароли: admin123, librarian123, reader123.
   Пользователи создаются в обход подтверждения почты, поэтому вход работает сразу. */

create extension if not exists pgcrypto;

do $$
declare
  accounts text[][] := array[
    ['admin',     'admin@habit.local',     'admin123',     'admin',     'Администратор', null],
    ['librarian', 'librarian@habit.local', 'librarian123', 'librarian', 'Редактор',      null],
    ['reader',    'reader@habit.local',    'reader123',    'reader',    'Читатель',      1]
  ];
  item text[];
  account_id uuid;
begin
  foreach item slice 1 in array accounts loop
    select id into account_id from auth.users where email = item[2];

    if account_id is null then
      account_id := gen_random_uuid();

      insert into auth.users (
        id, instance_id, aud, role, email,
        encrypted_password, email_confirmed_at, created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data,
        confirmation_token, recovery_token, email_change_token_new, email_change
      ) values (
        account_id,
        '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', item[2],
        crypt(item[3], gen_salt('bf')),
        now(), now(), now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('username', item[1], 'full_name', item[5]),
        '', '', '', ''
      );

      insert into auth.identities (
        id, user_id, provider_id, provider, identity_data,
        last_sign_in_at, created_at, updated_at
      ) values (
        gen_random_uuid(), account_id, account_id::text, 'email',
        jsonb_build_object(
          'sub', account_id::text,
          'email', item[2],
          'email_verified', true
        ),
        now(), now(), now()
      );
    end if;

    insert into public.app_users (id, username, full_name, role, profile_id)
    values (account_id, item[1], item[5], 'reader', null)
    on conflict (id) do nothing;

    update public.app_users
       set username = item[1],
           role = item[4],
           profile_id = item[6]::integer
     where id = account_id;
  end loop;
end $$;

select u.email, p.username, p.role, p.profile_id
  from auth.users u
  join public.app_users p on p.id = u.id
 order by p.role desc;
