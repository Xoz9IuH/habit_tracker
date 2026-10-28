import '../models/category.dart';
import '../models/category_query.dart';
import '../repositories/category_repository.dart';
import 'list_notifier.dart';

class CategoryListNotifier extends ListNotifier<Category, CategoryQuery> {
  final CategoryRepository _repository;

  CategoryListNotifier(this._repository) : super(const CategoryQuery());

  @override
  Future<void> load() =>
      runLoad((token) => _repository.find(query, cancelToken: token));

  Future<Category> save(Category category) async {
    final saved = category.id == 0
        ? await _repository.create(category)
        : await _repository.update(category);
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
