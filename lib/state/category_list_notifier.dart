import '../models/category.dart';
import '../models/category_query.dart';
import '../repositories/category_repository.dart';
import 'list_notifier.dart';

class CategoryListNotifier extends ListNotifier<Category, CategoryQuery> {
  final CategoryRepository _repository;

  CategoryListNotifier(this._repository) : super(const CategoryQuery());

  @override
  Future<void> load() async {
    setStatus(LoadStatus.loading);
    try {
      setResult(await _repository.find(query));
    } catch (e) {
      setStatus(LoadStatus.error, error: 'Не удалось загрузить категории: $e');
    }
  }

  Future<Category> save(Category category) async {
    if (category.id == 0) {
      final created = category.copyWith(id: _repository.takeNextId());
      final saved = await _repository.create(created);
      await load();
      return saved;
    }
    final saved = await _repository.update(category);
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
