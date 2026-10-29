import 'package:dio/dio.dart';

import '../core/reference_cache.dart';
import '../models/page_result.dart';
import '../models/tag.dart';
import '../models/tag_query.dart';
import 'api_repository.dart';

class TagRepository extends ApiRepository<Tag> {
  TagRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'tags',
        fromJson: Tag.fromJson,
        idOf: (t) => t.id,
        isDeleted: (t) => t.isDeleted,
        payload: (t) => {
          'name': t.name,
          'color': t.color,
          'categoryId': t.categoryId,
        },
        toRow: (t) => {
          'name': t.name,
          'color': t.color,
          'category_id': t.categoryId,
        },
      );

  @override
  void onCacheUpdated() {
    ReferenceCache.instance.putTags(
      allWithDeleted().map((t) => (t.id, t.name)),
    );
  }

  @override
  Future<PageResult<Tag>> find(dynamic query, {CancelToken? cancelToken}) {
    final q = query as TagQuery;
    return fetchPage({
      if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
      if (q.categoryId != null) 'categoryId': q.categoryId,
      'sort': '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}',
      'page': q.page,
      'size': q.size,
      if (q.includeDeleted) 'includeDeleted': true,
    }, cancelToken: cancelToken);
  }

  Tag? findByName(String name) {
    final needle = name.trim().toLowerCase();
    for (final t in allActive()) {
      if (t.name.trim().toLowerCase() == needle) return t;
    }
    return null;
  }
}
