
class HabitQuery {
  final String search;
  final int? categoryId;
  final int? periodicityId;
  final int? profileId;
  final int? tagId;
  final int? streakFrom;
  final int? streakTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const HabitQuery({
    this.search = '',
    this.categoryId,
    this.periodicityId,
    this.profileId,
    this.tagId,
    this.streakFrom,
    this.streakTo,
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  HabitQuery copyWith({
    String? search,
    Object? categoryId = _unset,
    Object? periodicityId = _unset,
    Object? profileId = _unset,
    Object? tagId = _unset,
    Object? streakFrom = _unset,
    Object? streakTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return HabitQuery(
      search: search ?? this.search,
      categoryId: categoryId == _unset ? this.categoryId : categoryId as int?,
      periodicityId:
          periodicityId == _unset ? this.periodicityId : periodicityId as int?,
      profileId: profileId == _unset ? this.profileId : profileId as int?,
      tagId: tagId == _unset ? this.tagId : tagId as int?,
      streakFrom: streakFrom == _unset ? this.streakFrom : streakFrom as int?,
      streakTo: streakTo == _unset ? this.streakTo : streakTo as int?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  static const _unset = Object();
}
