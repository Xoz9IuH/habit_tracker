import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';

class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final initials = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName.substring(0, 1).toUpperCase()
        : '?';

    return PopupMenuButton<String>(
      tooltip: 'Пользователь',
      icon: CircleAvatar(
        radius: 15,
        child: Text(initials, style: const TextStyle(fontSize: 13)),
      ),
      onSelected: (value) async {
        switch (value) {
          case 'home':
            context.go('/');
          case 'api-log':
            context.push('/api-log');
          case 'logout':
            await auth.logout();
            if (context.mounted) context.go('/login');
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(user?.fullName ?? 'Гость'),
            subtitle: Text(user?.roleName ?? 'нет сессии'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'home',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.home_outlined),
            title: Text('Главная'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'api-log',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.receipt_long_outlined),
            title: Text('Журнал API'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Выйти'),
          ),
        ),
      ],
    );
  }
}
