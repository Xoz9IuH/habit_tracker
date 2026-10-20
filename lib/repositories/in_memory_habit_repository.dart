import '../data/seed.dart';
import '../models/habit.dart';
import '../models/habit_query.dart';
import '../models/page_result.dart';
import 'habit_repository.dart';

class InMemoryHabitRepository implements HabitRepository {
  final List<Habit> _habits = [...seedHabits];
  int _nextId = seedHabits.length + 1;

  InMemoryHabitRepository() {
    // Сценарий «есть что восстановить»: привычка 15 удалена с самого старта.
    _habits[14] = _habits[14].copyWith(deletedAt: DateTime(2026, 10, 1));
  }

  @override
  Future<PageResult<Habit>> find(HabitQuery q) async {
    // Асинхронность, как и в ПрДе 4: имитация ожидания сетевого запроса.
    await Future.delayed(const Duration(milliseconds: 250));

    var rows = _habits.where((h) => q.includeDeleted || !h.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows
          .where((h) =>
              h.name.toLowerCase().contains(needle) ||
              h.goal.toLowerCase().contains(needle))
          .toList();
    }

    if (q.categoryId != null) {
      rows = rows.where((h) => h.categoryId == q.categoryId).toList();
    }
    if (q.periodicityId != null) {
      rows = rows.where((h) => h.periodicityId == q.periodicityId).toList();
    }
    if (q.streakFrom != null) {
      rows = rows.where((h) => h.streak >= q.streakFrom!).toList();
    }
    if (q.streakTo != null) {
      rows = rows.where((h) => h.streak <= q.streakTo!).toList();
    }

    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'streak' => a.streak.compareTo(b.streak),
        'minutes' => a.minutesPerDay.compareTo(b.minutesPerDay),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return q.sortAscending ? result : -result;
    });

    final total = rows.length;
    final from = (q.page - 1) * q.size;
    // Осторожно: num.clamp возвращает num, а не int, поэтому тут явная проверка.
    final to = (from + q.size) > total ? total : (from + q.size);
    final items = from >= total ? <Habit>[] : rows.sublist(from, to);

    return PageResult(items: items, page: q.page, size: q.size, total: total);
  }

  @override
  Future<Habit?> findById(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final i = _habits.indexWhere((h) => h.id == id);
    return i == -1 ? null : _habits[i];
  }

  @override
  Future<Habit> create(Habit habit) async {
    final created = Habit(
      id: _nextId++,
      name: habit.name,
      goal: habit.goal,
      categoryId: habit.categoryId,
      periodicityId: habit.periodicityId,
      minutesPerDay: habit.minutesPerDay,
      streak: habit.streak,
    );
    _habits.add(created);
    return created;
  }

  @override
  Future<Habit> update(Habit habit) async {
    final i = _habits.indexWhere((h) => h.id == habit.id);
    if (i == -1) throw StateError('Привычка ${habit.id} не найдена');
    _habits[i] = habit;
    return habit;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _habits.indexWhere((h) => h.id == id);
    if (i == -1) throw StateError('Привычка $id не найдена');
    _habits[i] = _habits[i].copyWith(deletedAt: DateTime.now());
  }

  @override
  Future<void> hardDelete(int id) async {
    _habits.removeWhere((h) => h.id == id);
  }

  @override
  Future<void> restore(int id) async {
    final i = _habits.indexWhere((h) => h.id == id);
    if (i == -1) throw StateError('Привычка $id не найдена');
    _habits[i] = _habits[i].copyWith(clearDeletedAt: true);
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _habits.indexWhere((h) => h.id == id && !h.isDeleted);
      if (i != -1) {
        _habits[i] = _habits[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    return count;
  }
}
