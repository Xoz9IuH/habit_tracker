/* Демо-данные «Трекер привычек»: справочники, привычки, отметки, купоны.
   Выполнять после миграции схемы: Supabase → SQL Editor → вставить и Run. */

insert into public.categories (id, name, description) values
  (1, 'Спорт', 'Зарядка, бег и тренировки'),
  (2, 'Здоровье', 'Сон, вода и питание'),
  (3, 'Обучение', 'Чтение, языки и курсы'),
  (4, 'Творчество', 'Рисование и музыка'),
  (5, 'Продуктивность', 'Планы и ритуалы'),
  (6, 'Быт', 'Домашние дела')
on conflict (id) do nothing;

select setval('public.categories_id_seq', greatest(6, (select max(id) from public.categories)));

insert into public.tags (id, name, color, category_id) values
  (1, 'утро', 'amber', 1),
  (2, 'вечер', 'indigo', 2),
  (3, 'здоровье', 'green', 2),
  (4, 'учёба', 'blue', 3),
  (5, 'сложное', 'red', 1),
  (6, 'быстро', 'teal', 6),
  (7, 'ритуал', 'purple', 5),
  (8, 'творчество', 'pink', 4)
on conflict (id) do nothing;

select setval('public.tags_id_seq', greatest(8, (select max(id) from public.tags)));

insert into public.profiles (id, name, email, city, daily_goal_minutes, reminders_enabled) values
  (1, 'Олег Бундович', 'oleg@example.com', 'Москва', 120, true),
  (2, 'Мария Петрова', 'maria@example.com', 'Казань', 90, false),
  (3, 'Иван Сидоров', 'ivan@example.com', 'Тула', 60, true)
on conflict (id) do nothing;

select setval('public.profiles_id_seq', greatest(3, (select max(id) from public.profiles)));

insert into public.habits (id, name, goal, category_id, periodicity_id, minutes_per_day, streak, profile_id) values
  (1, 'Утренняя зарядка', 'Все 7 дней в неделю', 1, 1, 15, 42, 1),
  (2, 'Пробежка 5 км', 'Три раза в неделю', 1, 1, 35, 12, 1),
  (3, '8 стаканов воды', 'Каждый день', 2, 1, 5, 49, 1),
  (4, 'День без сахара', 'Каждый день', 2, 1, 10, 15, 3),
  (5, 'Отбой до 23:00', 'Каждый день', 2, 1, 0, 6, 1),
  (6, 'Английский по 20 минут', 'Каждый день', 3, 1, 20, 35, 2),
  (7, 'Чтение 30 страниц', 'Каждый день', 3, 1, 30, 21, 1),
  (8, 'Изучение Dart', 'Каждый день', 3, 1, 45, 11, 1),
  (9, 'Скетчинг', 'Два раза в неделю', 4, 2, 40, 9, 2),
  (10, 'Медитация 10 минут', 'Каждый день', 5, 1, 10, 63, 2),
  (11, 'Дневник благодарности', 'Каждый день', 5, 1, 5, 17, 1),
  (12, 'План на завтра', 'Каждый день', 5, 1, 10, 28, 1),
  (13, 'Силовая тренировка', 'Два раза в неделю', 1, 1, 60, 8, 3),
  (14, 'Порядок на столе', 'Каждый день', 6, 1, 5, 33, 1),
  (15, 'Полив растений', 'Раз в три дня', 6, 2, 5, 14, 2)
on conflict (id) do nothing;

select setval('public.habits_id_seq', greatest(15, (select max(id) from public.habits)));

insert into public.habit_tags (habit_id, tag_id) values
  (1, 1), (1, 6), (2, 1), (2, 5), (3, 3), (3, 6), (4, 3), (5, 2), (5, 3),
  (6, 4), (7, 2), (7, 4), (8, 4), (8, 5), (9, 2), (9, 8), (10, 2), (10, 7),
  (11, 2), (11, 7), (12, 2), (13, 5), (14, 6), (15, 6)
on conflict do nothing;

insert into public.check_ins (id, habit_id, profile_id, date, minutes, completed, note) values
  (1, 1, 1, '2026-10-18', 15, true, 'Утро, бодро'),
  (2, 1, 1, '2026-10-19', 15, true, ''),
  (3, 2, 1, '2026-10-20', 35, true, 'Парк'),
  (4, 3, 1, '2026-10-19', 5, true, ''),
  (5, 4, 2, '2026-10-20', 10, true, ''),
  (6, 5, 2, '2026-10-18', 0, false, 'Не получилось'),
  (7, 6, 3, '2026-10-20', 20, true, 'Приложение'),
  (8, 7, 3, '2026-10-21', 30, true, ''),
  (9, 8, 1, '2026-10-21', 45, true, 'Streams'),
  (10, 9, 1, '2026-10-19', 12, true, 'Тёплый приём'),
  (11, 10, 2, '2026-10-20', 40, true, 'Тишина'),
  (12, 11, 1, '2026-10-21', 5, false, '')
on conflict (id) do nothing;

select setval('public.check_ins_id_seq', greatest(12, (select max(id) from public.check_ins)));

insert into public.coupons (id, profile_id, code, discount_percent, expires_at) values
  (1, 1, 'START-20', 20, '2027-01-31'),
  (2, 2, 'READER-10', 10, '2027-03-31')
on conflict (id) do nothing;

select setval('public.coupons_id_seq', greatest(2, (select max(id) from public.coupons)));
