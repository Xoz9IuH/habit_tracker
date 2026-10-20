// Контракт хранилища привычек. Абстракция в отдельном файле, чтобы в четвёртой
// работе заменить реализацию в one строку (например, на HTTP/backend).
import '../models/habit.dart';
import '../models/habit_query.dart';
import '../models/page_result.dart';

abstract interface class HabitRepository {
  Future<PageResult<Habit>> find(HabitQuery query);
  Future<Habit?> findById(int id);
  Future<Habit> create(Habit habit);
  Future<Habit> update(Habit habit);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}
