import 'package:dio/dio.dart';

import '../core/reference_cache.dart';
import '../models/habit.dart';
import '../models/habit_query.dart';
import '../models/page_result.dart';
import 'api_repository.dart';

class HabitRepository extends ApiRepository<Habit> {
  HabitRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'habits',
        fromJson: Habit.fromJson,
        idOf: (h) => h.id,
        isDeleted: (h) => h.isDeleted,
        payload: (h) => {
          'name': h.name,
          'goal': h.goal,
          'categoryId': h.categoryId,
          'periodicityId': h.periodicityId,
          'minutesPerDay': h.minutesPerDay,
          'streak': h.streak,
          'profileId': h.profileId,
          'tagIds': h.tagIds,
        },
      );

  @override
  void onCacheUpdated() {
    ReferenceCache.instance.putHabits(
      allWithDeleted().map((h) => (h.id, h.name)),
    );
  }

  @override
  Future<PageResult<Habit>> find(dynamic query, {CancelToken? cancelToken}) {
    final q = query as HabitQuery;
    return fetchPage({
      if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
      if (q.categoryId != null) 'categoryId': q.categoryId,
      if (q.periodicityId != null) 'periodicityId': q.periodicityId,
      if (q.profileId != null) 'profileId': q.profileId,
      if (q.tagId != null) 'tagId': q.tagId,
      if (q.streakFrom != null) 'streakFrom': q.streakFrom,
      if (q.streakTo != null) 'streakTo': q.streakTo,
      'sort': '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}',
      'page': q.page,
      'size': q.size,
      if (q.includeDeleted) 'includeDeleted': true,
    }, cancelToken: cancelToken);
  }

  Habit? findByName(String name) {
    final needle = name.trim().toLowerCase();
    for (final h in allActive()) {
      if (h.name.trim().toLowerCase() == needle) return h;
    }
    return null;
  }

  int countByCategory(int categoryId) =>
      allActive().where((h) => h.categoryId == categoryId).length;

  int countByTag(int tagId) =>
      allActive().where((h) => h.tagIds.contains(tagId)).length;

  int countByProfile(int profileId) =>
      allActive().where((h) => h.profileId == profileId).length;
}
