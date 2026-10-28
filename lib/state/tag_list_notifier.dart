import '../models/tag.dart';
import '../models/tag_query.dart';
import '../repositories/tag_repository.dart';
import 'list_notifier.dart';

class TagListNotifier extends ListNotifier<Tag, TagQuery> {
  final TagRepository _repository;

  TagListNotifier(this._repository) : super(const TagQuery());

  @override
  Future<void> load() =>
      runLoad((token) => _repository.find(query, cancelToken: token));

  Future<Tag> save(Tag tag) async {
    final saved = tag.id == 0
        ? await _repository.create(tag)
        : await _repository.update(tag);
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
