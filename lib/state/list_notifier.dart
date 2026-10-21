import 'package:flutter/foundation.dart';

import '../models/page_result.dart';

enum LoadStatus { idle, loading, success, error }

abstract class ListNotifier<T, Q> extends ChangeNotifier {
  Q _query;
  PageResult<T> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};

  ListNotifier(this._query);

  Q get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<void> load();

  Future<void> applyQuery(Q next) async {
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(int id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    notifyListeners();
  }

  void selectAll(Iterable<int> ids) {
    _selected.addAll(ids);
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  void setStatus(LoadStatus status, {String? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }

  Future<int> deleteSelected();

  void setResult(PageResult<T> result) {
    _result = result;
    _status = LoadStatus.success;
    notifyListeners();
  }
}
