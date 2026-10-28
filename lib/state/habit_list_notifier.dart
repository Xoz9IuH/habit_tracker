import '../models/habit.dart';
import '../models/habit_query.dart';
import '../repositories/habit_repository.dart';
import 'list_notifier.dart';

class HabitListNotifier extends ListNotifier<Habit, HabitQuery> {
  final HabitRepository _repository;

  HabitListNotifier(this._repository) : super(const HabitQuery());

  @override
  Future<void> load() =>
      runLoad((token) => _repository.find(query, cancelToken: token));

  Future<Habit> save(Habit habit) async {
    final saved = habit.id == 0
        ? await _repository.create(habit)
        : await _repository.update(habit);
    await load();
    return saved;
  }

  Future<void> softDeleteOne(int id) =>
      runAction(() => _repository.softDelete(id, DateTime.now()));

  @override
  Future<void> hardDeleteOne(int id) => runAction(() => _repository.remove(id));

  Future<void> restoreOne(int id) => runAction(() => _repository.restore(id));

  @override
  Future<int> deleteSelected() => runDeleteSelected(
    () => _repository.deleteMany(selected.toList(), DateTime.now()),
  );

  @override
  Future<int> purgeSelected() => runDeleteSelected(
    () => _repository.deleteMany(selected.toList(), DateTime.now(), hard: true),
  );
}
