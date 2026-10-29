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
        foreignKeys: const {'category': 'categories', 'profile': 'profiles'},
        manyToMany: 'habit_tags(tags(id,name))',
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
        toRow: (h) => {
          'name': h.name,
          'goal': h.goal,
          'category_id': h.categoryId,
          'periodicity_id': h.periodicityId,
          'minutes_per_day': h.minutesPerDay,
          'streak': h.streak,
          'profile_id': h.profileId,
        },
      );

  @override
  String? get searchColumn => 'name';

  @override
  void onCacheUpdated() {
    ReferenceCache.instance.putHabits(
      allWithDeleted().map((h) => (h.id, h.name)),
    );
  }

  @override
  Future<Habit> create(Habit item) async {
    final saved = await super.create(item);
    if (usesSupabase && item.tagIds.isNotEmpty) {
      await _replaceTags(saved.id, item.tagIds);
    }
    return saved;
  }

  @override
  Future<Habit> update(Habit item) async {
    final saved = await super.update(item);
    if (usesSupabase) {
      await _replaceTags(saved.id, item.tagIds);
    }
    return saved;
  }

  Future<void> _replaceTags(int habitId, List<int> tagIds) async {
    await dio.delete<void>(
      '/habit_tags',
      queryParameters: {'habit_id': 'eq.$habitId'},
    );
    if (tagIds.isEmpty) return;
    await dio.post<void>(
      '/habit_tags',
      data: [
        for (final tagId in tagIds) {'habit_id': habitId, 'tag_id': tagId},
      ],
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
      if (q.streakFrom != null) 'streakFrom': q.streakFrom,
      if (q.streakTo != null) 'streakTo': q.streakTo,
      if (q.tagId != null) 'tagId': q.tagId,
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

  List<Habit> byTag(int tagId) =>
      allActive().where((h) => h.tagIds.contains(tagId)).toList();
}
