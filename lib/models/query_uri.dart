
import 'category_query.dart';
import 'check_in_query.dart';
import 'habit_query.dart';
import 'profile_query.dart';
import 'tag_query.dart';

int? _parseInt(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return int.tryParse(raw);
}

bool _parseBool(String? raw) => raw == 'true';

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

String? _sortField(Map<String, String> p, String fallback) {
  final sort = p['sort'];
  if (sort == null || sort.isEmpty) return fallback;
  final parts = sort.split(',');
  return parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : fallback;
}

bool _sortAscending(Map<String, String> p) {
  final sort = p['sort'];
  if (sort == null || sort.isEmpty) return true;
  final parts = sort.split(',');
  return parts.length > 1 ? parts[1] != 'desc' : true;
}

Map<String, String> habitQueryToParams(HabitQuery q) {
  final params = <String, String>{};
  if (q.search.isNotEmpty) params['search'] = q.search;
  if (q.categoryId != null) params['categoryId'] = '${q.categoryId}';
  if (q.periodicityId != null) params['periodicityId'] = '${q.periodicityId}';
  if (q.profileId != null) params['profileId'] = '${q.profileId}';
  if (q.tagId != null) params['tagId'] = '${q.tagId}';
  if (q.streakFrom != null) params['streakFrom'] = '${q.streakFrom}';
  if (q.streakTo != null) params['streakTo'] = '${q.streakTo}';
  params['sort'] = '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}';
  if (q.page != 1) params['page'] = '${q.page}';
  if (q.size != 10) params['size'] = '${q.size}';
  if (q.includeDeleted) params['includeDeleted'] = 'true';
  return params;
}

HabitQuery habitQueryFromParams(Map<String, String> p) {
  return HabitQuery(
    search: p['search'] ?? '',
    categoryId: _parseInt(p['categoryId']),
    periodicityId: _parseInt(p['periodicityId']),
    profileId: _parseInt(p['profileId']),
    tagId: _parseInt(p['tagId']),
    streakFrom: _parseInt(p['streakFrom']),
    streakTo: _parseInt(p['streakTo']),
    sortField: _sortField(p, 'name')!,
    sortAscending: _sortAscending(p),
    page: _parseInt(p['page']) ?? 1,
    size: _parseInt(p['size']) ?? 10,
    includeDeleted: _parseBool(p['includeDeleted']),
  );
}

Map<String, String> categoryQueryToParams(CategoryQuery q) {
  final params = <String, String>{};
  if (q.search.isNotEmpty) params['search'] = q.search;
  params['sort'] = '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}';
  if (q.page != 1) params['page'] = '${q.page}';
  if (q.size != 10) params['size'] = '${q.size}';
  if (q.includeDeleted) params['includeDeleted'] = 'true';
  return params;
}

CategoryQuery categoryQueryFromParams(Map<String, String> p) {
  return CategoryQuery(
    search: p['search'] ?? '',
    sortField: _sortField(p, 'name')!,
    sortAscending: _sortAscending(p),
    page: _parseInt(p['page']) ?? 1,
    size: _parseInt(p['size']) ?? 10,
    includeDeleted: _parseBool(p['includeDeleted']),
  );
}

Map<String, String> tagQueryToParams(TagQuery q) {
  final params = <String, String>{};
  if (q.search.isNotEmpty) params['search'] = q.search;
  if (q.categoryId != null) params['categoryId'] = '${q.categoryId}';
  params['sort'] = '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}';
  if (q.page != 1) params['page'] = '${q.page}';
  if (q.size != 10) params['size'] = '${q.size}';
  if (q.includeDeleted) params['includeDeleted'] = 'true';
  return params;
}

TagQuery tagQueryFromParams(Map<String, String> p) {
  return TagQuery(
    search: p['search'] ?? '',
    categoryId: _parseInt(p['categoryId']),
    sortField: _sortField(p, 'name')!,
    sortAscending: _sortAscending(p),
    page: _parseInt(p['page']) ?? 1,
    size: _parseInt(p['size']) ?? 10,
    includeDeleted: _parseBool(p['includeDeleted']),
  );
}

Map<String, String> profileQueryToParams(ProfileQuery q) {
  final params = <String, String>{};
  if (q.search.isNotEmpty) params['search'] = q.search;
  if (q.city != null && q.city!.isNotEmpty) params['city'] = q.city!;
  params['sort'] = '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}';
  if (q.page != 1) params['page'] = '${q.page}';
  if (q.size != 10) params['size'] = '${q.size}';
  if (q.includeDeleted) params['includeDeleted'] = 'true';
  return params;
}

ProfileQuery profileQueryFromParams(Map<String, String> p) {
  return ProfileQuery(
    search: p['search'] ?? '',
    city: p['city'],
    sortField: _sortField(p, 'name')!,
    sortAscending: _sortAscending(p),
    page: _parseInt(p['page']) ?? 1,
    size: _parseInt(p['size']) ?? 10,
    includeDeleted: _parseBool(p['includeDeleted']),
  );
}

Map<String, String> checkInQueryToParams(CheckInQuery q) {
  final params = <String, String>{};
  if (q.search.isNotEmpty) params['search'] = q.search;
  if (q.habitId != null) params['habitId'] = '${q.habitId}';
  if (q.profileId != null) params['profileId'] = '${q.profileId}';
  if (q.dateFrom != null) {
    params['dateFrom'] = q.dateFrom!.toIso8601String();
  }
  if (q.dateTo != null) params['dateTo'] = q.dateTo!.toIso8601String();
  params['sort'] = '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}';
  if (q.page != 1) params['page'] = '${q.page}';
  if (q.size != 10) params['size'] = '${q.size}';
  if (q.includeDeleted) params['includeDeleted'] = 'true';
  return params;
}

CheckInQuery checkInQueryFromParams(Map<String, String> p) {
  return CheckInQuery(
    search: p['search'] ?? '',
    habitId: _parseInt(p['habitId']),
    profileId: _parseInt(p['profileId']),
    dateFrom: _parseDate(p['dateFrom']),
    dateTo: _parseDate(p['dateTo']),
    sortField: _sortField(p, 'date')!,
    sortAscending: _sortAscending(p),
    page: _parseInt(p['page']) ?? 1,
    size: _parseInt(p['size']) ?? 10,
    includeDeleted: _parseBool(p['includeDeleted']),
  );
}
