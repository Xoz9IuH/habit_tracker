import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/category_query.dart';
import '../models/query_uri.dart';
import '../repositories/habit_repository.dart';
import '../state/category_list_notifier.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';

/// Список категорий. Удаление категории, на которую ссылаются привычки,
/// запрещено — приложение сообщает, сколько записей на неё ссылается.
class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key, required this.initialQuery});

  final CategoryQuery initialQuery;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CategoryListNotifier>();
    final habitRepo = context.read<HabitRepository>();

    return EntityListScreen<Category, CategoryQuery>(
      path: '/categories',
      title: 'Категории',
      initialQuery: initialQuery,
      queryFromParams: categoryQueryFromParams,
      queryToParams: categoryQueryToParams,
      notifier: notifier,
      searchHint: 'Название или описание…',
      appBarActions: [
        IconButton(
          tooltip: 'Создать категорию',
          icon: const Icon(Icons.add),
          onPressed: () => context.go('/categories/new'),
        ),
        TextButton(
          onPressed: () => context.go('/habits'),
          child: const Text('Привычки'),
        ),
      ],
      extraFilters: (context, query, onQuery) => [
        FilterChip(
          label: const Text('Показывать удалённые'),
          selected: query.includeDeleted,
          onSelected: (v) => onQuery(query.copyWith(includeDeleted: v)),
        ),
      ],
      columns: (query) => [
        TableColumnSpec(
          label: 'Категория',
          sortField: 'name',
          build: (c) => Text(c.name + (c.isDeleted ? ' (удалёна)' : '')),
        ),
        TableColumnSpec(
          label: 'Описание',
          sortField: 'description',
          build: (c) => Text(c.description.length > 46
              ? '${c.description.substring(0, 46)}…'
              : c.description),
        ),
        TableColumnSpec(
          label: 'Привычек',
          numeric: true,
          build: (c) => Text('${habitRepo.countByCategory(c.id)}'),
        ),
      ],
      isDeleted: (c) => c.isDeleted,
      onOpen: (c) => context.go('/categories/${c.id}'),
      onEdit: (c) => context.go('/categories/${c.id}/edit'),
      onDelete: (c) async {
        final linked = habitRepo.countByCategory(c.id);
        if (linked > 0) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удаление невозможно'),
              content: Text('На категорию «${c.name}» ссылаются '
                  'привычки: $linked шт. Сначала перенесите их '
                  'в другую категорию.'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно'),
                ),
              ],
            ),
          );
          return;
        }
        await notifier.softDeleteOne(c.id);
      },
      onRestore: (c) => notifier.restoreOne(c.id),
      cardBuilder: (context, c) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(c.name + (c.isDeleted ? ' (удалёна)' : '')),
            subtitle: Text(c.description,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => context.go('/categories/${c.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.go('/categories/${c.id}/edit'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

