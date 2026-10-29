import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/csv.dart';
import '../core/reference_cache.dart';
import '../data/seed.dart';
import '../models/habit.dart';
import '../models/habit_query.dart';
import '../models/query_uri.dart';
import '../repositories/category_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/tag_repository.dart';
import '../state/habit_list_notifier.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';

class HabitListScreen extends StatelessWidget {
  const HabitListScreen({super.key, required this.initialQuery});

  final HabitQuery initialQuery;

  Future<void> _exportCsv(
    BuildContext context,
    HabitListNotifier notifier,
  ) async {
    final categories = ReferenceCache.instance;
    final rows = <List<String>>[
      [
        'Название',
        'Цель',
        'Категория',
        'Теги',
        'Профиль',
        'Серия, дн.',
        'Мин/день',
      ],
      for (final habit in notifier.result.items)
        [
          habit.name,
          habit.goal,
          categories.category(habit.categoryId),
          habit.tagIds.map(categories.tag).join(', '),
          categories.profile(habit.profileId),
          '${habit.streak}',
          '${habit.minutesPerDay}',
        ],
    ];

    final csv = buildCsv(rows);
    await copyCsvToClipboard(csv);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Скопировано в буфер обмена: ${notifier.result.items.length} '
          'строк CSV',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<HabitListNotifier>();
    final categories = context.read<CategoryRepository>().allActive();
    final profiles = context.read<ProfileRepository>().allActive();
    final tags = context.read<TagRepository>().allActive();

    return EntityListScreen<Habit, HabitQuery>(
      path: '/habits',
      title: 'Привычки',
      initialQuery: initialQuery,
      queryFromParams: habitQueryFromParams,
      queryToParams: habitQueryToParams,
      notifier: notifier,
      searchHint: 'Название или цель…',
      appBarActions: [
        IconButton(
          tooltip: 'Выгрузить в CSV',
          icon: const Icon(Icons.file_download_outlined),
          onPressed: () => _exportCsv(context, notifier),
        ),
        IconButton(
          tooltip: 'Создать привычку',
          icon: const Icon(Icons.add),
          onPressed: () => context.go('/habits/new'),
        ),
        TextButton(
          onPressed: () => context.go('/categories'),
          child: const Text('Категории'),
        ),
        TextButton(
          onPressed: () => context.go('/tags'),
          child: const Text('Теги'),
        ),
        TextButton(
          onPressed: () => context.go('/profiles'),
          child: const Text('Профили'),
        ),
        TextButton(
          onPressed: () => context.go('/check-ins'),
          child: const Text('Отметки'),
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
        DropdownButton<int?>(
          value: query.periodicityId,
          hint: const Text('Периодичность'),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Любая периодичность'),
            ),
            for (final p in periodicities)
              DropdownMenuItem(value: p.id, child: Text(p.name)),
          ],
          onChanged: (v) => onQuery(query.copyWith(periodicityId: v)),
        ),
        DropdownButton<int?>(
          value: query.profileId,
          hint: const Text('Профиль'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Любой')),
            for (final p in profiles)
              DropdownMenuItem(value: p.id, child: Text(p.name)),
          ],
          onChanged: (v) => onQuery(query.copyWith(profileId: v)),
        ),
        DropdownButton<int?>(
          value: query.tagId,
          hint: const Text('Тег'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Любой тег')),
            for (final t in tags)
              DropdownMenuItem(value: t.id, child: Text(t.name)),
          ],
          onChanged: (v) => onQuery(query.copyWith(tagId: v)),
        ),
        SizedBox(
          width: 110,
          child: TextFormField(
            initialValue: query.streakFrom?.toString() ?? '',
            decoration: const InputDecoration(
              labelText: 'Серия от',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onFieldSubmitted: (v) =>
                onQuery(query.copyWith(streakFrom: int.tryParse(v.trim()))),
          ),
        ),
        FilterChip(
          label: const Text('Показывать удалённые'),
          selected: query.includeDeleted,
          onSelected: (v) => onQuery(query.copyWith(includeDeleted: v)),
        ),
      ],
      columns: (query) => [
        TableColumnSpec(
          label: 'Привычка',
          sortField: 'name',
          build: (h) => Text(h.name + (h.isDeleted ? ' (удалёна)' : '')),
        ),
        TableColumnSpec(
          label: 'Категория',
          build: (h) => Text(categoryName(h.categoryId)),
        ),
        TableColumnSpec(
          label: 'Теги',
          build: (h) => Text(h.tagIds.map(tagName).join(', ')),
        ),
        TableColumnSpec(
          label: 'Профиль',
          build: (h) => Text(profileName(h.profileId)),
        ),
        TableColumnSpec(
          label: 'Серия, дн.',
          sortField: 'streak',
          numeric: true,
          build: (h) => Text('${h.streak}'),
        ),
        TableColumnSpec(
          label: 'Мин/день',
          sortField: 'minutes',
          numeric: true,
          build: (h) => Text('${h.minutesPerDay}'),
        ),
      ],
      isDeleted: (h) => h.isDeleted,
      onOpen: (h) => context.go('/habits/${h.id}'),
      onEdit: (h) => context.go('/habits/${h.id}/edit'),
      onDelete: (h) => notifier.softDeleteOne(h.id),
      onRestore: (h) => notifier.restoreOne(h.id),
      cardBuilder: (context, h) {
        final checked = notifier.selected.contains(h.id);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Checkbox(
              value: checked,
              onChanged: (_) => notifier.toggleSelection(h.id),
            ),
            title: Text(h.name + (h.isDeleted ? ' (удалёна)' : '')),
            subtitle: Text(
              '${categoryName(h.categoryId)} • '
              '${h.tagIds.map(tagName).join(', ')} • '
              'серия ${h.streak} дн. • ${h.minutesPerDay} мин/день',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => context.go('/habits/${h.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.go('/habits/${h.id}/edit'),
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
