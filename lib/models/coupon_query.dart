
class CouponQuery {
  final String search;
  final int? profileId;
  final int? discountFrom;
  final int? discountTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const CouponQuery({
    this.search = '',
    this.profileId,
    this.discountFrom,
    this.discountTo,
    this.sortField = 'code',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  CouponQuery copyWith({
    String? search,
    Object? profileId = _unset,
    Object? discountFrom = _unset,
    Object? discountTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return CouponQuery(
      search: search ?? this.search,
      profileId: profileId == _unset ? this.profileId : profileId as int?,
      discountFrom:
          discountFrom == _unset ? this.discountFrom : discountFrom as int?,
      discountTo: discountTo == _unset ? this.discountTo : discountTo as int?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  static const _unset = Object();
}
