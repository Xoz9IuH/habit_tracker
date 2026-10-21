import '../models/check_in.dart';
import '../models/check_in_query.dart';
import '../models/page_result.dart';
import 'stored_repository.dart';

class CheckInRepository extends StoredRepository<CheckIn> {
  CheckInRepository({
    required super.store,
    required super.seed,
  }) : super(
          name: 'check_ins',
          idOf: (c) => c.id,
          fromJson: CheckIn.fromJson,
          toJson: (c) => c.toJson(),
        );

  @override
  bool isDeleted(CheckIn item) => item.isDeleted;

  @override
  Future<PageResult<CheckIn>> find(dynamic query) async {
    final q = query as CheckInQuery;
    var rows =
        allWithDeleted().where((c) => q.includeDeleted || !c.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows.where((c) => c.note.toLowerCase().contains(needle)).toList();
    }

    if (q.habitId != null) {
      rows = rows.where((c) => c.habitId == q.habitId).toList();
    }
    if (q.profileId != null) {
      rows = rows.where((c) => c.profileId == q.profileId).toList();
    }
    if (q.dateFrom != null) {
      rows = rows.where((c) => !c.date.isBefore(q.dateFrom!)).toList();
    }
    if (q.dateTo != null) {
      final end = DateTime(
        q.dateTo!.year,
        q.dateTo!.month,
        q.dateTo!.day,
        23,
        59,
        59,
      );
      rows = rows.where((c) => !c.date.isAfter(end)).toList();
    }

    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'minutes' => a.minutes.compareTo(b.minutes),
        'habit' => a.habitId.compareTo(b.habitId),
        _ => a.date.compareTo(b.date),
      };
      return q.sortAscending ? result : -result;
    });

    return paginate(rows, q.page, q.size);
  }

  int countByHabit(int habitId) =>
      allActive().where((c) => c.habitId == habitId).length;

  int countByProfile(int profileId) =>
      allActive().where((c) => c.profileId == profileId).length;

  Future<void> softDelete(int id, DateTime at) async {
    final c = await findById(id);
    if (c == null) throw StateError('Отметка $id не найдена');
    await update(c.copyWith(deletedAt: at));
  }

  Future<void> restore(int id) async {
    final c = await findById(id);
    if (c == null) throw StateError('Отметка $id не найдена');
    await update(c.copyWith(clearDeletedAt: true));
  }

  Future<int> deleteMany(List<int> ids, DateTime at) async {
    var count = 0;
    for (final id in ids) {
      final c = await findById(id);
      if (c == null || c.isDeleted) continue;
      await update(c.copyWith(deletedAt: at));
      count++;
    }
    return count;
  }
}
