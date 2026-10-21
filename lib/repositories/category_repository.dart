import '../models/category.dart';
import '../models/category_query.dart';
import '../models/page_result.dart';
import 'stored_repository.dart';

/// Хранилище категорий. Заодно отвечает на вопрос «сколько привычек
/// ссылается на категорию» — без этого нельзя корректно удалить категорию.
class CategoryRepository extends StoredRepository<Category> {
  CategoryRepository({
    required super.store,
    required super.seed,
  }) : super(
          name: 'categories',
          idOf: (c) => c.id,
          fromJson: Category.fromJson,
          toJson: (c) => c.toJson(),
        );

  @override
  bool isDeleted(Category item) => item.isDeleted;

  @override
  Future<PageResult<Category>> find(dynamic query) async {
    final q = query as CategoryQuery;
    var rows = allWithDeleted().where((c) => q.includeDeleted || !c.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows
          .where((c) =>
              c.name.toLowerCase().contains(needle) ||
              c.description.toLowerCase().contains(needle))
          .toList();
    }

    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'description' =>
          a.description.toLowerCase().compareTo(b.description.toLowerCase()),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return q.sortAscending ? result : -result;
    });

    return paginate(rows, q.page, q.size);
  }

  Future<Category?> findByName(String name) async {
    final needle = name.trim().toLowerCase();
    for (final c in allActive()) {
      if (c.name.trim().toLowerCase() == needle) return c;
    }
    return null;
  }

  Future<void> softDelete(int id, DateTime at) async {
    final c = await findById(id);
    if (c == null) throw StateError('Категория $id не найдена');
    await update(c.copyWith(deletedAt: at));
  }

  Future<void> restore(int id) async {
    final c = await findById(id);
    if (c == null) throw StateError('Категория $id не найдена');
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
