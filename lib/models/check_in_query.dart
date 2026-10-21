
class CheckInQuery {
  final String search;
  final int? habitId;
  final int? profileId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const CheckInQuery({
    this.search = '',
    this.habitId,
    this.profileId,
    this.dateFrom,
    this.dateTo,
    this.sortField = 'date',
    this.sortAscending = false,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  CheckInQuery copyWith({
    String? search,
    Object? habitId = _unset,
    Object? profileId = _unset,
    Object? dateFrom = _unset,
    Object? dateTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return CheckInQuery(
      search: search ?? this.search,
      habitId: habitId == _unset ? this.habitId : habitId as int?,
      profileId: profileId == _unset ? this.profileId : profileId as int?,
      dateFrom: dateFrom == _unset ? this.dateFrom : dateFrom as DateTime?,
      dateTo: dateTo == _unset ? this.dateTo : dateTo as DateTime?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  static const _unset = Object();
}
