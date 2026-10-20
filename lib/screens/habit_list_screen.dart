import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/seed.dart';
import '../models/habit.dart';
import '../models/habit_query.dart';
import '../models/query_uri.dart';
import '../state/habit_list_notifier.dart';
import '../widgets/debounced_search_field.dart';
import '../widgets/entity_table.dart';
import '../widgets/pagination_bar.dart';

class HabitListScreen extends StatefulWidget {
  final HabitQuery initialQuery;

  const HabitListScreen({super.key, required this.initialQuery});

  @override
  State<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends State<HabitListScreen> {
  final _streakFromController = TextEditingController();
  final _streakToController = TextEditingController();
  late final HabitListNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = Provider.of<HabitListNotifier>(context, listen: false);
    _streakFromController.text =
        widget.initialQuery.streakFrom?.toString() ?? '';
    _streakToController.text = widget.initialQuery.streakTo?.toString() ?? '';
    // Запрос из URL применяем после первого кадра: сначала создаём notifier.
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
    _streakFromController.dispose();
    _streakToController.dispose();
    super.dispose();
  }

  /// Обратная синхронизация: каждое изменение notifier уезжает в адресную
  /// строку, так что состоянием экрана остаётся URL, а не переменные.
  void _syncUrl() {
    if (!mounted) return;
    final params = habitQueryToParams(_notifier.query);
    final current = GoRouterState.of(context).uri.queryParameters;
    if (!_mapsEqual(params, current)) {
      context.go(Uri(path: '/habits', queryParameters: params).toString());
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
        title: const Text('Удалить привычки?'),
        content: Text('Выбрано: $count. Привычки исчезнут из списка, '
            'но останутся в «корзине» — их можно вернуть.'),
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
          const SnackBar(content: Text('Привычки перемещены в корзину')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<HabitListNotifier>();
    final query = notifier.query;
    final wide = MediaQuery.widthOf(context) >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Привычки'),
        actions: [
          TextButton(
            onPressed: () => context.go('/categories'),
            child: const Text('Категории',
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

  Widget _filters(
      BuildContext context, HabitListNotifier notifier, HabitQuery query) {
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
              hint: 'Название или цель…',
              onChanged: (v) => notifier.applyQuery(query.copyWith(search: v)),
            ),
          ),
          DropdownButton<int?>(
            value: query.categoryId,
            hint: const Text('Категория'),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('Без категории')),
              for (final c in seedCategories)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) =>
                notifier.applyQuery(query.copyWith(categoryId: v)),
          ),
          DropdownButton<int?>(
            value: query.periodicityId,
            hint: const Text('Периодичность'),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('Любая периодичность')),
              for (final p in periodicities)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) =>
                notifier.applyQuery(query.copyWith(periodicityId: v)),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _streakFromController,
              decoration: const InputDecoration(
                labelText: 'Серия от',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => notifier.applyQuery(
                query.copyWith(
                    streakFrom: v.trim().isEmpty ? null : int.tryParse(v)),
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _streakToController,
              decoration: const InputDecoration(
                labelText: 'Серия до',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => notifier.applyQuery(
                query.copyWith(
                    streakTo: v.trim().isEmpty ? null : int.tryParse(v)),
              ),
            ),
          ),
          FilterChip(
            label: const Text('Показывать удалённые'),
            selected: query.includeDeleted,
            onSelected: (v) =>
                notifier.applyQuery(query.copyWith(includeDeleted: v)),
          ),
          TextButton.icon(
            onPressed: () {
              _streakFromController.clear();
              _streakToController.clear();
              notifier.applyQuery(const HabitQuery());
            },
            icon: const Icon(Icons.filter_alt_off),
            label: const Text('Сбросить'),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar(BuildContext context, HabitListNotifier notifier) {
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

  Widget _body(
      BuildContext context, HabitListNotifier notifier, bool wide) {
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
                    onPressed: () {
                      _streakFromController.clear();
                      _streakToController.clear();
                      notifier.applyQuery(const HabitQuery());
                    },
                    child: const Text('Сбросить фильтры'),
                  ),
                ],
              ),
            )
          : wide ? _table(context, notifier) : _cards(context, notifier),
    };
  }

  Widget _table(BuildContext context, HabitListNotifier notifier) {
    return EntityTable<Habit>(
      items: notifier.result.items,
      idOf: (h) => h.id,
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
          label: 'Привычка',
          sortField: 'name',
          build: (h) =>
              Text(h.name + (h.isDeleted ? ' (удалёна)' : '')),
        ),
        TableColumnSpec(
          label: 'Категория',
          build: (h) => Text(categoryName(h.categoryId)),
        ),
        TableColumnSpec(
          label: 'Периодичность',
          build: (h) => Text(periodicityName(h.periodicityId)),
        ),
        TableColumnSpec(
            label: 'Серия, дн.',
            sortField: 'streak',
            numeric: true,
            build: (h) => Text('${h.streak}')),
        TableColumnSpec(
            label: 'Мин/день',
            sortField: 'minutes',
            numeric: true,
            build: (h) => Text('${h.minutesPerDay}')),
      ],
      actions: (h) => [
        IconButton(
          tooltip: 'Открыть',
          icon: const Icon(Icons.open_in_new),
          onPressed: () => context.go('/habits/${h.id}'),
        ),
        if (!h.isDeleted)
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => notifier.softDeleteOne(h.id),
          )
        else
          IconButton(
            tooltip: 'Вернуть',
            icon: const Icon(Icons.restore),
            onPressed: () => notifier.restoreOne(h.id),
          ),
      ],
    );
  }

  Widget _cards(BuildContext context, HabitListNotifier notifier) {
    return ListView.builder(
      itemCount: notifier.result.items.length,
      itemBuilder: (context, i) {
        final h = notifier.result.items[i];
        final checked = notifier.selected.contains(h.id);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Checkbox(
              value: checked,
              onChanged: (_) => notifier.toggleSelection(h.id),
            ),
            title: Text(h.name + (h.isDeleted ? ' (удалёна)' : '')),
            subtitle: Text('${categoryName(h.categoryId)} • '
                '${periodicityName(h.periodicityId)} • '
                'серия ${h.streak} дн. • ${h.minutesPerDay} мин/день'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => context.go('/habits/${h.id}'),
                ),
                if (!h.isDeleted)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => notifier.softDeleteOne(h.id),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.restore),
                    onPressed: () => notifier.restoreOne(h.id),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
