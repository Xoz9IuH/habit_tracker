import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/seed.dart';
import '../models/tag.dart';
import '../models/tag_query.dart';
import '../models/query_uri.dart';
import '../repositories/category_repository.dart';
import '../repositories/habit_repository.dart';
import '../state/tag_list_notifier.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';

class TagListScreen extends StatelessWidget {
  const TagListScreen({super.key, required this.initialQuery});

  final TagQuery initialQuery;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<TagListNotifier>();
    final categories = context.read<CategoryRepository>().allActive();
    final habitRepo = context.read<HabitRepository>();

    return EntityListScreen<Tag, TagQuery>(
      path: '/tags',
      title: 'Теги',
      initialQuery: initialQuery,
      queryFromParams: tagQueryFromParams,
      queryToParams: tagQueryToParams,
      notifier: notifier,
      searchHint: 'Название тега…',
      appBarActions: [
        IconButton(
          tooltip: 'Создать тег',
          icon: const Icon(Icons.add),
          onPressed: () => context.go('/tags/new'),
        ),
        TextButton(
          onPressed: () => context.go('/habits'),
          child: const Text('Привычки'),
        ),
      ],
      extraFilters: (context, query, onQuery) => [
        DropdownButton<int?>(
          value: query.categoryId,
          hint: const Text('Категория'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Любая')),
            for (final c in categories)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) => onQuery(query.copyWith(categoryId: v)),
        ),
        FilterChip(
          label: const Text('Показывать удалённые'),
          selected: query.includeDeleted,
          onSelected: (v) => onQuery(query.copyWith(includeDeleted: v)),
        ),
      ],
      columns: (query) => [
        TableColumnSpec(
          label: 'Тег',
          sortField: 'name',
          build: (t) => Text(t.name + (t.isDeleted ? ' (удалён)' : '')),
        ),
        TableColumnSpec(
          label: 'Цвет',
          sortField: 'color',
          build: (t) => Text(t.color),
        ),
        TableColumnSpec(
          label: 'Категория',
          build: (t) => Text(
            t.categoryId == null ? 'общий' : categoryName(t.categoryId as int),
          ),
        ),
        TableColumnSpec(
          label: 'Привычек',
          numeric: true,
          build: (t) => Text('${habitRepo.countByTag(t.id)}'),
        ),
      ],
      isDeleted: (t) => t.isDeleted,
      onOpen: (t) => context.go('/tags/${t.id}'),
      onEdit: (t) => context.go('/tags/${t.id}/edit'),
      onDelete: (t) async {
        final linked = habitRepo.countByTag(t.id);
        if (linked > 0) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удаление невозможно'),
              content: Text(
                'На тег «${t.name}» ссылаются привычки: '
                '$linked шт. Сначала уберите тег у этих привычек.',
              ),
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
        await notifier.softDeleteOne(t.id);
      },
      onRestore: (t) => notifier.restoreOne(t.id),
      cardBuilder: (context, t) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(t.name + (t.isDeleted ? ' (удалён)' : '')),
            subtitle: Text(
              '${t.color} • '
              '${t.categoryId == null ? 'общий' : categoryName(t.categoryId as int)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => context.go('/tags/${t.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.go('/tags/${t.id}/edit'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
