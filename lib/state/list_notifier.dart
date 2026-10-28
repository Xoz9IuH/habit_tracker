import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../core/app_messenger.dart';
import '../models/page_result.dart';

enum LoadStatus { idle, loading, success, error }

abstract class ListNotifier<T, Q> extends ChangeNotifier {
  Q _query;
  PageResult<T> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  CancelToken? _cancelToken;

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

  @protected
  Future<void> runLoad(
    Future<PageResult<T>> Function(CancelToken token) fetch,
  ) async {
    _cancelToken?.cancel('stale');
    final token = CancelToken();
    _cancelToken = token;

    setStatus(LoadStatus.loading);
    try {
      final result = await fetch(token);
      if (token.isCancelled) return;
      setResult(result);
    } on RequestCancelledException {
      return;
    } catch (e) {
      if (token.isCancelled) return;
      setStatus(LoadStatus.error, error: errorText(e));
    }
  }

  @protected
  Future<void> runAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    try {
      await action();
      if (successMessage != null) AppMessenger.show(successMessage);
      await load();
    } catch (e) {
      AppMessenger.showError(e);
    }
  }

  @protected
  Future<int> runDeleteSelected(Future<int> Function() action) async {
    try {
      final count = await action();
      clearSelection();
      await load();
      return count;
    } catch (e) {
      AppMessenger.showError(e);
      return 0;
    }
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

  Future<void> hardDeleteOne(int id);

  Future<int> purgeSelected();

  void setResult(PageResult<T> result) {
    _result = result;
    _status = LoadStatus.success;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('dispose');
    super.dispose();
  }
}
