import 'dart:async';

import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../core/supabase_config.dart';
import '../models/page_result.dart';

abstract class ApiRepository<T> {
  ApiRepository({
    required this.dio,
    required this.collection,
    required this.fromJson,
    required this.idOf,
    required this.isDeleted,
    required this.payload,
    this.toRow,
    this.foreignKeys = const {},
    this.manyToMany,
  });

  final Dio dio;
  final String collection;
  final T Function(Map<String, dynamic>) fromJson;
  final int Function(T) idOf;
  final bool Function(T) isDeleted;
  final Map<String, dynamic> Function(T) payload;

  final Map<String, dynamic> Function(T)? toRow;
  final Map<String, String> foreignKeys;
  final String? manyToMany;

  final List<T> _cache = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<T> get all => List.unmodifiable(_cache);

  List<T> allActive() => _cache.where((e) => !isDeleted(e)).toList();

  List<T> allWithDeleted() => List<T>.from(_cache);

  int takeNextId() => 0;

  bool get usesSupabase => SupabaseConfig.isConfigured;

  Future<PageResult<T>> find(dynamic query, {CancelToken? cancelToken});

  Future<PageResult<T>> fetchPage(
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) {
    if (usesSupabase) {
      return _fetchSupabase(params, cancelToken: cancelToken);
    }
    return _fetchRest(params, cancelToken: cancelToken);
  }

  Future<PageResult<T>> _fetchRest(
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

  Future<PageResult<T>> _fetchSupabase(
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) {
    return guard(() async {
      final size = params['size'] as int? ?? 10;
      final page = params['page'] as int? ?? 1;
      final includeDeleted = params['includeDeleted'] == true;

      final query = <String, dynamic>{
        'select': _select,
        'order': _order(params['sort'] as String?),
        'limit': size,
        'offset': (page - 1) * size,
      };
      query.addAll(_filters(params));
      if (!includeDeleted) query['deleted_at'] = 'is.null';

      final options = Options(headers: {'Prefer': 'count=exact'});

      final tagId = params['tagId'];
      if (tagId != null && manyToMany != null) {
        query['$association!inner'] = associationColumn;
        query['$association.$associationColumn'] = 'eq.$tagId';
      }

      final response = await dio.get<List<dynamic>>(
        '/$collection',
        queryParameters: query,
        cancelToken: cancelToken,
        options: options,
      );

      final rows = (response.data ?? const [])
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
      final items = rows.map((row) => fromJson(_expand(row))).toList();
      _merge(items);
      _loaded = true;
      onCacheUpdated();

      final total = _totalFrom(response.headers) ?? items.length;
      return PageResult(items: items, page: page, size: size, total: total);
    });
  }

  Future<void> refresh() async {
    if (usesSupabase) {
      await guard(() async {
        final response = await dio.get<List<dynamic>>(
          '/$collection',
          queryParameters: {
            'select': _select,
            'order': 'id.asc',
            'limit': 1000,
          },
        );
        final rows = (response.data ?? const [])
            .whereType<Map>()
            .map((row) => row.cast<String, dynamic>())
            .toList();
        _cache
          ..clear()
          ..addAll(rows.map((row) => fromJson(_expand(row))));
        _loaded = true;
        onCacheUpdated();
      });
      return;
    }

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
    if (usesSupabase) {
      final rows = await _fetchRows({'id': 'eq.$id', 'limit': 1});
      if (rows.isEmpty) return null;
      final item = fromJson(_expand(rows.first));
      _upsert(item);
      onCacheUpdated();
      return item;
    }

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
    if (usesSupabase) {
      return guard(() async {
        final row = (toRow ?? payload)(item);
        final response = await dio.post<List<dynamic>>(
          '/$collection',
          data: row,
        );
        final rows = (response.data ?? const []).whereType<Map>().toList();
        final saved = fromJson(_expand(rows.first.cast<String, dynamic>()));
        _upsert(saved);
        onCacheUpdated();
        return saved;
      });
    }

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
    if (usesSupabase) {
      return guard(() async {
        final row = (toRow ?? payload)(item);
        final response = await dio.patch<List<dynamic>>(
          '/$collection',
          queryParameters: {'id': 'eq.${idOf(item)}'},
          data: row,
        );
        final rows = (response.data ?? const []).whereType<Map>().toList();
        final saved = fromJson(_expand(rows.first.cast<String, dynamic>()));
        _upsert(saved);
        onCacheUpdated();
        return saved;
      });
    }

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
    if (usesSupabase) {
      await guard(() async {
        await dio.patch<List<dynamic>>(
          '/$collection',
          queryParameters: {'id': 'eq.$id'},
          data: {'deleted_at': DateTime.now().toUtc().toIso8601String()},
        );
      });
      await _reloadOne(id);
      return;
    }

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
    if (usesSupabase) {
      await guard(() async {
        await dio.patch<List<dynamic>>(
          '/$collection',
          queryParameters: {'id': 'eq.$id'},
          data: {'deleted_at': null},
        );
      });
      await _reloadOne(id);
      return;
    }

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
    if (usesSupabase) {
      await guard(() async {
        await dio.delete<List<dynamic>>(
          '/$collection',
          queryParameters: {'id': 'eq.$id'},
        );
      });
      _remove(id);
      onCacheUpdated();
      return;
    }

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
    if (usesSupabase) {
      if (ids.isEmpty) return 0;
      final filter = 'in.(${ids.join(',')})';
      await guard(() async {
        if (hard) {
          await dio.delete<List<dynamic>>(
            '/$collection',
            queryParameters: {'id': filter},
          );
        } else {
          await dio.patch<List<dynamic>>(
            '/$collection',
            queryParameters: {'id': filter},
            data: {'deleted_at': DateTime.now().toUtc().toIso8601String()},
          );
        }
      });
      for (final id in ids) {
        _remove(id);
      }
      onCacheUpdated();
      return ids.length;
    }

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

  String get _select {
    final joins = [
      for (final entry in foreignKeys.entries)
        '${entry.key}:${entry.value}(id,name)',
      if (manyToMany != null) '$manyToMany(*)',
    ];
    return joins.isEmpty ? '*' : '*,${joins.join(',')}';
  }

  String _order(String? sort) {
    final parts = (sort ?? 'id,asc').split(',');
    final field = _column(parts.first);
    final direction = parts.length > 1 && parts[1] == 'desc' ? 'desc' : 'asc';
    return '$field.$direction';
  }

  String _column(String name) {
    final buffer = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final char = name[i];
      final upper = char.toUpperCase() == char && char.toLowerCase() != char;
      buffer.write(upper && i > 0 ? '_${char.toLowerCase()}' : char);
    }
    return buffer.toString();
  }

  Map<String, dynamic> _filters(Map<String, dynamic> params) {
    final result = <String, dynamic>{};
    for (final entry in params.entries) {
      final value = entry.value;
      switch (entry.key) {
        case 'sort':
        case 'page':
        case 'size':
        case 'includeDeleted':
        case 'tagId':
          continue;
        case 'search':
          if (value is String && value.trim().isNotEmpty) {
            final column = searchColumn;
            if (column != null) {
              result[column] = 'ilike.*${value.trim()}*';
            }
          }
        case 'categoryId':
        case 'periodicityId':
        case 'profileId':
        case 'streakFrom':
        case 'streakTo':
        case 'discountFrom':
        case 'discountTo':
          continue;
        default:
          result[entry.key] = value;
      }
    }

    void eq(String param, String column) {
      final value = params[param];
      if (value != null) result[column] = 'eq.$value';
    }

    eq('categoryId', 'category_id');
    eq('periodicityId', 'periodicity_id');
    eq('profileId', 'profile_id');
    eq('habitId', 'habit_id');
    if (params['streakFrom'] != null) {
      result['streak'] = 'gte.${params['streakFrom']}';
    }
    if (params['streakTo'] != null) {
      result['streak'] = 'lte.${params['streakTo']}';
    }
    if (params['discountFrom'] != null) {
      result['discount_percent'] = 'gte.${params['discountFrom']}';
    }
    if (params['discountTo'] != null) {
      result['discount_percent'] = 'lte.${params['discountTo']}';
    }
    return result;
  }

  String? get searchColumn => null;

  String get association {
    final raw = manyToMany ?? 'habit_tags';
    final cut = raw.indexOf('(');
    return cut == -1 ? raw : raw.substring(0, cut);
  }

  String get associationColumn {
    final raw = manyToMany ?? 'habit_tags(tags(id,name))';
    return raw.contains('tags(') ? 'tag_id' : 'tag_id';
  }

  Map<String, dynamic> _expand(Map<String, dynamic> row) {
    final result = Map<String, dynamic>.from(row);
    for (final entry in foreignKeys.entries) {
      final joined = result[entry.key];
      if (joined is Map) {
        result['${entry.key}Id'] = joined['id'];
      }
    }
    final tags = result[manyToMany ?? ''];
    if (tags is List) {
      result['tagIds'] = tags
          .whereType<Map>()
          .map((tag) => tag['id'])
          .whereType<int>()
          .toList();
    }
    result['deletedAt'] = result['deleted_at'];
    return result;
  }

  Future<List<Map<String, dynamic>>> _fetchRows(Map<String, dynamic> params) {
    return guard(() async {
      final response = await dio.get<List<dynamic>>(
        '/$collection',
        queryParameters: {'select': _select, ...params},
      );
      return (response.data ?? const [])
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
    });
  }

  Future<void> _reloadOne(int id) async {
    final rows = await _fetchRows({'id': 'eq.$id', 'limit': 1});
    if (rows.isEmpty) {
      _remove(id);
    } else {
      _upsert(fromJson(_expand(rows.first)));
    }
    onCacheUpdated();
  }

  int? _totalFrom(Headers headers) {
    final range = headers.value('content-range');
    if (range == null) return null;
    final parts = range.split('/');
    return int.tryParse(parts.last.trim());
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
