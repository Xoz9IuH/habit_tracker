import '../models/coupon.dart';
import '../models/coupon_query.dart';
import '../models/page_result.dart';
import 'stored_repository.dart';

class CouponRepository extends StoredRepository<Coupon> {
  CouponRepository({
    required super.store,
    required super.seed,
  }) : super(
          name: 'coupons',
          idOf: (c) => c.id,
          fromJson: Coupon.fromJson,
          toJson: (c) => c.toJson(),
        );

  @override
  bool isDeleted(Coupon item) => item.isDeleted;

  @override
  Future<PageResult<Coupon>> find(dynamic query) async {
    final q = query as CouponQuery;
    var rows = allWithDeleted().where((c) => q.includeDeleted || !c.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows.where((c) => c.code.toLowerCase().contains(needle)).toList();
    }

    if (q.profileId != null) {
      rows = rows.where((c) => c.profileId == q.profileId).toList();
    }
    if (q.discountFrom != null) {
      rows = rows.where((c) => c.discountPercent >= q.discountFrom!).toList();
    }
    if (q.discountTo != null) {
      rows = rows.where((c) => c.discountPercent <= q.discountTo!).toList();
    }

    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'discount' => a.discountPercent.compareTo(b.discountPercent),
        'expires' => a.expiresAt.compareTo(b.expiresAt),
        _ => a.code.toLowerCase().compareTo(b.code.toLowerCase()),
      };
      return q.sortAscending ? result : -result;
    });

    return paginate(rows, q.page, q.size);
  }

  Coupon? findByProfile(int profileId) {
    for (final c in allActive()) {
      if (c.profileId == profileId) return c;
    }
    return null;
  }

  Coupon? findByCode(String code, {int? excludeId}) {
    final needle = code.trim().toLowerCase();
    for (final c in allActive()) {
      if (c.id == excludeId) continue;
      if (c.code.trim().toLowerCase() == needle) return c;
    }
    return null;
  }

  Future<void> softDelete(int id, DateTime at) async {
    final c = await findById(id);
    if (c == null) throw StateError('Купон $id не найден');
    await update(c.copyWith(deletedAt: at));
  }

  Future<Coupon> saveCoupon(Coupon coupon) async {
    if (coupon.id == 0) {
      final created = coupon.copyWith(id: takeNextId());
      final saved = await create(created);
      return saved;
    }
    return update(coupon);
  }

  Future<void> restore(int id) async {
    final c = await findById(id);
    if (c == null) throw StateError('Купон $id не найден');
    await update(c.copyWith(clearDeletedAt: true));
  }

  Future<int> deleteMany(List<int> ids, DateTime at) async {
    var count = 0;
    for (final id in ids) {
      final c = await findById(id);
      if (c == null || c.isDeleted) continue;
      await update(c.copyWith(deletedAt: at));
      count++;
    }
    return count;
  }
}
