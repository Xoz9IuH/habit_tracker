import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../models/profile_query.dart';
import '../models/query_uri.dart';
import '../repositories/coupon_repository.dart';
import '../repositories/habit_repository.dart';
import '../state/profile_list_notifier.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';

class ProfileListScreen extends StatelessWidget {
  const ProfileListScreen({super.key, required this.initialQuery});

  final ProfileQuery initialQuery;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ProfileListNotifier>();
    final habitRepo = context.read<HabitRepository>();
    final couponRepo = context.read<CouponRepository>();

    return EntityListScreen<Profile, ProfileQuery>(
      path: '/profiles',
      title: 'Профили',
      initialQuery: initialQuery,
      queryFromParams: profileQueryFromParams,
      queryToParams: profileQueryToParams,
      notifier: notifier,
      searchHint: 'Имя или почта…',
      appBarActions: [
        IconButton(
          tooltip: 'Создать профиль',
          icon: const Icon(Icons.add),
          onPressed: () => context.go('/profiles/new'),
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
          label: 'Имя',
          sortField: 'name',
          build: (p) => Text(p.name + (p.isDeleted ? ' (удалён)' : '')),
        ),
        TableColumnSpec(
          label: 'Почта',
          sortField: 'email',
          build: (p) => Text(p.email),
        ),
        TableColumnSpec(
          label: 'Город',
          sortField: 'city',
          build: (p) => Text(p.city),
        ),
        TableColumnSpec(
          label: 'Цель, мин',
          numeric: true,
          build: (p) => Text('${p.dailyGoalMinutes}'),
        ),
        TableColumnSpec(
          label: 'Привычек',
          numeric: true,
          build: (p) => Text('${habitRepo.countByProfile(p.id)}'),
        ),
      ],
      isDeleted: (p) => p.isDeleted,
      onOpen: (p) => context.go('/profiles/${p.id}'),
      onEdit: (p) => context.go('/profiles/${p.id}/edit'),
      onDelete: (p) async {
        final linked = habitRepo.countByProfile(p.id);
        final coupon = couponRepo.findByProfile(p.id);
        if (coupon != null) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удаление невозможно'),
              content: Text(
                'У профиля «${p.name}» есть скидочный купон '
                '«${coupon.code}». Сначала удалите купон.',
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
        if (linked > 0) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удаление невозможно'),
              content: Text(
                'На профиль «${p.name}» ссылаются привычки: '
                '$linked шт. Сначала перенесите их другому профилю.',
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
        await notifier.softDeleteOne(p.id);
      },
      onRestore: (p) => notifier.restoreOne(p.id),
      cardBuilder: (context, p) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(p.name + (p.isDeleted ? ' (удалён)' : '')),
            subtitle: Text(
              '${p.email} • ${p.city} • '
              'цель ${p.dailyGoalMinutes} мин',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => context.go('/profiles/${p.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.go('/profiles/${p.id}/edit'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
