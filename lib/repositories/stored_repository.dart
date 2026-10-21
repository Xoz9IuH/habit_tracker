import 'dart:math' as math;

import '../models/page_result.dart';
import '../storage/json_store.dart';

/// Общий каркас репозитория: список в памяти + сохранение в хранилище
/// после каждого изменения. Наследники реализуют find() — фильтры, поиск,
/// сортировку и пагинацию для своей сущности.
abstract class StoredRepository<T> {
  StoredRepository({
    required this.store,
    required this.name,
    required List<T> seed,
    required this.idOf,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
  }) : _toJson = toJson {
    final load =
        store.loadList<T>(name, () => List<T>.from(seed), fromJson, toJson);
    _items = load.items;
    notice = load.notice;
    var maxId = 0;
    for (final item in _items) {
      final id = idOf(item);
      if (id > maxId) maxId = id;
    }
    _nextId = maxId + 1;
  }

  final JsonStore store;
  final String name;
  final int Function(T) idOf;
  final Map<String, dynamic> Function(T) _toJson;

  late List<T> _items;
  int _nextId = 1;

  /// Сообщение о миграции формата данных (показывается один раз).
  String? notice;

  List<T> get all => List.unmodifiable(_items);

  /// Следующий свободный id — выдаётся при создании записи.
  int takeNextId() => _nextId++;

  Future<PageResult<T>> find(dynamic query);

  Future<T?> findById(int id) async {
    for (final item in _items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  /// Все записи без учёта удалённых — для проверок уникальности и связей.
  List<T> allActive() => _items.where((e) => !isDeleted(e)).toList();

  /// Все записи, включая удалённые.
  List<T> allWithDeleted() => List<T>.from(_items);

  bool isDeleted(T item);

  Future<T> create(T item) async {
    _items.add(item);
    await _persist();
    return item;
  }

  Future<T> update(T item) async {
    final index = _items.indexWhere((e) => idOf(e) == idOf(item));
    if (index == -1) {
      throw StateError('Запись с id=${idOf(item)} не найдена');
    }
    _items[index] = item;
    await _persist();
    return item;
  }

  /// Заменить запись в списке — используется наследниками при инициализации
  /// (например, чтобы отметить часть сидов как удалённые).
  void replace(T item) {
    final index = _items.indexWhere((e) => idOf(e) == idOf(item));
    if (index != -1) _items[index] = item;
  }

  Future<void> remove(int id) async {
    _items.removeWhere((e) => idOf(e) == id);
    await _persist();
  }

  Future<void> _persist() async {
    await store.saveList<T>(name, _items, _toJson);
  }

  /// Страница результата по общему для всех сущностей алгоритму.
  PageResult<T> paginate(List<T> rows, int page, int size) {
    final total = rows.length;
    final from = (page - 1) * size;
    final to = math.min(from + size, total);
    final items = from >= total ? <T>[] : rows.sublist(from, to);
    return PageResult(items: items, page: page, size: size, total: total);
  }
}
