import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/list_notifier.dart';
import 'debounced_search_field.dart';
import 'entity_table.dart';
import 'pagination_bar.dart';
import 'user_menu.dart';

class EntityListScreen<T, Q> extends StatefulWidget {
  final String path;
  final String title;
  final Q initialQuery;
  final Q Function(Map<String, String>) queryFromParams;
  final Map<String, String> Function(Q) queryToParams;
  final ListNotifier<T, Q> notifier;
  final List<TableColumnSpec<T>> Function(Q query) columns;
  final List<Widget> Function(
    BuildContext context,
    Q query,
    ValueChanged<Q> onQuery,
  )
  extraFilters;
  final String searchHint;
  final void Function(T item) onOpen;
  final void Function(T item)? onEdit;
  final void Function(T item)? onDelete;
  final void Function(T item)? onRestore;
  final bool Function(T item) isDeleted;
  final Widget Function(BuildContext context, T item) cardBuilder;
  final List<Widget> appBarActions;

  const EntityListScreen({
    super.key,
    required this.path,
    required this.title,
    required this.initialQuery,
    required this.queryFromParams,
    required this.queryToParams,
    required this.notifier,
    required this.columns,
    required this.extraFilters,
    required this.searchHint,
    required this.onOpen,
    required this.isDeleted,
    required this.cardBuilder,
    this.onEdit,
    this.onDelete,
    this.onRestore,
    this.appBarActions = const [],
  });

  @override
  State<EntityListScreen<T, Q>> createState() => _EntityListScreenState<T, Q>();
}

class _EntityListScreenState<T, Q> extends State<EntityListScreen<T, Q>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.notifier
        ..removeListener(_syncUrl)
        ..addListener(_syncUrl);
      widget.notifier.applyQuery(widget.initialQuery);
    });
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_syncUrl);
    super.dispose();
  }

  void _syncUrl() {
    if (!mounted) return;
    final params = widget.queryToParams(widget.notifier.query);
    final current = GoRouterState.of(context).uri.queryParameters;
    if (!_mapsEqual(params, current)) {
      context.go(Uri(path: widget.path, queryParameters: params).toString());
    }
  }

  bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (b[k] != a[k]) return false;
    }
    return true;
  }

  void _apply(Q next) {
    widget.notifier.applyQuery(next);
  }

  Future<void> _confirmDeleteSelected(int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить записи?'),
        content: Text(
          'Выбрано: $count. Записи исчезнут из списка, '
          'но останутся в «корзине» — их можно вернуть.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final deleted = await widget.notifier.deleteSelected();
      if (mounted && deleted > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('В корзину перемещено: $deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = widget.notifier;
    final query = notifier.query;
    final wide = MediaQuery.widthOf(context) >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [...widget.appBarActions, const UserMenu()],
      ),
      body: Column(
        children: [
          _filters(context, query),
          if (notifier.hasSelection) _selectionBar(context, notifier),
          Expanded(child: _body(context, notifier, wide)),
          PaginationBar(
            page: notifier.result.page,
            totalPages: notifier.result.totalPages,
            total: notifier.result.total,
            size: _sizeOf(query),
            onPage: (p) => _apply(_withPage(query, p)),
            onSize: (s) => _apply(_withSize(query, s)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Q _withPage(Q query, int page) {
    final params = widget.queryToParams(query);
    params['page'] = '$page';
    return widget.queryFromParams(params);
  }

  Q _withSize(Q query, int size) {
    final params = widget.queryToParams(query);
    params['size'] = '$size';
    return widget.queryFromParams(params);
  }

  int _sizeOf(Q query) {
    try {
      return (query as dynamic).size as int? ?? 10;
    } catch (_) {
      return 10;
    }
  }

  Widget _filters(BuildContext context, Q query) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: DebouncedSearchField(
              initialValue: _searchValue(query),
              hint: widget.searchHint,
              onChanged: (v) => _apply(_withSearch(query, v)),
            ),
          ),
          ...widget.extraFilters(context, query, _apply),
        ],
      ),
    );
  }

  String _searchValue(Q query) {
    try {
      final dynamic q = query;
      return (q.search as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  Q _withSearch(Q query, String value) {
    final params = widget.queryToParams(query);
    if (value.trim().isEmpty) {
      params.remove('search');
    } else {
      params['search'] = value;
    }
    return widget.queryFromParams(params);
  }

  Widget _selectionBar(BuildContext context, ListNotifier<T, Q> notifier) {
    return Container(
      color: Theme.of(context).colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text('Выбрано: ${notifier.selected.length}'),
          const Spacer(),
          TextButton.icon(
            onPressed: notifier.clearSelection,
            icon: const Icon(Icons.clear),
            label: const Text('Снять'),
          ),
          FilledButton.icon(
            onPressed: () => _confirmDeleteSelected(notifier.selected.length),
            icon: const Icon(Icons.delete),
            label: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ListNotifier<T, Q> notifier, bool wide) {
    return switch (notifier.status) {
      LoadStatus.loading => const Center(child: CircularProgressIndicator()),
      LoadStatus.error => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(notifier.error ?? 'Ошибка загрузки'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: notifier.load,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
      LoadStatus.success || LoadStatus.idle =>
        notifier.result.total == 0
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off, size: 48),
                    const SizedBox(height: 8),
                    const Text('Ничего не найдено'),
                  ],
                ),
              )
            : wide
            ? _table(context, notifier)
            : ListView.builder(
                itemCount: notifier.result.items.length,
                itemBuilder: (context, i) =>
                    widget.cardBuilder(context, notifier.result.items[i]),
              ),
    };
  }

  Widget _table(BuildContext context, ListNotifier<T, Q> notifier) {
    return EntityTable<T>(
      items: notifier.result.items,
      idOf: (item) => (item as dynamic).id as int,
      selected: notifier.selected,
      onToggleSelect: notifier.toggleSelection,
      onToggleSelectAll: (ids) {
        final all = ids.every(notifier.selected.contains);
        all ? notifier.clearSelection() : notifier.selectAll(ids);
      },
      sortField: _sortField(notifier.query),
      sortAscending: _sortAscending(notifier.query),
      onSort: (field) => _apply(_withSort(notifier.query, field)),
      columns: widget.columns(notifier.query),
      actions: (item) => [
        IconButton(
          tooltip: 'Открыть',
          icon: const Icon(Icons.open_in_new),
          onPressed: () => widget.onOpen(item),
        ),
        if (widget.onEdit != null)
          IconButton(
            tooltip: 'Изменить',
            icon: const Icon(Icons.edit),
            onPressed: () => widget.onEdit!(item),
          ),
        if (!widget.isDeleted(item) && widget.onDelete != null)
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => widget.onDelete!(item),
          ),
        if (widget.isDeleted(item) && widget.onRestore != null)
          IconButton(
            tooltip: 'Вернуть',
            icon: const Icon(Icons.restore),
            onPressed: () => widget.onRestore!(item),
          ),
      ],
    );
  }

  String? _sortField(Q query) {
    try {
      return (query as dynamic).sortField as String?;
    } catch (_) {
      return null;
    }
  }

  bool _sortAscending(Q query) {
    try {
      return (query as dynamic).sortAscending as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  Q _withSort(Q query, String field) {
    final dynamic q = query;
    final current = q.sortField as String? ?? '';
    final ascending = current == field
        ? !(q.sortAscending as bool? ?? true)
        : true;
    final params = widget.queryToParams(query);
    params['sort'] = '$field,${ascending ? 'asc' : 'desc'}';
    return widget.queryFromParams(params);
  }
}
