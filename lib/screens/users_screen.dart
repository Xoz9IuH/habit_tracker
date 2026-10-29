import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../services/admin_service.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/user_menu.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<AppUser>> _future;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<UserService>().list();
  }

  void _reload() {
    setState(() {
      _future = context.read<UserService>().list();
    });
  }

  Future<void> _changeRole(AppUser user, String role) async {
    setState(() => _busy = true);
    try {
      await context.read<UserService>().setRole(user.key, role);
      if (!mounted) return;
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(AppUser user) async {
    final service = context.read<UserService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text(
          'Пользователь ${user.username} больше не сможет войти. '
          'Сессии будут отозваны.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await service.remove(user.key);
      if (!mounted) return;
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
          const AppMenuButton(),
          const UserMenu(),
        ],
      ),
      body: FutureBuilder<List<AppUser>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = _error ?? snapshot.error;
          if (error != null) {
            return _ErrorBox(text: errorText(error), onRetry: _reload);
          }
          final users = snapshot.data ?? const <AppUser>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              Text(
                'Управление ролями и сессиями. Менять роли и удалять '
                'пользователей может только администратор.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              for (final user in users)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(user.username.substring(0, 1).toUpperCase()),
                    ),
                    title: Text('${user.fullName} (${user.username})'),
                    subtitle: Text('Роль: ${user.roleName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButton<String>(
                          value: user.role,
                          onChanged: _busy
                              ? null
                              : (role) {
                                  if (role != null && role != user.role) {
                                    _changeRole(user, role);
                                  }
                                },
                          items: const [
                            DropdownMenuItem(
                              value: 'reader',
                              child: Text('читатель'),
                            ),
                            DropdownMenuItem(
                              value: 'librarian',
                              child: Text('редактор'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('администратор'),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Удалить пользователя',
                          onPressed: _busy ? null : () => _remove(user),
                          icon: const Icon(Icons.person_remove_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ErrorBox({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text(text),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
