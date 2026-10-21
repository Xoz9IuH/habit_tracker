import '../models/tag.dart';
import '../models/tag_query.dart';
import '../repositories/tag_repository.dart';
import 'list_notifier.dart';

class TagListNotifier extends ListNotifier<Tag, TagQuery> {
  final TagRepository _repository;

  TagListNotifier(this._repository) : super(const TagQuery());

  @override
  Future<void> load() async {
    setStatus(LoadStatus.loading);
    try {
      setResult(await _repository.find(query));
    } catch (e) {
      setStatus(LoadStatus.error, error: 'Не удалось загрузить теги: $e');
    }
  }

  Future<Tag> save(Tag tag) async {
    if (tag.id == 0) {
      final created = tag.copyWith(id: _repository.takeNextId());
      final saved = await _repository.create(created);
      await load();
      return saved;
    }
    final saved = await _repository.update(tag);
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
