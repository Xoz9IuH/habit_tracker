import '../models/profile.dart';
import '../models/profile_query.dart';
import '../repositories/profile_repository.dart';
import 'list_notifier.dart';

class ProfileListNotifier extends ListNotifier<Profile, ProfileQuery> {
  final ProfileRepository _repository;

  ProfileListNotifier(this._repository) : super(const ProfileQuery());

  @override
  Future<void> load() async {
    setStatus(LoadStatus.loading);
    try {
      setResult(await _repository.find(query));
    } catch (e) {
      setStatus(LoadStatus.error, error: 'Не удалось загрузить профили: $e');
    }
  }

  Future<Profile> save(Profile profile) async {
    if (profile.id == 0) {
      final created = profile.copyWith(id: _repository.takeNextId());
      final saved = await _repository.create(created);
      await load();
      return saved;
    }
    final saved = await _repository.update(profile);
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
