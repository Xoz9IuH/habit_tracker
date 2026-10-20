import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/category_query.dart';
import '../models/query_uri.dart';
import '../state/category_list_notifier.dart';
import '../state/habit_list_notifier.dart' show LoadStatus;
import '../widgets/debounced_search_field.dart';
import '../widgets/entity_table.dart';
import '../widgets/pagination_bar.dart';

class CategoryListScreen extends StatefulWidget {
  final CategoryQuery initialQuery;

  const CategoryListScreen({super.key, required this.initialQuery});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  late final CategoryListNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = Provider.of<CategoryListNotifier>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier
        ..removeListener(_syncUrl)
        ..addListener(_syncUrl);
      _notifier.applyQuery(widget.initialQuery);
    });
  }

  @override
  void dispose() {
    _notifier.removeListener(_syncUrl);
    super.dispose();
  }

  void _syncUrl() {
    if (!mounted) return;
    final params = categoryQueryToParams(_notifier.query);
    final current = GoRouterState.of(context).uri.queryParameters;
    if (!_mapsEqual(params, current)) {
      context.go(Uri(path: '/categories', queryParameters: params).toString());
    }
  }

  bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (b[k] != a[k]) return false;
    }
    return true;
  }

  void _sort(String field) {
    final q = _notifier.query;
    _notifier.applyQuery(q.copyWith(
      sortField: field,
      sortAscending: field == q.sortField ? !q.sortAscending : true,
    ));
  }

  Future<void> _confirmDeleteSelected(int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить категории?'),
        content: Text('Выбрано: $count. Категории уйдут в корзину, '
            'их можно вернуть.'),
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
      await _notifier.deleteSelected();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Категории перемещены в корзину')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CategoryListNotifier>();
    final query = notifier.query;
    final wide = MediaQuery.widthOf(context) >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Категории'),
        actions: [
          TextButton(
            onPressed: () => context.go('/habits'),
            child: const Text('Привычки',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(context, notifier, query),
          if (notifier.hasSelection) _selectionBar(context, notifier),
          Expanded(child: _body(context, notifier, wide)),
          PaginationBar(
            page: notifier.result.page,
            totalPages: notifier.result.totalPages,
            total: notifier.result.total,
            size: query.size,
            onPage: (p) => notifier.applyQuery(query.copyWith(page: p)),
            onSize: (s) => notifier.applyQuery(query.copyWith(size: s)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context, CategoryListNotifier notifier,
      CategoryQuery query) {
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
              initialValue: query.search,
              hint: 'Название или описание…',
              onChanged: (v) => notifier.applyQuery(query.copyWith(search: v)),
            ),
          ),
          FilterChip(
            label: const Text('Показывать удалённые'),
            selected: query.includeDeleted,
            onSelected: (v) =>
                notifier.applyQuery(query.copyWith(includeDeleted: v)),
          ),
          TextButton.icon(
            onPressed: () => notifier.applyQuery(const CategoryQuery()),
            icon: const Icon(Icons.filter_alt_off),
            label: const Text('Сбросить'),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar(BuildContext context, CategoryListNotifier notifier) {
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
            onPressed: () =>
                _confirmDeleteSelected(notifier.selected.length),
            icon: const Icon(Icons.delete),
            label: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, CategoryListNotifier notifier,
      bool wide) {
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
      LoadStatus.success || LoadStatus.idle => notifier.result.total == 0
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 48),
                  const SizedBox(height: 8),
                  const Text('Ничего не найдено'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        notifier.applyQuery(const CategoryQuery()),
                    child: const Text('Сбросить фильтры'),
                  ),
                ],
              ),
            )
          : wide ? _table(context, notifier) : _cards(context, notifier),
    };
  }

  Widget _table(BuildContext context, CategoryListNotifier notifier) {
    return EntityTable<Category>(
      items: notifier.result.items,
      idOf: (c) => c.id,
      selected: notifier.selected,
      onToggleSelect: notifier.toggleSelection,
      onToggleSelectAll: (ids) {
        final all = ids.every(notifier.selected.contains);
        all ? notifier.clearSelection() : notifier.selectAll(ids);
      },
      sortField: notifier.query.sortField,
      sortAscending: notifier.query.sortAscending,
      onSort: _sort,
      columns: [
        TableColumnSpec(
          label: 'Категория',
          sortField: 'name',
          build: (c) =>
              Text(c.name + (c.isDeleted ? ' (удалёна)' : '')),
        ),
        TableColumnSpec(
          label: 'Описание',
          sortField: 'description',
          build: (c) => Text(
              c.description.length > 46
                  ? '${c.description.substring(0, 46)}…'
                  : c.description),
        ),
      ],
      actions: (c) => [
        IconButton(
          tooltip: 'Открыть',
          icon: const Icon(Icons.open_in_new),
          onPressed: () => context.go('/categories/${c.id}'),
        ),
        if (!c.isDeleted)
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => notifier.softDeleteOne(c.id),
          )
        else
          IconButton(
            tooltip: 'Вернуть',
            icon: const Icon(Icons.restore),
            onPressed: () => notifier.restoreOne(c.id),
          ),
      ],
    );
  }

  Widget _cards(BuildContext context, CategoryListNotifier notifier) {
    return ListView.builder(
      itemCount: notifier.result.items.length,
      itemBuilder: (context, i) {
        final c = notifier.result.items[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Checkbox(
              value: notifier.selected.contains(c.id),
              onChanged: (_) => notifier.toggleSelection(c.id),
            ),
            title: Text(c.name + (c.isDeleted ? ' (удалёна)' : '')),
            subtitle: Text(c.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => context.go('/categories/${c.id}'),
                ),
                if (!c.isDeleted)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => notifier.softDeleteOne(c.id),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.restore),
                    onPressed: () => notifier.restoreOne(c.id),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
