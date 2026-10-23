import 'package:dio/dio.dart';

import '../models/check_in.dart';
import '../models/check_in_query.dart';
import '../models/page_result.dart';
import 'api_repository.dart';

class CheckInRepository extends ApiRepository<CheckIn> {
  CheckInRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'check_ins',
        fromJson: CheckIn.fromJson,
        idOf: (c) => c.id,
        isDeleted: (c) => c.isDeleted,
        payload: (c) => {
          'habitId': c.habitId,
          'profileId': c.profileId,
          'date': c.date.toIso8601String(),
          'minutes': c.minutes,
          'completed': c.completed,
          'note': c.note,
        },
      );

  @override
  Future<PageResult<CheckIn>> find(dynamic query, {CancelToken? cancelToken}) {
    final q = query as CheckInQuery;
    return fetchPage({
      if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
      if (q.habitId != null) 'habitId': q.habitId,
      if (q.profileId != null) 'profileId': q.profileId,
      if (q.dateFrom != null) 'dateFrom': _date(q.dateFrom!),
      if (q.dateTo != null) 'dateTo': _date(q.dateTo!),
      'sort': '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}',
      'page': q.page,
      'size': q.size,
      if (q.includeDeleted) 'includeDeleted': true,
    }, cancelToken: cancelToken);
  }

  int countByHabit(int habitId) =>
      allActive().where((c) => c.habitId == habitId).length;

  int countByProfile(int profileId) =>
      allActive().where((c) => c.profileId == profileId).length;

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
