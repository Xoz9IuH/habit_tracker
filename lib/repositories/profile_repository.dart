import '../models/profile.dart';
import '../models/profile_query.dart';
import '../models/page_result.dart';
import 'stored_repository.dart';

class ProfileRepository extends StoredRepository<Profile> {
  ProfileRepository({
    required super.store,
    required super.seed,
  }) : super(
          name: 'profiles',
          idOf: (p) => p.id,
          fromJson: Profile.fromJson,
          toJson: (p) => p.toJson(),
        );

  @override
  bool isDeleted(Profile item) => item.isDeleted;

  @override
  Future<PageResult<Profile>> find(dynamic query) async {
    final q = query as ProfileQuery;
    var rows = allWithDeleted().where((p) => q.includeDeleted || !p.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows
          .where((p) =>
              p.name.toLowerCase().contains(needle) ||
              p.email.toLowerCase().contains(needle))
          .toList();
    }

    if (q.city != null && q.city!.isNotEmpty) {
      rows = rows.where((p) => p.city == q.city).toList();
    }

    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'email' => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
        'city' => a.city.toLowerCase().compareTo(b.city.toLowerCase()),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return q.sortAscending ? result : -result;
    });

    return paginate(rows, q.page, q.size);
  }

  Future<Profile?> findByEmail(String email, {int? excludeId}) async {
    final needle = email.trim().toLowerCase();
    for (final p in allActive()) {
      if (p.id == excludeId) continue;
      if (p.email.trim().toLowerCase() == needle) return p;
    }
    return null;
  }

  List<String> get cities {
    final result = allActive().map((p) => p.city).toSet().toList()..sort();
    return result;
  }

  Future<void> softDelete(int id, DateTime at) async {
    final p = await findById(id);
    if (p == null) throw StateError('Профиль $id не найден');
    await update(p.copyWith(deletedAt: at));
  }

  Future<void> restore(int id) async {
    final p = await findById(id);
    if (p == null) throw StateError('Профиль $id не найден');
    await update(p.copyWith(clearDeletedAt: true));
  }

  Future<int> deleteMany(List<int> ids, DateTime at) async {
    var count = 0;
    for (final id in ids) {
      final p = await findById(id);
      if (p == null || p.isDeleted) continue;
      await update(p.copyWith(deletedAt: at));
      count++;
    }
    return count;
  }
}
