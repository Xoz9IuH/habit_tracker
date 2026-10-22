import '../models/coupon.dart';
import '../models/coupon_query.dart';
import '../repositories/coupon_repository.dart';
import 'list_notifier.dart';

class CouponListNotifier extends ListNotifier<Coupon, CouponQuery> {
  final CouponRepository _repository;

  CouponListNotifier(this._repository) : super(const CouponQuery());

  @override
  Future<void> load() async {
    setStatus(LoadStatus.loading);
    try {
      setResult(await _repository.find(query));
    } catch (e) {
      setStatus(LoadStatus.error, error: 'Не удалось загрузить купоны: $e');
    }
  }

  Future<Coupon> save(Coupon coupon) async {
    if (coupon.id == 0) {
      final created = coupon.copyWith(id: _repository.takeNextId());
      final saved = await _repository.create(created);
      await load();
      return saved;
    }
    final saved = await _repository.update(coupon);
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
