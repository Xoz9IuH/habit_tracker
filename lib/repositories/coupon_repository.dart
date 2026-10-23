import 'package:dio/dio.dart';

import '../models/coupon.dart';
import '../models/coupon_query.dart';
import '../models/page_result.dart';
import 'api_repository.dart';

class CouponRepository extends ApiRepository<Coupon> {
  CouponRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'coupons',
        fromJson: Coupon.fromJson,
        idOf: (c) => c.id,
        isDeleted: (c) => c.isDeleted,
        payload: (c) => {
          'profileId': c.profileId,
          'code': c.code,
          'discountPercent': c.discountPercent,
          'expiresAt': c.expiresAt.toIso8601String(),
        },
      );

  @override
  Future<PageResult<Coupon>> find(dynamic query, {CancelToken? cancelToken}) {
    final q = query as CouponQuery;
    return fetchPage({
      if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
      if (q.profileId != null) 'profileId': q.profileId,
      if (q.discountFrom != null) 'discountFrom': q.discountFrom,
      if (q.discountTo != null) 'discountTo': q.discountTo,
      'sort': '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}',
      'page': q.page,
      'size': q.size,
      if (q.includeDeleted) 'includeDeleted': true,
    }, cancelToken: cancelToken);
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

  Future<Coupon> saveCoupon(Coupon coupon) =>
      coupon.id == 0 ? create(coupon) : update(coupon);
}
