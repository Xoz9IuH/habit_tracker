import '../models/check_in.dart';
import '../models/check_in_query.dart';
import '../repositories/check_in_repository.dart';
import 'list_notifier.dart';

class CheckInListNotifier extends ListNotifier<CheckIn, CheckInQuery> {
  final CheckInRepository _repository;

  CheckInListNotifier(this._repository) : super(const CheckInQuery());

  @override
  Future<void> load() =>
      runLoad((token) => _repository.find(query, cancelToken: token));

  Future<CheckIn> save(CheckIn checkIn) async {
    final saved = checkIn.id == 0
        ? await _repository.create(checkIn)
        : await _repository.update(checkIn);
    await load();
    return saved;
  }

  Future<void> softDeleteOne(int id) =>
      runAction(() => _repository.softDelete(id, DateTime.now()));

  Future<void> hardDeleteOne(int id) => runAction(() => _repository.remove(id));

  Future<void> restoreOne(int id) => runAction(() => _repository.restore(id));

  @override
  Future<int> deleteSelected() => runDeleteSelected(
    () => _repository.deleteMany(selected.toList(), DateTime.now()),
  );
}
