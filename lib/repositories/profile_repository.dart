import 'package:dio/dio.dart';

import '../core/reference_cache.dart';
import '../models/page_result.dart';
import '../models/profile.dart';
import '../models/profile_query.dart';
import 'api_repository.dart';

class ProfileRepository extends ApiRepository<Profile> {
  ProfileRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'profiles',
        fromJson: Profile.fromJson,
        idOf: (p) => p.id,
        isDeleted: (p) => p.isDeleted,
        payload: (p) => {
          'name': p.name,
          'email': p.email,
          'city': p.city,
          'dailyGoalMinutes': p.dailyGoalMinutes,
          'remindersEnabled': p.remindersEnabled,
          'couponId': p.couponId,
        },
      );

  @override
  void onCacheUpdated() {
    ReferenceCache.instance.putProfiles(
      allWithDeleted().map((p) => (p.id, p.name)),
    );
  }

  @override
  Future<PageResult<Profile>> find(dynamic query, {CancelToken? cancelToken}) {
    final q = query as ProfileQuery;
    return fetchPage({
      if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
      if (q.city != null && q.city!.isNotEmpty) 'city': q.city,
      'sort': '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}',
      'page': q.page,
      'size': q.size,
      if (q.includeDeleted) 'includeDeleted': true,
    }, cancelToken: cancelToken);
  }

  Profile? findByEmail(String email, {int? excludeId}) {
    final needle = email.trim().toLowerCase();
    for (final p in allActive()) {
      if (p.id == excludeId) continue;
      if (p.email.trim().toLowerCase() == needle) return p;
    }
    return null;
  }

  List<String> get cities {
    return allActive().map((p) => p.city).toSet().toList()..sort();
  }
}
