import '../models/habit.dart';
import '../models/habit_query.dart';
import '../repositories/habit_repository.dart';
import 'list_notifier.dart';

class HabitListNotifier extends ListNotifier<Habit, HabitQuery> {
  final HabitRepository _repository;

  HabitListNotifier(this._repository) : super(const HabitQuery());

  @override
  Future<void> load() async {
    setStatus(LoadStatus.loading);
    try {
      setResult(await _repository.find(query));
    } catch (e) {
      setStatus(LoadStatus.error, error: 'Не удалось загрузить привычки: $e');
    }
  }

  /// Сохранить привычку (создание или изменение).
  Future<Habit> save(Habit habit) async {
    if (habit.id == 0) {
      final created = habit.copyWith(id: _repository.takeNextId());
      final saved = await _repository.create(created);
      await load();
      return saved;
    }
    final saved = await _repository.update(habit);
    await load();
    return saved;
  }

  Future<void> softDeleteOne(int id) async {
    await _repository.softDelete(id, DateTime.now());
    await load();
  }

  Future<void> hardDeleteOne(int id) async {
    await _repository.remove(id);
    await load();
  }

  Future<void> restoreOne(int id) async {
    await _repository.restore(id);
    await load();
  }

  @override
  Future<int> deleteSelected() async {
    final count = await _repository.deleteMany(selected.toList(), DateTime.now());
    clearSelection();
    await load();
    return count;
  }
}
