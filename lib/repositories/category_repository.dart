import 'package:dio/dio.dart';

import '../core/reference_cache.dart';
import '../models/category.dart';
import '../models/category_query.dart';
import '../models/page_result.dart';
import 'api_repository.dart';

class CategoryRepository extends ApiRepository<Category> {
  CategoryRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'categories',
        fromJson: Category.fromJson,
        idOf: (c) => c.id,
        isDeleted: (c) => c.isDeleted,
        payload: (c) => {'name': c.name, 'description': c.description},
      );

  @override
  void onCacheUpdated() {
    ReferenceCache.instance.putCategories(
      allWithDeleted().map((c) => (c.id, c.name)),
    );
  }

  @override
  Future<PageResult<Category>> find(dynamic query, {CancelToken? cancelToken}) {
    final q = query as CategoryQuery;
    return fetchPage({
      if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
      'sort': '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}',
      'page': q.page,
      'size': q.size,
      if (q.includeDeleted) 'includeDeleted': true,
    }, cancelToken: cancelToken);
  }

  Category? findByName(String name) {
    final needle = name.trim().toLowerCase();
    for (final c in allActive()) {
      if (c.name.trim().toLowerCase() == needle) return c;
    }
    return null;
  }
}
