import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/role.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/user_menu.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final theme = Theme.of(context);
    final sections = menuSections
        .where((section) => Role.atLeast(user?.role, section.minimumRole))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Трекер привычек'),
        actions: const [AppMenuButton(), UserMenu()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    child: Text(
                      (user?.fullName.isNotEmpty ?? false)
                          ? user!.fullName.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Гость',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          '${user?.username ?? ''} / роль: '
                          '${user?.roleName ?? 'нет сессии'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Разделы, доступные вашей роли',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final section in sections)
                SizedBox(
                  width: 200,
                  child: Card(
                    child: ListTile(
                      leading: Icon(section.icon),
                      title: Text(section.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(section.route),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Скрытые разделы недоступны этой роли: справочники и профили '
                'ведёт редактор, а пользователей, статистику и безвозвратное '
                'удаление — только администратор.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
