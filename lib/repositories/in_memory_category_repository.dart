import '../data/seed.dart';
import '../models/category.dart';
import '../models/category_query.dart';
import '../models/page_result.dart';
import 'category_repository.dart';

class InMemoryCategoryRepository implements CategoryRepository {
  final List<Category> _categories = [...seedCategories];
  int _nextId = seedCategories.length + 1;

  @override
  Future<PageResult<Category>> find(CategoryQuery q) async {
    await Future.delayed(const Duration(milliseconds: 200));

    var rows =
        _categories.where((c) => q.includeDeleted || !c.isDeleted).toList();

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

    final total = rows.length;
    final from = (q.page - 1) * q.size;
    final to = (from + q.size) > total ? total : (from + q.size);
    final items = from >= total ? <Category>[] : rows.sublist(from, to);

    return PageResult(
        items: items, page: q.page, size: q.size, total: total);
  }

  @override
  Future<Category?> findById(int id) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final i = _categories.indexWhere((c) => c.id == id);
    return i == -1 ? null : _categories[i];
  }

  @override
  Future<Category> create(Category category) async {
    final created = Category(
      id: _nextId++,
      name: category.name,
      description: category.description,
    );
    _categories.add(created);
    return created;
  }

  @override
  Future<Category> update(Category category) async {
    final i = _categories.indexWhere((c) => c.id == category.id);
    if (i == -1) throw StateError('Категория ${category.id} не найдена');
    _categories[i] = category;
    return category;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _categories.indexWhere((c) => c.id == id);
    if (i == -1) throw StateError('Категория $id не найдена');
    _categories[i] = _categories[i].copyWith(deletedAt: DateTime.now());
  }

  @override
  Future<void> hardDelete(int id) async {
    _categories.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> restore(int id) async {
    final i = _categories.indexWhere((c) => c.id == id);
    if (i == -1) throw StateError('Категория $id не найдена');
    _categories[i] = _categories[i].copyWith(clearDeletedAt: true);
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _categories.indexWhere((c) => c.id == id && !c.isDeleted);
      if (i != -1) {
        _categories[i] = _categories[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    return count;
  }
}
