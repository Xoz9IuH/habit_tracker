import '../models/coupon.dart';
import '../models/coupon_query.dart';
import '../repositories/coupon_repository.dart';
import 'list_notifier.dart';

class CouponListNotifier extends ListNotifier<Coupon, CouponQuery> {
  final CouponRepository _repository;

  CouponListNotifier(this._repository) : super(const CouponQuery());

  @override
  Future<void> load() =>
      runLoad((token) => _repository.find(query, cancelToken: token));

  Future<Coupon> save(Coupon coupon) async {
    final saved = await _repository.saveCoupon(coupon);
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
