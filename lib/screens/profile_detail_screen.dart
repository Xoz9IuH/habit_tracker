import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../repositories/coupon_repository.dart';
import '../repositories/habit_repository.dart';
import '../repositories/profile_repository.dart';
import '../state/profile_list_notifier.dart';

class ProfileDetailScreen extends StatefulWidget {
  final int id;

  const ProfileDetailScreen({super.key, required this.id});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  Profile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await context.read<ProfileRepository>().findById(widget.id);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
      if (profile == null) _error = 'Профиль не найден';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.name ?? 'Загрузка профиля…'),
        actions: [
          if (_profile != null)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/profiles/${_profile!.id}/edit'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.go('/profiles'),
                        child: const Text('К списку профилей'),
                      ),
                    ],
                  ),
                )
              : _card(context, _profile!),
    );
  }

  Widget _card(BuildContext context, Profile profile) {
    final notifier = context.read<ProfileListNotifier>();
    final couponRepo = context.read<CouponRepository>();
    final coupon = couponRepo.findByProfile(profile.id);
    final linked = context.read<HabitRepository>().countByProfile(profile.id);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Имя', profile.name),
              _row('Почта', profile.email),
              _row('Город', profile.city),
              _row('Привычек', '$linked шт.'),
              _row('Скидочный купон',
                  coupon == null ? 'нет' : coupon.code),
              _row('Статус',
                  profile.isDeleted ? 'Удалён (в корзине)' : 'Активен'),
              const SizedBox(height: 20),

              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Настройки',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _row('Цель в минутах в день',
                          '${profile.dailyGoalMinutes}'),
                      _row('Напоминания',
                          profile.remindersEnabled ? 'включены' : 'выключены'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (!profile.isDeleted)
                FilledButton.icon(
                  onPressed: linked > 0
                      ? () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Удаление невозможно'),
                              content: Text('На профиль «${profile.name}» '
                                  'ссылаются привычки: $linked шт.'),
                              actions: [
                                FilledButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Понятно'),
                                ),
                              ],
                            ),
                          )
                      : () async {
                          await notifier.softDeleteOne(profile.id);
                          if (context.mounted) context.go('/profiles');
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить (в корзину)'),
                )
              else
                FilledButton.icon(
                  onPressed: () async {
                    await notifier.restoreOne(profile.id);
                    if (context.mounted) context.go('/profiles');
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Вернуть из корзины'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 190,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
