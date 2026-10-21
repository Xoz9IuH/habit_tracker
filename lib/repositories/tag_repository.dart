import '../models/tag.dart';
import '../models/tag_query.dart';
import '../models/page_result.dart';
import 'stored_repository.dart';

class TagRepository extends StoredRepository<Tag> {
  TagRepository({
    required super.store,
    required super.seed,
  }) : super(
          name: 'tags',
          idOf: (t) => t.id,
          fromJson: Tag.fromJson,
          toJson: (t) => t.toJson(),
        );

  @override
  bool isDeleted(Tag item) => item.isDeleted;

  @override
  Future<PageResult<Tag>> find(dynamic query) async {
    final q = query as TagQuery;
    var rows = allWithDeleted().where((t) => q.includeDeleted || !t.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows.where((t) => t.name.toLowerCase().contains(needle)).toList();
    }

    if (q.categoryId != null) {
      rows = rows.where((t) => t.categoryId == q.categoryId).toList();
    }

    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'color' => a.color.compareTo(b.color),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return q.sortAscending ? result : -result;
    });

    return paginate(rows, q.page, q.size);
  }

  Future<Tag?> findByName(String name) async {
    final needle = name.trim().toLowerCase();
    for (final t in allActive()) {
      if (t.name.trim().toLowerCase() == needle) return t;
    }
    return null;
  }

  Future<void> softDelete(int id, DateTime at) async {
    final t = await findById(id);
    if (t == null) throw StateError('Тег $id не найден');
    await update(t.copyWith(deletedAt: at));
  }

  Future<void> restore(int id) async {
    final t = await findById(id);
    if (t == null) throw StateError('Тег $id не найден');
    await update(t.copyWith(clearDeletedAt: true));
  }

  Future<int> deleteMany(List<int> ids, DateTime at) async {
    var count = 0;
    for (final id in ids) {
      final t = await findById(id);
      if (t == null || t.isDeleted) continue;
      await update(t.copyWith(deletedAt: at));
      count++;
    }
    return count;
  }
}
