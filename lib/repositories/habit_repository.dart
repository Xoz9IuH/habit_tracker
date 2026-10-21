import '../models/habit.dart';
import '../models/habit_query.dart';
import '../models/page_result.dart';
import 'stored_repository.dart';

class HabitRepository extends StoredRepository<Habit> {
  HabitRepository({
    required super.store,
    required super.seed,
  }) : super(
          name: 'habits',
          idOf: (h) => h.id,
          fromJson: Habit.fromJson,
          toJson: (h) => h.toJson(),
        ) {

    for (final h in all) {
      if (h.id == 15) {
        replace(h.copyWith(deletedAt: DateTime(2026, 10, 1)));
      }
    }
  }

  @override
  bool isDeleted(Habit item) => item.isDeleted;

  @override
  Future<PageResult<Habit>> find(dynamic query) async {
    final q = query as HabitQuery;
    var rows = allWithDeleted().where((h) => q.includeDeleted || !h.isDeleted).toList();

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
    if (q.profileId != null) {
      rows = rows.where((h) => h.profileId == q.profileId).toList();
    }
    if (q.tagId != null) {
      rows = rows.where((h) => h.tagIds.contains(q.tagId)).toList();
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

    return paginate(rows, q.page, q.size);
  }

  Future<Habit?> findByName(String name) async {
    final needle = name.trim().toLowerCase();
    for (final h in allActive()) {
      if (h.name.trim().toLowerCase() == needle) return h;
    }
    return null;
  }

  int countByCategory(int categoryId) => allActive()
      .where((h) => h.categoryId == categoryId)
      .length;

  int countByTag(int tagId) =>
      allActive().where((h) => h.tagIds.contains(tagId)).length;

  int countByProfile(int profileId) =>
      allActive().where((h) => h.profileId == profileId).length;

  Future<void> softDelete(int id, DateTime at) async {
    final h = await findById(id);
    if (h == null) throw StateError('Привычка $id не найдена');
    await update(h.copyWith(deletedAt: at));
  }

  Future<void> restore(int id) async {
    final h = await findById(id);
    if (h == null) throw StateError('Привычка $id не найдена');
    await update(h.copyWith(clearDeletedAt: true));
  }

  Future<int> deleteMany(List<int> ids, DateTime at) async {
    var count = 0;
    for (final id in ids) {
      final h = await findById(id);
      if (h == null || h.isDeleted) continue;
      await update(h.copyWith(deletedAt: at));
      count++;
    }
    return count;
  }
}
