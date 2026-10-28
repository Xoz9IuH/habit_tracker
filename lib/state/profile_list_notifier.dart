import '../models/profile.dart';
import '../models/profile_query.dart';
import '../repositories/profile_repository.dart';
import 'list_notifier.dart';

class ProfileListNotifier extends ListNotifier<Profile, ProfileQuery> {
  final ProfileRepository _repository;

  ProfileListNotifier(this._repository) : super(const ProfileQuery());

  @override
  Future<void> load() =>
      runLoad((token) => _repository.find(query, cancelToken: token));

  Future<Profile> save(Profile profile) async {
    final saved = profile.id == 0
        ? await _repository.create(profile)
        : await _repository.update(profile);
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
