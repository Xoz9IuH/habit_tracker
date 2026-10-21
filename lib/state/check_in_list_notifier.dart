import '../models/check_in.dart';
import '../models/check_in_query.dart';
import '../repositories/check_in_repository.dart';
import 'list_notifier.dart';

class CheckInListNotifier extends ListNotifier<CheckIn, CheckInQuery> {
  final CheckInRepository _repository;

  CheckInListNotifier(this._repository) : super(const CheckInQuery());

  @override
  Future<void> load() async {
    setStatus(LoadStatus.loading);
    try {
      setResult(await _repository.find(query));
    } catch (e) {
      setStatus(LoadStatus.error, error: 'Не удалось загрузить отметки: $e');
    }
  }

  Future<CheckIn> save(CheckIn checkIn) async {
    if (checkIn.id == 0) {
      final created = checkIn.copyWith(id: _repository.takeNextId());
      final saved = await _repository.create(created);
      await load();
      return saved;
    }
    final saved = await _repository.update(checkIn);
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
