// Переводы объект запрос <-> параметры адресной строки.
// Именно эта связка делает URL «источником правды»: мгновенно в кадре
// обновится ссылка чем только пользователь произвёл изменение.
import 'category_query.dart';
import 'habit_query.dart';

int? _parseInt(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return int.tryParse(raw);
}

bool _parseBool(String? raw) => raw == 'true';

/// /habits?search=бег&categoryId=2&sort=streak,desc&page=2
Map<String, String> habitQueryToParams(HabitQuery q) {
  final params = <String, String>{};
  if (q.search.isNotEmpty) params['search'] = q.search;
  if (q.categoryId != null) params['categoryId'] = '${q.categoryId}';
  if (q.periodicityId != null) params['periodicityId'] = '${q.periodicityId}';
  if (q.streakFrom != null) params['streakFrom'] = '${q.streakFrom}';
  if (q.streakTo != null) params['streakTo'] = '${q.streakTo}';
  params['sort'] = '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}';
  if (q.page != 1) params['page'] = '${q.page}';
  if (q.size != 10) params['size'] = '${q.size}';
  if (q.includeDeleted) params['includeDeleted'] = 'true';
  return params;
}

HabitQuery habitQueryFromParams(Map<String, String> p) {
  var sortField = 'name';
  var ascending = true;
  final sort = p['sort'];
  if (sort != null && sort.isNotEmpty) {
    final parts = sort.split(',');
    if (parts.isNotEmpty && parts.first.isNotEmpty) sortField = parts.first;
    if (parts.length > 1) ascending = parts[1] != 'desc';
  }
  return HabitQuery(
    search: p['search'] ?? '',
    categoryId: _parseInt(p['categoryId']),
    periodicityId: _parseInt(p['periodicityId']),
    streakFrom: _parseInt(p['streakFrom']),
    streakTo: _parseInt(p['streakTo']),
    sortField: sortField,
    sortAscending: ascending,
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
  var sortField = 'name';
  var ascending = true;
  final sort = p['sort'];
  if (sort != null && sort.isNotEmpty) {
    final parts = sort.split(',');
    if (parts.isNotEmpty && parts.first.isNotEmpty) sortField = parts.first;
    if (parts.length > 1) ascending = parts[1] != 'desc';
  }
  return CategoryQuery(
    search: p['search'] ?? '',
    sortField: sortField,
    sortAscending: ascending,
    page: _parseInt(p['page']) ?? 1,
    size: _parseInt(p['size']) ?? 10,
    includeDeleted: _parseBool(p['includeDeleted']),
  );
}
