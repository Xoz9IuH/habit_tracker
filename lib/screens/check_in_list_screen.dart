import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/seed.dart';
import '../models/check_in.dart';
import '../models/check_in_query.dart';
import '../models/query_uri.dart';
import '../repositories/habit_repository.dart';
import '../repositories/profile_repository.dart';
import '../state/check_in_list_notifier.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';

/// Список отметок о выполнении — связь «многие к одному» с привычкой
/// и с профилем.
class CheckInListScreen extends StatelessWidget {
  const CheckInListScreen({super.key, required this.initialQuery});

  final CheckInQuery initialQuery;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CheckInListNotifier>();
    final habits = context.read<HabitRepository>().allActive();
    final profiles = context.read<ProfileRepository>().allActive();

    return EntityListScreen<CheckIn, CheckInQuery>(
      path: '/check-ins',
      title: 'Отметки о выполнении',
      initialQuery: initialQuery,
      queryFromParams: checkInQueryFromParams,
      queryToParams: checkInQueryToParams,
      notifier: notifier,
      searchHint: 'По заметке…',
      appBarActions: [
        IconButton(
          tooltip: 'Создать отметку',
          icon: const Icon(Icons.add),
          onPressed: () => context.go('/check-ins/new'),
        ),
        TextButton(
          onPressed: () => context.go('/habits'),
          child: const Text('Привычки'),
        ),
      ],
      extraFilters: (context, query, onQuery) => [
        DropdownButton<int?>(
          value: query.habitId,
          hint: const Text('Привычка'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Любая')),
            for (final h in habits)
              DropdownMenuItem(value: h.id, child: Text(h.name)),
          ],
          onChanged: (v) => onQuery(query.copyWith(habitId: v)),
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
        FilterChip(
          label: const Text('Показывать удалённые'),
          selected: query.includeDeleted,
          onSelected: (v) => onQuery(query.copyWith(includeDeleted: v)),
        ),
      ],
      columns: (query) => [
        TableColumnSpec(
          label: 'Дата',
          sortField: 'date',
          build: (c) => Text(
              '${c.date.day}.${c.date.month}.${c.date.year}'),
        ),
        TableColumnSpec(
          label: 'Привычка',
          sortField: 'habit',
          build: (c) => Text(habitName(c.habitId)),
        ),
        TableColumnSpec(
          label: 'Профиль',
          build: (c) => Text(profileName(c.profileId)),
        ),
        TableColumnSpec(
          label: 'Мин',
          sortField: 'minutes',
          numeric: true,
          build: (c) => Text('${c.minutes}'),
        ),
        TableColumnSpec(
          label: 'Статус',
          build: (c) => Text(c.completed ? 'выполнено' : 'не выполнено'),
        ),
      ],
      isDeleted: (c) => c.isDeleted,
      onOpen: (c) => context.go('/check-ins/${c.id}'),
      onEdit: (c) => context.go('/check-ins/${c.id}/edit'),
      onDelete: (c) => notifier.softDeleteOne(c.id),
      onRestore: (c) => notifier.restoreOne(c.id),
      cardBuilder: (context, c) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text('${habitName(c.habitId)} — '
                '${c.date.day}.${c.date.month}.${c.date.year}'),
            subtitle: Text('${profileName(c.profileId)} • '
                '${c.minutes} мин • '
                '${c.completed ? 'выполнено' : 'не выполнено'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => context.go('/check-ins/${c.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.go('/check-ins/${c.id}/edit'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

