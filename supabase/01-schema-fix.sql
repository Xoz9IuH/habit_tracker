/* Догоняющий скрипт: дописывает недостающие политики доступа.
   Нужен, если основной скрипт остановился на ошибке «policy already exists».
   SQL Editor → вставить целиком → Run. Повторный запуск безопасен. */

drop policy if exists categories_read on public.categories;
drop policy if exists categories_write on public.categories;
drop policy if exists tags_read on public.tags;
drop policy if exists tags_write on public.tags;
drop policy if exists profiles_read on public.profiles;
drop policy if exists profiles_write on public.profiles;
drop policy if exists habits_read on public.habits;
drop policy if exists habits_write on public.habits;
drop policy if exists habit_tags_read on public.habit_tags;
drop policy if exists habit_tags_write on public.habit_tags;
drop policy if exists check_ins_read on public.check_ins;
drop policy if exists check_ins_write on public.check_ins;
drop policy if exists coupons_read on public.coupons;
drop policy if exists coupons_write on public.coupons;
drop policy if exists app_users_read_own on public.app_users;
drop policy if exists app_users_read_admin on public.app_users;
drop policy if exists app_users_update_admin on public.app_users;
drop policy if exists app_users_delete_admin on public.app_users;

alter table public.categories enable row level security;
alter table public.tags       enable row level security;
alter table public.profiles   enable row level security;
alter table public.habits     enable row level security;
alter table public.habit_tags enable row level security;
alter table public.check_ins  enable row level security;
alter table public.coupons    enable row level security;
alter table public.app_users  enable row level security;

create policy categories_read on public.categories
  for select to authenticated using (true);
create policy categories_write on public.categories
  for all to authenticated
  using (public.app_role() in ('librarian', 'admin'))
  with check (public.app_role() in ('librarian', 'admin'));

create policy tags_read on public.tags
  for select to authenticated using (true);
create policy tags_write on public.tags
  for all to authenticated
  using (public.app_role() in ('librarian', 'admin'))
  with check (public.app_role() in ('librarian', 'admin'));

create policy profiles_read on public.profiles
  for select to authenticated using (true);
create policy profiles_write on public.profiles
  for all to authenticated
  using (public.app_role() in ('librarian', 'admin'))
  with check (public.app_role() in ('librarian', 'admin'));

create policy habits_read on public.habits
  for select to authenticated using (true);
create policy habits_write on public.habits
  for all to authenticated
  using (public.app_role() in ('librarian', 'admin'))
  with check (public.app_role() in ('librarian', 'admin'));

create policy habit_tags_read on public.habit_tags
  for select to authenticated using (true);
create policy habit_tags_write on public.habit_tags
  for all to authenticated
  using (public.app_role() in ('librarian', 'admin'))
  with check (public.app_role() in ('librarian', 'admin'));

create policy check_ins_read on public.check_ins
  for select to authenticated using (true);
create policy check_ins_write on public.check_ins
  for all to authenticated
  using (public.app_role() in ('librarian', 'admin'))
  with check (public.app_role() in ('librarian', 'admin'));

create policy coupons_read on public.coupons
  for select to authenticated using (true);
create policy coupons_write on public.coupons
  for all to authenticated
  using (public.app_role() in ('librarian', 'admin'))
  with check (public.app_role() in ('librarian', 'admin'));

create policy app_users_read_own on public.app_users
  for select to authenticated using (id = auth.uid() and deleted_at is null);
create policy app_users_read_admin on public.app_users
  for select to authenticated using (public.app_role() = 'admin');
create policy app_users_update_admin on public.app_users
  for update to authenticated
  using (public.app_role() = 'admin')
  with check (public.app_role() = 'admin');
create policy app_users_delete_admin on public.app_users
  for delete to authenticated
  using (public.app_role() = 'admin' and id <> auth.uid());

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

select schemaname, tablename, policyname
  from pg_policies
 where schemaname = 'public'
 order by tablename, policyname;
