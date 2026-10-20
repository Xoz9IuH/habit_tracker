// Контракт хранилища категорий — такой же, как у привычек, только короче.
import '../models/category.dart';
import '../models/category_query.dart';
import '../models/page_result.dart';

abstract interface class CategoryRepository {
  Future<PageResult<Category>> find(CategoryQuery query);
  Future<Category?> findById(int id);
  Future<Category> create(Category category);
  Future<Category> update(Category category);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}
