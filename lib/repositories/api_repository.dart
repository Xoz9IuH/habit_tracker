import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';

abstract class ApiRepository<T> {
  ApiRepository({
    required this.dio,
    required this.collection,
    required this.fromJson,
    required this.idOf,
    required this.isDeleted,
    required this.payload,
  });

  final Dio dio;
  final String collection;
  final T Function(Map<String, dynamic>) fromJson;
  final int Function(T) idOf;
  final bool Function(T) isDeleted;
  final Map<String, dynamic> Function(T) payload;

  final List<T> _cache = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<T> get all => List.unmodifiable(_cache);

  List<T> allActive() => _cache.where((e) => !isDeleted(e)).toList();

  List<T> allWithDeleted() => List<T>.from(_cache);

  int takeNextId() => 0;

  Future<PageResult<T>> find(dynamic query, {CancelToken? cancelToken});

  Future<PageResult<T>> fetchPage(
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) {
    return guard(() async {
      final response = await dio.get<Map<String, dynamic>>(
        '/$collection',
        queryParameters: params,
        cancelToken: cancelToken,
      );
      final data = response.data ?? const <String, dynamic>{};
      final items = _itemsOf(data);
      _merge(items);
      _loaded = true;
      onCacheUpdated();

      return PageResult(
        items: items,
        page: data['page'] as int? ?? 1,
        size: data['size'] as int? ?? (params['size'] as int? ?? items.length),
        total: data['total'] as int? ?? items.length,
      );
    });
  }

  Future<void> refresh() async {
    const pageSize = 100;
    final loaded = <T>[];
    var page = 1;

    while (true) {
      final response = await guard(() async {
        return dio.get<Map<String, dynamic>>(
          '/$collection',
          queryParameters: {'page': page, 'size': pageSize, 'sort': 'id,asc'},
        );
      });

      final data = response.data ?? const <String, dynamic>{};
      final items = _itemsOf(data);
      loaded.addAll(items);

      final total = data['total'] as int? ?? loaded.length;
      if (items.isEmpty || loaded.length >= total) break;
      page++;
    }

    _cache
      ..clear()
      ..addAll(loaded);
    _loaded = true;
    onCacheUpdated();
  }

  Future<T?> findById(int id) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/$collection/$id',
        queryParameters: {'includeDeleted': true},
      );
      final item = fromJson(response.data ?? const {});
      _upsert(item);
      onCacheUpdated();
      return item;
    } on DioException catch (e) {
      final mapped = mapDioError(e);
      if (mapped is NotFoundException) return null;
      throw mapped;
    }
  }

  Future<T> create(T item) async {
    final saved = await guard(() async {
      final response = await dio.post<Map<String, dynamic>>(
        '/$collection',
        data: payload(item),
      );
      return fromJson(response.data ?? const {});
    });
    _upsert(saved);
    onCacheUpdated();
    return saved;
  }

  Future<T> update(T item) async {
    final saved = await guard(() async {
      final response = await dio.put<Map<String, dynamic>>(
        '/$collection/${idOf(item)}',
        data: payload(item),
      );
      return fromJson(response.data ?? const {});
    });
    _upsert(saved);
    onCacheUpdated();
    return saved;
  }

  Future<void> softDelete(int id, DateTime at) async {
    await guard(() => dio.delete<void>('/$collection/$id'));

    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/$collection/$id',
        queryParameters: {'includeDeleted': true},
      );
      _upsert(fromJson(response.data ?? const {}));
    } on DioException {
      _remove(id);
    }
    onCacheUpdated();
  }

  Future<void> restore(int id) async {
    final restored = await guard(() async {
      final response = await dio.post<Map<String, dynamic>>(
        '/$collection/$id/restore',
      );
      return fromJson(response.data ?? const {});
    });
    _upsert(restored);
    onCacheUpdated();
  }

  Future<void> remove(int id) async {
    await guard(
      () =>
          dio.delete<void>('/$collection/$id', queryParameters: {'hard': true}),
    );
    _remove(id);
    onCacheUpdated();
  }

  Future<int> deleteMany(
    List<int> ids,
    DateTime at, {
    bool hard = false,
  }) async {
    final deleted = await guard(() async {
      final response = await dio.post<Map<String, dynamic>>(
        '/$collection/bulk-delete',
        data: {'ids': ids, if (hard) 'hard': true},
      );
      return response.data?['deleted'] as int? ?? 0;
    });

    for (final id in ids) {
      _remove(id);
    }
    onCacheUpdated();
    return deleted;
  }

  void onCacheUpdated() {}

  List<T> _itemsOf(Map<String, dynamic> data) {
    final raw = data['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  void _merge(List<T> items) {
    for (final item in items) {
      _upsert(item);
    }
  }

  void _upsert(T item) {
    final index = _cache.indexWhere((e) => idOf(e) == idOf(item));
    if (index == -1) {
      _cache.add(item);
    } else {
      _cache[index] = item;
    }
  }

  void _remove(int id) {
    _cache.removeWhere((e) => idOf(e) == id);
  }
}
