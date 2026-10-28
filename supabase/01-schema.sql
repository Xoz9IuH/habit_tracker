# Трекер привычек — схема Supabase (PostgreSQL)
# REST-API по этой схеме формируется PostgREST автоматически.

create extension if not exists pgcrypto;

create table if not exists public.categories (
  id          serial primary key,
  name        text not null,
  description text not null default '',
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  constraint categories_name_check check (char_length(name) between 2 and 40),
  constraint categories_description_check check (char_length(description) <= 200)
);

create unique index if not exists categories_name_key
  on public.categories (lower(name)) where deleted_at is null;

create table if not exists public.tags (
  id          serial primary key,
  name        text not null,
  color       text not null default 'blue',
  category_id integer references public.categories (id) on delete set null,
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  constraint tags_name_check check (char_length(name) between 2 and 30)
);

create unique index if not exists tags_name_key
  on public.tags (lower(name)) where deleted_at is null;

create table if not exists public.profiles (
  id                  serial primary key,
  name                text not null,
  email               text not null,
  city                text not null default '',
  daily_goal_minutes  integer not null default 60,
  reminders_enabled   boolean not null default true,
  created_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  constraint profiles_name_check check (char_length(name) between 2 and 60),
  constraint profiles_email_check check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  constraint profiles_city_check check (char_length(city) <= 60),
  constraint profiles_goal_check check (daily_goal_minutes between 1 and 1440)
);

create unique index if not exists profiles_email_key
  on public.profiles (lower(email)) where deleted_at is null;

create table if not exists public.habits (
  id                serial primary key,
  name              text not null,
  goal              text not null default '',
  category_id       integer not null references public.categories (id) on delete restrict,
  periodicity_id    integer not null default 1,
  minutes_per_day   integer not null default 0,
  streak            integer not null default 0,
  profile_id        integer not null references public.profiles (id) on delete restrict,
  created_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  constraint habits_name_check check (char_length(name) between 2 and 80),
  constraint habits_goal_check check (char_length(goal) <= 200),
  constraint habits_periodicity_check check (periodicity_id between 1 and 5),
  constraint habits_minutes_check check (minutes_per_day between 0 and 600),
  constraint habits_streak_check check (streak between 0 and 3650)
);

create unique index if not exists habits_name_key
  on public.habits (lower(name)) where deleted_at is null;

create index if not exists habits_category_idx on public.habits (category_id);
create index if not exists habits_profile_idx on public.habits (profile_id);

create table if not exists public.habit_tags (
  habit_id integer not null references public.habits (id) on delete cascade,
  tag_id   integer not null references public.tags (id) on delete cascade,
  primary key (habit_id, tag_id)
);

create table if not exists public.check_ins (
  id         serial primary key,
  habit_id   integer not null references public.habits (id) on delete cascade,
  profile_id integer not null references public.profiles (id) on delete restrict,
  date       date not null,
  minutes    integer not null default 0,
  completed  boolean not null default true,
  note       text not null default '',
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint check_ins_minutes_check check (minutes between 0 and 1440),
  constraint check_ins_note_check check (char_length(note) <= 200)
);

create unique index if not exists check_ins_habit_date_key
  on public.check_ins (habit_id, date) where deleted_at is null;

create table if not exists public.coupons (
  id               serial primary key,
  profile_id       integer not null unique references public.profiles (id) on delete cascade,
  code             text not null,
  discount_percent integer not null,
  expires_at       date not null,
  created_at       timestamptz not null default now(),
  deleted_at       timestamptz,
  constraint coupons_code_check check (code ~ '^[A-Z0-9-]{4,20}$'),
  constraint coupons_discount_check check (discount_percent between 1 and 100)
);

create unique index if not exists coupons_code_key
  on public.coupons (upper(code)) where deleted_at is null;

create table if not exists public.app_users (
  id         uuid primary key references auth.users (id) on delete cascade,
  username   text not null,
  full_name  text not null default '',
  role       text not null default 'reader',
  profile_id integer references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint app_users_role_check check (role in ('reader', 'librarian', 'admin'))
);

create unique index if not exists app_users_username_key
  on public.app_users (lower(username)) where deleted_at is null;

create or replace function public.app_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.app_users
   where id = auth.uid() and deleted_at is null
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uname text;
begin
  uname := coalesce(
    nullif(new.raw_user_meta_data ->> 'username', ''),
    split_part(new.email, '@', 1)
  );
  if exists (select 1 from public.app_users where lower(username) = lower(uname)) then
    uname := uname || '_' || substr(new.id::text, 1, 4);
  end if;
  insert into public.app_users (id, username, full_name, role)
  values (new.id, uname, coalesce(new.raw_user_meta_data ->> 'full_name', ''), 'reader');
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

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
