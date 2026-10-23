import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/coupon.dart';
import '../models/coupon_query.dart';
import '../models/query_uri.dart';
import '../repositories/profile_repository.dart';
import '../state/coupon_list_notifier.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';

class CouponListScreen extends StatelessWidget {
  const CouponListScreen({super.key, required this.initialQuery});

  final CouponQuery initialQuery;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CouponListNotifier>();
    final profiles = context.read<ProfileRepository>().allActive();

    return EntityListScreen<Coupon, CouponQuery>(
      path: '/coupons',
      title: 'Скидочные купоны',
      initialQuery: initialQuery,
      queryFromParams: couponQueryFromParams,
      queryToParams: couponQueryToParams,
      notifier: notifier,
      searchHint: 'Промокод…',
      appBarActions: [
        IconButton(
          tooltip: 'Создать купон',
          icon: const Icon(Icons.add),
          onPressed: () => context.go('/coupons/new'),
        ),
        TextButton(
          onPressed: () => context.go('/profiles'),
          child: const Text('Профили', style: TextStyle(color: Colors.white)),
        ),
      ],
      extraFilters: (context, query, onQuery) => [
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
        SizedBox(
          width: 110,
          child: TextFormField(
            initialValue: query.discountFrom?.toString() ?? '',
            decoration: const InputDecoration(
              labelText: 'Скидка от',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onFieldSubmitted: (v) =>
                onQuery(query.copyWith(discountFrom: int.tryParse(v.trim()))),
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
          label: 'Промокод',
          sortField: 'code',
          build: (c) => Text(c.code + (c.isDeleted ? ' (удалён)' : '')),
        ),
        TableColumnSpec(
          label: 'Профиль',
          build: (c) => Text(_profileName(context, c.profileId)),
        ),
        TableColumnSpec(
          label: 'Скидка, %',
          sortField: 'discount',
          numeric: true,
          build: (c) => Text('${c.discountPercent}'),
        ),
        TableColumnSpec(
          label: 'Действует до',
          sortField: 'expires',
          build: (c) => Text(
            '${c.expiresAt.day}.${c.expiresAt.month}.${c.expiresAt.year}',
          ),
        ),
      ],
      isDeleted: (c) => c.isDeleted,
      onOpen: (c) => context.go('/coupons/${c.id}'),
      onEdit: (c) => context.go('/coupons/${c.id}/edit'),
      onDelete: (c) => notifier.softDeleteOne(c.id),
      onRestore: (c) => notifier.restoreOne(c.id),
      cardBuilder: (context, c) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.local_offer),
            title: Text(c.code + (c.isDeleted ? ' (удалён)' : '')),
            subtitle: Text(
              '${_profileName(context, c.profileId)} • '
              'скидка ${c.discountPercent}% • до '
              '${c.expiresAt.day}.${c.expiresAt.month}.${c.expiresAt.year}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => context.go('/coupons/${c.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.go('/coupons/${c.id}/edit'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _profileName(BuildContext context, int profileId) {
    final profiles = context.read<ProfileRepository>().allActive();
    for (final p in profiles) {
      if (p.id == profileId) return p.name;
    }
    return '—';
  }
}
