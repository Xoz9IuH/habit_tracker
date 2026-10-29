import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../services/admin_service.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/user_menu.dart';

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  late Future<Stats> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<StatsService>().load();
  }

  void _reload() {
    setState(() => _future = context.read<StatsService>().load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика и служебный раздел'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          const AppMenuButton(),
          const UserMenu(),
        ],
      ),
      body: FutureBuilder<Stats>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(errorText(snapshot.error!)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          final stats = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Данные сервера на ${_date(stats.generatedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _tile('Привычки', stats.count('habits')),
                  _tile('Отметки', stats.count('check_ins')),
                  _tile('Категории', stats.count('categories')),
                  _tile('Теги', stats.count('tags')),
                  _tile('Профили', stats.count('profiles')),
                  _tile('Купоны', stats.count('coupons')),
                  _tile('Пользователи', stats.count('users')),
                  _tile('Минут всего', stats.totalMinutes),
                  _tile('Выполнено, %', stats.completionRate),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Распределение по категориям',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              CategoryPieChart(
                values: {
                  for (final category in stats.perCategory)
                    category.name: category.habits,
                },
              ),
              const SizedBox(height: 24),
              Text('Популярные привычки', style: theme.textTheme.titleMedium),
              Card(
                child: Column(
                  children: [
                    for (final habit in stats.topHabits)
                      ListTile(
                        dense: true,
                        title: Text(habit.name),
                        trailing: Text('${habit.checkIns} отметок'),
                      ),
                    if (stats.topHabits.isEmpty)
                      const ListTile(dense: true, title: Text('Нет данных')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('По профилям', style: theme.textTheme.titleMedium),
              Card(
                child: Column(
                  children: [
                    for (final profile in stats.perProfile)
                      ListTile(
                        dense: true,
                        title: Text(profile.name),
                        subtitle: Text(
                          'привычек: ${profile.habits}, '
                          'отметок: ${profile.checkIns}',
                        ),
                        trailing: Text('${profile.minutes} мин'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('По категориям', style: theme.textTheme.titleMedium),
              Card(
                child: Column(
                  children: [
                    for (final category in stats.perCategory)
                      ListTile(
                        dense: true,
                        title: Text(category.name),
                        trailing: Text('${category.habits} привычек'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: const ListTile(
                  leading: Icon(Icons.admin_panel_settings_outlined),
                  title: Text('Служебный раздел'),
                  subtitle: Text(
                    'Экран доступен только администратору: остальным сервер '
                    'ответит 403, а маршрут отправит на страницу отказа.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.${value.year} $hour:$minute';
  }

  Widget _tile(String label, int value) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: const TextStyle(fontSize: 24)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
