// Демонстрационные данные приложения.
// В ПР3 появились новые сущности: теги (многие ко многим с привычками),
// профили (один к одному с настройками) и отметки о выполнении.
import '../models/category.dart';
import '../models/check_in.dart';
import '../models/habit.dart';
import '../models/profile.dart';
import '../models/tag.dart';

class Periodicity {
  final int id;
  final String name;
  const Periodicity(this.id, this.name);
}

const List<Periodicity> periodicities = [
  Periodicity(1, 'Ежедневно'),
  Periodicity(2, 'Через день'),
  Periodicity(3, '3 раза в неделю'),
  Periodicity(4, 'Еженедельно'),
  Periodicity(5, 'По будням'),
];

String periodicityName(int id) => periodicities
    .firstWhere((p) => p.id == id, orElse: () => const Periodicity(0, '?'))
    .name;

String categoryName(int id) => seedCategories
    .firstWhere((c) => c.id == id,
        orElse: () => const Category(id: 0, name: '?', description: ''))
    .name;

String tagName(int id) => seedTags
    .firstWhere((t) => t.id == id,
        orElse: () => const Tag(id: 0, name: '?'))
    .name;

String profileName(int id) => seedProfiles
    .firstWhere((p) => p.id == id,
        orElse: () => const Profile(
              id: 0,
              name: '?',
              email: '',
              city: '',
              dailyGoalMinutes: 0,
              remindersEnabled: false,
            ))
    .name;

String habitName(int id) => seedHabits
    .firstWhere((h) => h.id == id,
        orElse: () => const Habit(
              id: 0,
              name: '?',
              goal: '',
              categoryId: 0,
              periodicityId: 0,
              minutesPerDay: 0,
              streak: 0,
              profileId: 0,
            ))
    .name;

const List<Category> seedCategories = [
  Category(id: 1, name: 'Спорт', description: 'Физическая активность и выносливость'),
  Category(id: 2, name: 'Здоровье', description: 'Сон, питание и самочувствие'),
  Category(id: 3, name: 'Обучение', description: 'Чтение, языки и новые навыки'),
  Category(id: 4, name: 'Быт', description: 'Домашние дела и порядок'),
  Category(id: 5, name: 'Продуктивность', description: 'Фокус, планирование и ритуалы'),
  Category(id: 6, name: 'Творчество', description: 'Рисование, музыка и хобби'),
];

const List<Tag> seedTags = [
  Tag(id: 1, name: 'утро', color: 'оранжевый'),
  Tag(id: 2, name: 'вечер', color: 'фиолетовый'),
  Tag(id: 3, name: 'здоровье', color: 'зелёный', categoryId: 2),
  Tag(id: 4, name: 'дома', color: 'серый', categoryId: 4),
  Tag(id: 5, name: 'учёба', color: 'синий', categoryId: 3),
  Tag(id: 6, name: 'сложное', color: 'красный'),
  Tag(id: 7, name: 'быстро', color: 'зелёный'),
  Tag(id: 8, name: 'ритуал', color: 'серый', categoryId: 5),
];

const List<Profile> seedProfiles = [
  Profile(
    id: 1,
    name: 'Олег Бундович',
    email: 'oleg@example.com',
    city: 'Москва',
    dailyGoalMinutes: 120,
    remindersEnabled: true,
  ),
  Profile(
    id: 2,
    name: 'Мария Петрова',
    email: 'maria@example.com',
    city: 'Казань',
    dailyGoalMinutes: 60,
    remindersEnabled: false,
  ),
  Profile(
    id: 3,
    name: 'Иван Сидоров',
    email: 'ivan@example.com',
    city: 'Москва',
    dailyGoalMinutes: 90,
    remindersEnabled: true,
  ),
];

const List<Habit> seedHabits = [
  Habit(id: 1, name: 'Утренняя зарядка', goal: 'Все 7 дней в неделю', categoryId: 1, periodicityId: 1, minutesPerDay: 15, streak: 42, profileId: 1, tagIds: [1, 7]),
  Habit(id: 2, name: 'Пробежка 5 км', goal: 'Темп лучше 7:30 / км', categoryId: 1, periodicityId: 2, minutesPerDay: 35, streak: 12, profileId: 1, tagIds: [1, 6]),
  Habit(id: 3, name: 'Медитация 10 минут', goal: 'Спокойно досидеть таймер', categoryId: 5, periodicityId: 1, minutesPerDay: 10, streak: 63, profileId: 2, tagIds: [2, 8]),
  Habit(id: 4, name: 'Чтение 30 страниц', goal: '12 книг за год', categoryId: 3, periodicityId: 1, minutesPerDay: 30, streak: 21, profileId: 1, tagIds: [2, 5]),
  Habit(id: 5, name: 'Английский по 20 минут', goal: 'Уровень B2 к июню', categoryId: 3, periodicityId: 1, minutesPerDay: 20, streak: 35, profileId: 2, tagIds: [5]),
  Habit(id: 6, name: '8 стаканов воды', goal: 'Каждый день без напоминаний', categoryId: 2, periodicityId: 1, minutesPerDay: 5, streak: 49, profileId: 1, tagIds: [3, 7]),
  Habit(id: 7, name: 'Силовая тренировка', goal: '3 тренировки в неделю', categoryId: 1, periodicityId: 3, minutesPerDay: 60, streak: 8, profileId: 3, tagIds: [6]),
  Habit(id: 8, name: 'Дневник благодарности', goal: 'Три пункта каждый вечер', categoryId: 5, periodicityId: 1, minutesPerDay: 5, streak: 17, profileId: 1, tagIds: [2, 8]),
  Habit(id: 9, name: 'Уборка стола', goal: 'Рабочая зона пустая к вечеру', categoryId: 4, periodicityId: 4, minutesPerDay: 10, streak: 3, profileId: 2, tagIds: [4]),
  Habit(id: 10, name: 'Отбой до 23:00', goal: '7+ часов сна', categoryId: 2, periodicityId: 1, minutesPerDay: 0, streak: 6, profileId: 1, tagIds: [2, 3]),
  Habit(id: 11, name: 'День без сахара', goal: 'Не сладкого с понедельника', categoryId: 2, periodicityId: 1, minutesPerDay: 10, streak: 15, profileId: 3, tagIds: [3]),
  Habit(id: 12, name: 'Скетчинг', goal: 'Один набросок в два дня', categoryId: 6, periodicityId: 2, minutesPerDay: 40, streak: 9, profileId: 2, tagIds: [2]),
  Habit(id: 13, name: 'Изучение Dart', goal: 'Каждый будний день', categoryId: 3, periodicityId: 5, minutesPerDay: 45, streak: 11, profileId: 1, tagIds: [5, 6]),
  Habit(id: 14, name: 'Стирка и сортировка', goal: 'Бельё разложено в шкафу', categoryId: 4, periodicityId: 4, minutesPerDay: 25, streak: 2, profileId: 3, tagIds: [4]),
  // Привычка 15 удаляется репозиторием при старте — есть что восстановить.
  Habit(id: 15, name: 'Соцсети до обеда', goal: 'Отвыкнуть от утреннего скролла', categoryId: 4, periodicityId: 1, minutesPerDay: 10, streak: 0, profileId: 2, tagIds: [4]),
];

/// Отметки о выполнении: «многие к одному» к привычке и к профилю.
final List<CheckIn> seedCheckIns = [
  CheckIn(id: 1, habitId: 1, profileId: 1, date: DateTime(2026, 10, 18), minutes: 15, completed: true, note: 'Легко вышло'),
  CheckIn(id: 2, habitId: 1, profileId: 1, date: DateTime(2026, 10, 19), minutes: 15, completed: true, note: ''),
  CheckIn(id: 3, habitId: 6, profileId: 1, date: DateTime(2026, 10, 19), minutes: 5, completed: true, note: 'Все 8 стаканов'),
  CheckIn(id: 4, habitId: 4, profileId: 1, date: DateTime(2026, 10, 20), minutes: 30, completed: false, note: 'Только 10 страниц'),
  CheckIn(id: 5, habitId: 3, profileId: 2, date: DateTime(2026, 10, 20), minutes: 10, completed: true, note: ''),
  CheckIn(id: 6, habitId: 13, profileId: 1, date: DateTime(2026, 10, 20), minutes: 45, completed: true, note: 'Разобрал коллекции'),
  CheckIn(id: 7, habitId: 9, profileId: 2, date: DateTime(2026, 10, 20), minutes: 10, completed: true, note: ''),
  CheckIn(id: 8, habitId: 11, profileId: 3, date: DateTime(2026, 10, 20), minutes: 0, completed: false, note: 'Сорвалась вечером'),
  CheckIn(id: 9, habitId: 2, profileId: 1, date: DateTime(2026, 10, 21), minutes: 35, completed: true, note: 'Рекорд сезона'),
  CheckIn(id: 10, habitId: 5, profileId: 2, date: DateTime(2026, 10, 21), minutes: 20, completed: true, note: ''),
  CheckIn(id: 11, habitId: 12, profileId: 2, date: DateTime(2026, 10, 21), minutes: 40, completed: false, note: 'Набросок не начал'),
  CheckIn(id: 12, habitId: 14, profileId: 3, date: DateTime(2026, 10, 21), minutes: 25, completed: true, note: ''),
];
