import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ForbiddenScreen extends StatelessWidget {
  final String target;
  final String role;

  const ForbiddenScreen({super.key, required this.target, required this.role});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Доступ закрыт')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: scheme.error),
                const SizedBox(height: 16),
                Text(
                  '403 — нет прав',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Адрес $target доступен другой роли. '
                  'Вы вошли как $role.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Проверка в интерфейсе только скрывает лишние кнопки. '
                  'Настоящее решение принимает сервер: он ответит 403.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.outline),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/habits'),
                  child: const Text('К привычкам'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
