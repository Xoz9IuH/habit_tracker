// Примерный «контент» приложения: справочники и стартовые привычки.
// Одна привычка в сиде сразу удалена, чтобы was где показывать
// восстановление и режим «видеть удалённые».
import '../models/category.dart';
import '../models/habit.dart';

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
    .firstWhere((c) => c.id == id, orElse: () => const Category(id: 0, name: '?', description: ''))
    .name;

const List<Category> seedCategories = [
  Category(id: 1, name: 'Спорт', description: 'Физическая активность и выносливость'),
  Category(id: 2, name: 'Здоровье', description: 'Сон, питание и самочувствие'),
  Category(id: 3, name: 'Обучение', description: 'Чтение, языки и новые навыки'),
  Category(id: 4, name: 'Быт', description: 'Домашние дела и порядок'),
  Category(id: 5, name: 'Продуктивность', description: 'Фокус, планирование и ритуалы'),
  Category(id: 6, name: 'Творчество', description: 'Рисование, музыка и хобби'),
];

const List<Habit> seedHabits = [
  Habit(id: 1, name: 'Утренняя зарядка', goal: 'Все 7 дней в неделю', categoryId: 1, periodicityId: 1, minutesPerDay: 15, streak: 42),
  Habit(id: 2, name: 'Пробежка 5 км', goal: 'Темп лучше 7:30 / км', categoryId: 1, periodicityId: 2, minutesPerDay: 35, streak: 12),
  Habit(id: 3, name: 'Медитация 10 минут', goal: 'Спокойно досидеть таймер', categoryId: 5, periodicityId: 1, minutesPerDay: 10, streak: 63),
  Habit(id: 4, name: 'Чтение 30 страниц', goal: '12 книг за год', categoryId: 3, periodicityId: 1, minutesPerDay: 30, streak: 21),
  Habit(id: 5, name: 'Английский по 20 минут', goal: 'Уровень B2 к июню', categoryId: 3, periodicityId: 1, minutesPerDay: 20, streak: 35),
  Habit(id: 6, name: '8 стаканов воды', goal: 'Каждый день без напоминаний', categoryId: 2, periodicityId: 1, minutesPerDay: 5, streak: 49),
  Habit(id: 7, name: 'Силовая тренировка', goal: '3 тренировки в неделю', categoryId: 1, periodicityId: 3, minutesPerDay: 60, streak: 8),
  Habit(id: 8, name: 'Дневник благодарности', goal: 'Три пункта каждый вечер', categoryId: 5, periodicityId: 1, minutesPerDay: 5, streak: 17),
  Habit(id: 9, name: 'Уборка стола', goal: 'Рабочая зона пустая к вечеру', categoryId: 4, periodicityId: 4, minutesPerDay: 10, streak: 3),
  Habit(id: 10, name: 'Отбой до 23:00', goal: '7+ часов сна', categoryId: 2, periodicityId: 1, minutesPerDay: 0, streak: 6),
  Habit(id: 11, name: 'День без сахара', goal: 'Не сладкого с понедельника', categoryId: 2, periodicityId: 1, minutesPerDay: 10, streak: 15),
  Habit(id: 12, name: 'Скетчинг', goal: 'Один набросок в два дня', categoryId: 6, periodicityId: 2, minutesPerDay: 40, streak: 9),
  Habit(id: 13, name: 'Изучение Dart', goal: 'Каждый будний день', categoryId: 3, periodicityId: 5, minutesPerDay: 45, streak: 11),
  Habit(id: 14, name: 'Стирка и сортировка', goal: 'Бельё разложено в шкафу', categoryId: 4, periodicityId: 4, minutesPerDay: 25, streak: 2),
  // Привычка 15 в репозитории сразу помечается удалённой: сид не может
  // вызвать DateTime.now() в const-списке, поэтому делает это репозиторий.
  Habit(id: 15, name: 'Соцсети до обеда', goal: 'Отвыкнуть от утреннего скролла', categoryId: 4, periodicityId: 1, minutesPerDay: 10, streak: 0),
];
